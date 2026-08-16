import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Todoist task list popup. Owns every bit of state BarWidget.qml reads back
// (apiToken, taskCount) plus the curl processes that talk to the Todoist API
// (https://developer.todoist.com/api/v1/) and the local settings file that
// holds the personal API token.
Panel {
  id: root
  moduleName: "io.github.aryan-techie.todoist"
  ipcTarget: "io.github.aryan-techie.todoist"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string apiBase: "https://api.todoist.com/api/v1"
  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string pluginDir: homeDir + "/.config/omarchy/plugins/io.github.aryan-techie.todoist"
  readonly property string stateDir: homeDir + "/.local/state/omarchy/io.github.aryan-techie.todoist"
  readonly property string settingsPath: stateDir + "/settings.json"

  property string apiToken: ""
  property string filterQuery: "today | overdue"
  // "today" | "inbox" | "all" | "custom" — the three tabs plus whatever the
  // free-form filter field in Settings last applied.
  property string quickView: "today"
  property bool settingsLoaded: false
  property bool settingsView: true

  property var tasks: []
  readonly property int taskCount: tasks.length
  onTasksChanged: {
    if (root.selectedTaskIndex >= root.tasks.length) root.selectedTaskIndex = root.tasks.length - 1
  }

  // Keyboard cursor over the task list. -1 = nothing selected yet;
  // taskCursorActive gates the row highlight so it only shows up once the
  // user has actually pressed an arrow key, not on every open.
  property int selectedTaskIndex: -1
  property bool taskCursorActive: false

  property string pendingDeleteTaskId: ""
  property string pendingDeleteTaskContent: ""

  // Tasks mid-completion: closed on the server already, but kept in the
  // list (struck through, dimmed) for a moment so the click reads as
  // "done", not "vanished".
  property var completingTaskIds: []
  property var pendingRemovalIds: []

  // Inline content editing. -1 = no row being edited.
  property int editingTaskIndex: -1
  property string editDraft: ""

  // Enter fires both returnRequested (open in browser) and activateRequested
  // (complete) back-to-back — this suppresses the completion half of that so
  // Enter only opens the browser; Space still completes on its own.
  property bool suppressNextActivate: false

  property bool helpOpen: false

  // Fixed popup size, user-adjustable from Settings → Advanced. Deliberately
  // NOT derived from content (mainColumn.implicitHeight) — letting the
  // window grow/shrink with task count is what was causing content to
  // overflow past the card; a fixed size scrolls instead.
  property int panelWidth: 340
  property int panelHeight: 480

  property bool loading: false
  property string errorText: ""

  property string tokenDraft: ""
  property string quickAddText: ""
  property bool quickAddSubmitting: false
  property var actionQueue: []

  // ---- Keyboard shortcut (Settings → Keyboard shortcut). Empty means no
  //      shortcut has been wired into ~/.config/hypr/bindings.lua yet.
  property string keybindCombo: ""
  property bool recordingKeybind: false
  property string pendingKeybindCombo: ""
  property string keybindRecordError: ""
  property string keybindApplyStatus: ""
  property string keybindApplyError: ""

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string quickViewLabel: root.quickView === "inbox" ? "INBOX"
    : root.quickView === "all" ? "ALL TASKS"
    : root.quickView === "custom" ? "CUSTOM FILTER"
    : "TODAY & OVERDUE"

  readonly property string headerSubtitle: {
    if (root.apiToken === "") return "NOT CONNECTED"
    if (root.settingsView) return "SETTINGS"
    if (root.loading && root.tasks.length === 0) return "LOADING…"
    return root.quickViewLabel + " · " + root.taskCount + (root.taskCount === 1 ? " TASK" : " TASKS")
  }

  // ---- Lifecycle. Matches the clock/weather contract: open() refreshes
  //      before showing so the list is never more than one popup-open stale.
  function open() {
    if (root.apiToken !== "") refresh()
    root.controller.show()
    // Only steal focus into a text field when Settings needs the token
    // typed immediately. Otherwise leave focus on keyCatcher (its own
    // default via KeyboardPanel's focusTarget) so arrows/Tab/r/q work the
    // instant the panel opens, instead of being swallowed by quickAddField.
    if (root.settingsView) Qt.callLater(function() {
      if (root.opened && root.settingsView) tokenField.forceActiveFocus()
    })
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // ---- Settings persistence. A local state file, not shell.json — the
  //      token is a secret, not bar layout, so it never round-trips through
  //      the shared config the bar writes.
  function ensureStateDir() {
    mkdirProc.running = true
  }

  function loadSettingsFromText(text) {
    var parsed = {}
    try { parsed = JSON.parse(text || "{}") } catch (e) { parsed = {} }
    if (typeof parsed.apiToken === "string") root.apiToken = parsed.apiToken
    if (typeof parsed.filter === "string") root.filterQuery = Model.sanitizeFilter(parsed.filter)
    if (typeof parsed.quickView === "string" && ["today", "inbox", "all", "custom"].indexOf(parsed.quickView) !== -1)
      root.quickView = parsed.quickView
    if (typeof parsed.keybind === "string") root.keybindCombo = parsed.keybind
    if (typeof parsed.panelWidth === "number") root.panelWidth = Math.max(260, Math.min(700, parsed.panelWidth))
    if (typeof parsed.panelHeight === "number") root.panelHeight = Math.max(240, Math.min(800, parsed.panelHeight))
    root.settingsLoaded = true
    root.settingsView = root.apiToken === ""
    if (root.apiToken !== "") refresh()
  }

  function persistSettings() {
    settingsFile.setText(JSON.stringify({
      apiToken: root.apiToken,
      filter: root.filterQuery,
      quickView: root.quickView,
      keybind: root.keybindCombo,
      panelWidth: root.panelWidth,
      panelHeight: root.panelHeight
    }, null, 2) + "\n")
    // The token is a secret; keep the file readable only by the user. A
    // short defer gives the atomic write below somewhere to land first.
    Qt.callLater(function() { chmodProc.running = true })
  }

  function saveToken() {
    var value = Model.safeTrim(root.tokenDraft)
    if (value === "") return
    root.apiToken = value
    root.tokenDraft = ""
    tokenField.text = ""
    root.errorText = ""
    root.settingsView = false
    persistSettings()
    refresh()
  }

  function clearToken() {
    root.apiToken = ""
    root.tasks = []
    root.errorText = ""
    root.settingsView = true
    persistSettings()
  }

  function applyFilter(value) {
    var next = Model.sanitizeFilter(value)
    filterField.text = next
    root.quickView = "custom"
    if (next === root.filterQuery) { persistSettings(); refresh(); return }
    root.filterQuery = next
    persistSettings()
    refresh()
  }

  // ---- Popup size (Settings → Advanced).
  function setPanelWidth(width) {
    root.panelWidth = Math.max(260, Math.min(700, width))
    persistSettings()
  }

  function setPanelHeight(height) {
    root.panelHeight = Math.max(240, Math.min(800, height))
    persistSettings()
  }

  // ---- Quick views. "today"/"inbox" hit /tasks/filter with a canned query;
  //      "all" hits plain /tasks (no filter = every active task); "custom"
  //      reuses whatever filter the Settings field last applied.
  function selectQuickView(view) {
    if (view === root.quickView) return
    root.quickView = view
    root.selectedTaskIndex = -1
    root.taskCursorActive = false
    persistSettings()
    refresh()
  }

  readonly property var quickViewOrder: ["today", "inbox", "all"]

  function cycleQuickView(direction) {
    var idx = root.quickViewOrder.indexOf(root.quickView)
    if (idx === -1) idx = 0
    var next = (idx + direction + root.quickViewOrder.length) % root.quickViewOrder.length
    root.selectQuickView(root.quickViewOrder[next])
  }

  // ---- Keyboard cursor over the task list (arrow keys / j·k, Enter/Space
  //      to complete). Independent of the Tab-driven quick-view cycling and
  //      of the keyboard-shortcut recorder above.
  function moveTaskCursor(delta) {
    if (root.tasks.length === 0) return
    root.taskCursorActive = true
    var next = root.selectedTaskIndex + delta
    if (next < 0) next = 0
    if (next > root.tasks.length - 1) next = root.tasks.length - 1
    root.selectedTaskIndex = next
    Qt.callLater(function() {
      if (taskListView.count > 0) taskListView.positionViewAtIndex(root.selectedTaskIndex, ListView.Contain)
    })
  }

  function activateSelectedTask() {
    if (root.selectedTaskIndex < 0 || root.selectedTaskIndex >= root.tasks.length) return
    var task = root.tasks[root.selectedTaskIndex]
    if (task) root.requestComplete(task.id)
  }

  // ---- Open the selected task on the Todoist website (Enter). Closes the
  //      panel afterward — attention is going to the browser, not staying
  //      here, matching how launching anything else from a panel dismisses it.
  function openSelectedTaskInBrowser() {
    if (root.selectedTaskIndex < 0 || root.selectedTaskIndex >= root.tasks.length) return
    var task = root.tasks[root.selectedTaskIndex]
    if (!task || !task.id) return
    openUrlProc.command = ["xdg-open", "https://app.todoist.com/app/task/" + encodeURIComponent(task.id)]
    openUrlProc.running = true
    root.close()
  }

  // ---- Inline content edit (e).
  function startEditSelectedTask() {
    if (root.selectedTaskIndex < 0 || root.selectedTaskIndex >= root.tasks.length) return
    var task = root.tasks[root.selectedTaskIndex]
    if (!task || root.completingTaskIds.indexOf(task.id) !== -1) return
    root.editDraft = task.content || ""
    root.editingTaskIndex = root.selectedTaskIndex
  }

  function cancelEditTask() {
    root.editingTaskIndex = -1
    root.editDraft = ""
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function commitEditTask() {
    var index = root.editingTaskIndex
    root.editingTaskIndex = -1
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    if (index < 0 || index >= root.tasks.length) { root.editDraft = ""; return }
    var task = root.tasks[index]
    var newContent = Model.safeTrim(root.editDraft)
    root.editDraft = ""
    if (!task || newContent === "" || newContent === task.content) return

    var updated = {}
    for (var key in task) updated[key] = task[key]
    updated.content = newContent
    var nextTasks = root.tasks.slice()
    nextTasks[index] = updated
    root.tasks = nextTasks

    editProc.command = ["curl", "-fsS", "--max-time", "10", "-X", "POST",
      "-H", "Authorization: Bearer " + root.apiToken,
      "-H", "Content-Type: application/json",
      "-d", JSON.stringify({ content: newContent }),
      root.apiBase + "/tasks/" + encodeURIComponent(task.id)]
    editProc.running = true
  }

  // ---- Delete (the selected task, via "x" or a task row's delete button).
  //      Confirmed first — unlike completing, this can't be undone from here.
  function requestDeleteSelected() {
    if (root.selectedTaskIndex < 0 || root.selectedTaskIndex >= root.tasks.length) return
    var task = root.tasks[root.selectedTaskIndex]
    if (!task) return
    root.requestDeleteTask(task.id, task.content || "")
  }

  function requestDeleteTask(taskId, content) {
    root.pendingDeleteTaskId = taskId
    root.pendingDeleteTaskContent = content
    confirmDialog.selectedIndex = 0
    confirmDialog.opened = true
  }

  function cancelDeleteTask() {
    confirmDialog.opened = false
    root.pendingDeleteTaskId = ""
    root.pendingDeleteTaskContent = ""
  }

  function confirmDeleteTask() {
    confirmDialog.opened = false
    var taskId = root.pendingDeleteTaskId
    root.pendingDeleteTaskId = ""
    root.pendingDeleteTaskContent = ""
    if (taskId === "") return
    root.tasks = root.tasks.filter(function(t) { return !t || t.id !== taskId })
    deleteProc.command = ["curl", "-fsS", "--max-time", "10", "-X", "DELETE",
      "-H", "Authorization: Bearer " + root.apiToken,
      root.apiBase + "/tasks/" + encodeURIComponent(taskId)]
    deleteProc.running = true
  }

  // ---- Task list.
  function refresh() {
    if (root.apiToken === "") {
      root.settingsView = true
      return
    }
    if (listProc.running) return
    root.loading = true
    root.errorText = ""

    var url
    if (root.quickView === "all") {
      url = root.apiBase + "/tasks"
    } else {
      var query = root.quickView === "inbox" ? "#Inbox"
        : root.quickView === "custom" ? root.filterQuery
        : "today | overdue"
      url = root.apiBase + "/tasks/filter?query=" + encodeURIComponent(query) + "&lang=en"
    }

    listProc.command = ["curl", "-fsS", "--max-time", "10",
      "-H", "Authorization: Bearer " + root.apiToken, url]
    listProc.running = true
  }

  // ---- Quick add. Uses Todoist's own Quick Add parser (/tasks/quick) so
  //      "p1"/"p2"/"p3"/"p4", "#Project", "@label", and natural-language
  //      due dates work exactly like typing into Todoist itself. A bare
  //      task with no date hint gets " today" appended so it defaults to
  //      due today instead of no due date.
  function submitQuickAdd() {
    var content = Model.safeTrim(root.quickAddText)
    if (content === "" || root.quickAddSubmitting || root.apiToken === "") return
    var text = Model.quickAddHasDueHint(content) ? content : (content + " today")
    root.quickAddSubmitting = true
    root.errorText = ""
    createProc.command = ["curl", "-fsS", "--max-time", "10", "-X", "POST",
      "-H", "Authorization: Bearer " + root.apiToken,
      "-H", "Content-Type: application/json",
      "-d", JSON.stringify({ text: text }),
      root.apiBase + "/tasks/quick"]
    createProc.running = true
  }

  // ---- Complete task. Marked "completing" (struck through, dimmed) right
  //      away for feedback, then actually removed from the list a moment
  //      later — the API call itself fires immediately, only the row's
  //      disappearance is delayed. A failed close re-fetches rather than
  //      trying to reinsert it at the right sorted position by hand.
  function requestComplete(taskId) {
    if (taskId === "" || root.completingTaskIds.indexOf(taskId) !== -1) return
    root.completingTaskIds = root.completingTaskIds.concat([taskId])
    root.pendingRemovalIds.push(taskId)
    root.actionQueue.push(taskId)
    processActionQueue()
    completionRemovalTimer.restart()
  }

  function flushCompletedRemovals() {
    var ids = root.pendingRemovalIds
    root.pendingRemovalIds = []
    root.tasks = root.tasks.filter(function(t) { return !t || ids.indexOf(t.id) === -1 })
    root.completingTaskIds = root.completingTaskIds.filter(function(id) { return ids.indexOf(id) === -1 })
  }

  function processActionQueue() {
    if (actionProc.running || root.actionQueue.length === 0) return
    var taskId = root.actionQueue.shift()
    actionProc.command = ["curl", "-fsS", "--max-time", "10", "-X", "POST",
      "-H", "Authorization: Bearer " + root.apiToken,
      root.apiBase + "/tasks/" + encodeURIComponent(taskId) + "/close"]
    actionProc.running = true
  }

  // ---- Keyboard shortcut recording. Mirrors a stripped-down Hyprland key
  //      combo into "MOD + MOD + KEY" form; set-keybind.sh does the actual
  //      ~/.config/hypr/bindings.lua edit (backup + reload + auto-rollback).
  function isBareModifier(key) {
    return key === Qt.Key_Super_L || key === Qt.Key_Super_R || key === Qt.Key_Meta
      || key === Qt.Key_Control || key === Qt.Key_Shift || key === Qt.Key_Alt || key === Qt.Key_AltGr
  }

  function hyprKeyName(key) {
    if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key)
    if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key)
    if (key >= Qt.Key_F1 && key <= Qt.Key_F12) return "F" + (key - Qt.Key_F1 + 1)
    var names = {}
    names[Qt.Key_Space] = "SPACE"
    names[Qt.Key_Return] = "RETURN"
    names[Qt.Key_Enter] = "RETURN"
    names[Qt.Key_Tab] = "TAB"
    names[Qt.Key_Backspace] = "BACKSPACE"
    names[Qt.Key_Comma] = "comma"
    names[Qt.Key_Period] = "period"
    names[Qt.Key_Minus] = "minus"
    names[Qt.Key_Equal] = "equal"
    names[Qt.Key_Slash] = "slash"
    return names[key] || ""
  }

  function startRecordingKeybind() {
    root.recordingKeybind = true
    root.pendingKeybindCombo = ""
    root.keybindRecordError = ""
    root.keybindApplyStatus = ""
  }

  function cancelRecordingKeybind() {
    root.recordingKeybind = false
    root.pendingKeybindCombo = ""
    root.keybindRecordError = ""
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function handleKeybindRecordKey(event) {
    if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
      root.cancelRecordingKeybind()
      event.accepted = true
      return
    }
    if (root.isBareModifier(event.key)) { event.accepted = true; return }

    var mods = []
    if (event.modifiers & Qt.MetaModifier) mods.push("SUPER")
    if (event.modifiers & Qt.ControlModifier) mods.push("CTRL")
    if (event.modifiers & Qt.AltModifier) mods.push("ALT")
    if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT")

    var keyStr = root.hyprKeyName(event.key)
    if (keyStr === "") {
      root.keybindRecordError = "Unsupported key — try a letter, digit, F-key, or punctuation key."
      event.accepted = true
      return
    }
    if (mods.length === 0) {
      root.keybindRecordError = "Add a modifier (Super/Ctrl/Alt/Shift) — a bare key would break typing everywhere."
      event.accepted = true
      return
    }

    root.keybindRecordError = ""
    root.pendingKeybindCombo = mods.join(" + ") + " + " + keyStr
    event.accepted = true
  }

  function applyKeybindCombo(combo) {
    if (combo === "" || root.keybindApplyStatus === "applying") return
    root.keybindApplyStatus = "applying"
    root.keybindApplyError = ""
    keybindProc.pendingApply = combo
    keybindProc.command = ["bash", root.pluginDir + "/set-keybind.sh", combo]
    keybindProc.running = true
  }

  function removeKeybindCombo() {
    if (root.keybindCombo === "" || root.keybindApplyStatus === "applying") return
    root.keybindApplyStatus = "applying"
    root.keybindApplyError = ""
    keybindProc.pendingApply = ""
    keybindProc.command = ["bash", root.pluginDir + "/set-keybind.sh", "__REMOVE__"]
    keybindProc.running = true
  }

  Component.onCompleted: {
    ensureStateDir()
    Qt.callLater(function() { settingsFile.reload() })
  }

  // ---- Processes -----------------------------------------------------

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.stateDir]
  }

  Process {
    id: chmodProc
    command: ["chmod", "600", root.settingsPath]
  }

  Process {
    id: listProc
    stdout: StdioCollector {
      id: listOut
      waitForEnd: true
      onStreamFinished: {
        root.loading = false
        var raw = String(text || "").trim()
        if (raw === "") return
        try {
          var parsed = JSON.parse(raw)
          var results = (parsed && parsed.results) ? parsed.results : []
          root.tasks = Model.sortedTasks(results)
          root.errorText = ""
        } catch (e) {
          root.errorText = "Couldn't read the response from Todoist."
        }
      }
    }
    stderr: StdioCollector {
      id: listErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0) root.errorText = Model.errorMessageForExit(exitCode, listErr.text)
    }
  }

  Process {
    id: createProc
    stderr: StdioCollector {
      id: createErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.quickAddSubmitting = false
      if (exitCode === 0) {
        root.quickAddText = ""
        quickAddField.text = ""
        root.refresh()
      } else {
        root.errorText = Model.errorMessageForExit(exitCode, createErr.text)
      }
    }
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      id: actionErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.errorText = Model.errorMessageForExit(exitCode, actionErr.text)
        root.refresh()
      }
      Qt.callLater(root.processActionQueue)
    }
  }

  Process {
    id: deleteProc
    stderr: StdioCollector {
      id: deleteErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.errorText = Model.errorMessageForExit(exitCode, deleteErr.text)
        root.refresh()
      }
    }
  }

  Process {
    id: editProc
    stderr: StdioCollector {
      id: editErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.errorText = Model.errorMessageForExit(exitCode, editErr.text)
        root.refresh()
      }
    }
  }

  Process {
    id: openUrlProc
  }

  Timer {
    id: completionRemovalTimer
    interval: 700
    repeat: false
    onTriggered: root.flushCompletedRemovals()
  }

  Process {
    id: keybindProc
    property string pendingApply: ""
    stderr: StdioCollector {
      id: keybindErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.keybindCombo = keybindProc.pendingApply
        root.keybindApplyStatus = ""
        root.keybindApplyError = ""
        root.recordingKeybind = false
        root.pendingKeybindCombo = ""
        persistSettings()
      } else {
        root.keybindApplyStatus = "error"
        root.keybindApplyError = (keybindErr.text || "").trim() || "Failed to apply keybind."
      }
    }
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSettingsFromText(text())
    onLoadFailed: root.loadSettingsFromText("")
  }

  // Background poll so the bar's count stays fresh even while the panel is
  // closed; a tighter interval only while it's open.
  Timer {
    interval: 15 * 60 * 1000
    running: root.apiToken !== ""
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 5 * 60 * 1000
    running: root.opened && root.apiToken !== ""
    repeat: true
    onTriggered: root.refresh()
  }

  // ---- One task row: complete button + content + due label. ----------
  component TaskRow: Item {
    id: row
    required property var task
    // Not named "index" — a delegate instantiating this component also
    // needs its own ListView-injected "required property int index", and
    // QML won't let two same-named required properties coexist between a
    // component and the instance declaring it (matches the built-in
    // bluetooth panel's DeviceRow/rowIndex convention).
    required property int rowIndex
    property bool hasCursor: false

    readonly property bool overdue: Model.taskIsOverdue(task)
    readonly property string dueLabel: Model.taskDueLabel(task)
    readonly property bool completing: task ? root.completingTaskIds.indexOf(task.id) !== -1 : false
    readonly property bool editing: root.editingTaskIndex === rowIndex
    // Todoist priority colors (API priority 4 = p1, the most urgent, down
    // to 1 = p4/no priority). Fixed, theme-independent hex — these carry a
    // specific meaning ("this is p1") the same way in every theme, unlike
    // an accent color that's meant to shift with the user's theme.
    readonly property color textColor: {
      if (!task) return root.contentForeground
      if (task.priority === 4) return "#eb5757"
      if (task.priority === 3) return "#f2b84b"
      if (task.priority === 2) return "#4a90d2"
      return root.contentForeground
    }

    // editField.text isn't kept bound to root.editDraft once the user has
    // typed in it once (assigning to a QML property severs a declarative
    // binding on it) — re-sync explicitly whenever this row starts editing.
    onEditingChanged: {
      if (editing) {
        editField.text = root.editDraft
        Qt.callLater(function() {
          if (row.editing) { editField.forceActiveFocus(); editField.selectAll() }
        })
      }
    }

    height: Math.max(checkBtn.height, textColumn.implicitHeight) + Style.spacing.sm * 2

    Rectangle {
      anchors.fill: parent
      anchors.margins: -Style.spacing.xs
      radius: Style.cornerRadius
      visible: row.hasCursor
      color: Style.hoverFillFor(root.contentForeground, Color.accent)
    }

    PanelActionButton {
      id: checkBtn
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.topMargin: Style.spacing.sm
      iconText: row.completing ? "●" : "○"
      tooltipText: "Mark complete (Space)"
      foreground: row.textColor
      enabled: !row.completing
      onClicked: root.requestComplete(row.task ? row.task.id : "")
    }

    Column {
      id: textColumn
      anchors.left: checkBtn.right
      anchors.leftMargin: Style.spacing.sm
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.topMargin: Style.spacing.sm
      spacing: 2

      Text {
        visible: !row.editing
        height: visible ? implicitHeight : 0
        width: parent.width
        text: row.task ? row.task.content : ""
        opacity: row.completing ? 0.5 : 1.0
        font.strikeout: row.completing
        color: row.textColor
        wrapMode: Text.WordWrap
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
      }

      TextField {
        id: editField
        visible: row.editing
        height: visible ? implicitHeight : 0
        width: parent.width
        onTextChanged: if (row.editing) root.editDraft = text
        onAccepted: root.commitEditTask()
        Keys.onEscapePressed: root.cancelEditTask()
      }

      Text {
        visible: row.dueLabel !== "" && !row.editing
        height: visible ? implicitHeight : 0
        width: parent.width
        text: row.dueLabel
        color: row.overdue ? Color.urgent : Qt.darker(root.contentForeground, 1.5)
        wrapMode: Text.WordWrap
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // ---- Chrome ----------------------------------------------------------

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    // Drops right below the bar icon, not centered on the whole bar.
    centerOnBar: false
    focusTarget: keyCatcher
    // Fixed size (Settings → Advanced), not derived from mainColumn's
    // implicitHeight — content that doesn't fit scrolls inside the
    // Flickable below rather than resizing the window around it.
    contentWidth: panel.fittedContentWidth(root.panelWidth)
    contentHeight: panel.fittedContentHeight(root.panelHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      clip: true
      blocked: tokenField.activeFocus || filterField.activeFocus || quickAddField.activeFocus || root.recordingKeybind || confirmDialog.opened || root.editingTaskIndex !== -1 || root.helpOpen
      // First Escape backs out of Settings to the task list; a second one
      // (now that settingsView is false) closes the panel.
      onCloseRequested: {
        if (root.settingsView) root.settingsView = false
        else root.close()
      }
      // Tab cycles the quick-view tabs while the task list is showing;
      // Settings has no tabs of its own, so Tab falls back to the shell's
      // usual "switch to the next bar panel" behavior there.
      onTabRequested: function(direction) {
        if (root.settingsView) root.switchPanel(direction)
        else root.cycleQuickView(direction)
      }
      onMoveRequested: function(dx, dy) {
        if (root.settingsView || dy === 0) return
        root.moveTaskCursor(dy)
      }
      // Enter fires returnRequested then activateRequested, back to back,
      // for the same keypress — returnRequested opens the task in the
      // browser and flags suppressNextActivate so the activateRequested
      // that immediately follows doesn't also complete it. Space fires only
      // activateRequested, so it still completes on its own.
      onReturnRequested: {
        if (root.settingsView) return
        root.suppressNextActivate = true
        root.openSelectedTaskInBrowser()
      }
      onActivateRequested: {
        if (root.suppressNextActivate) { root.suppressNextActivate = false; return }
        if (!root.settingsView) root.activateSelectedTask()
      }
      // "x" is this shell's established delete shortcut (see
      // Ui/PanelKeyCatcher.qml) — the physical Delete key has no printable
      // event.text so PanelKeyCatcher never sees it as a distinct key.
      onDeleteRequested: {
        if (!root.settingsView) root.requestDeleteSelected()
      }
      onTextKey: function(t) {
        if (t === "?") { root.helpOpen = !root.helpOpen; return }
        if (t === "r" || t === "R") { root.refresh(); return }
        if (t === "p" || t === "P") { root.settingsView = !root.settingsView; return }
        if (root.settingsView) return
        if (t === "q" || t === "Q") { quickAddField.forceActiveFocus(); return }
        if (t === "e" || t === "E") { root.startEditSelectedTask(); return }
        if (t === "t" || t === "T") { root.selectQuickView("today"); return }
        if (t === "i" || t === "I") { root.selectQuickView("inbox"); return }
        if (t === "a" || t === "A") root.selectQuickView("all")
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: mainColumn
          width: parent.width
          spacing: Style.spacing.lg

          // ---- Header ---------------------------------------------------
          // Height comes from titleColumn alone (not a Math.max of both
          // children) and actionsRow centers on that sibling directly,
          // rather than on the parent's own height — sizing a parent from a
          // child while anchoring that child back to the parent's center is
          // a classic Qt Quick binding-loop trap.
          Item {
            width: parent.width
            height: titleColumn.implicitHeight

            Column {
              id: titleColumn
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.right: actionsRow.left
              anchors.rightMargin: Style.spacing.sm
              spacing: 2

              Row {
                spacing: Style.spacing.xs

                Text {
                  text: "✓"
                  color: Color.accent
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.title
                }

                Text {
                  text: "Todoist"
                  font.bold: true
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.title
                  color: root.contentForeground
                }
              }

              Text {
                width: parent.width
                text: root.headerSubtitle
                elide: Text.ElideRight
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Row {
              id: actionsRow
              anchors.right: parent.right
              anchors.verticalCenter: titleColumn.verticalCenter
              spacing: Style.spacing.sm

              PanelActionButton {
                iconText: root.settingsView ? "✕" : "󰒓"
                tooltipText: root.settingsView ? "Close settings (Esc)" : "Settings (p)"
                foreground: root.contentForeground
                onClicked: root.settingsView = !root.settingsView
              }
            }
          }

          PanelSeparator {
            foreground: root.contentForeground
          }

          // ---- Settings view ---------------------------------------------
          Column {
            id: settingsColumn
            width: parent.width
            visible: root.settingsView
            height: visible ? implicitHeight : 0
            spacing: Style.spacing.md

            PanelSectionHeader {
              text: "ACCOUNT"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Text {
              width: parent.width
              text: "Paste your Todoist personal API token — Todoist → Settings → Integrations → Developer."
              wrapMode: Text.WordWrap
              color: Qt.darker(root.contentForeground, 1.3)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            TextField {
              id: tokenField
              width: parent.width
              password: true
              placeholderText: root.apiToken !== "" ? "Token saved — paste a new one to replace it" : "API token"
              text: root.tokenDraft
              onTextChanged: root.tokenDraft = text
              onAccepted: root.saveToken()
            }

            Row {
              spacing: Style.spacing.sm

              Button {
                text: "Save token"
                enabled: root.tokenDraft.trim() !== ""
                onClicked: root.saveToken()
              }

              Button {
                text: "Remove token"
                visible: root.apiToken !== ""
                onClicked: root.clearToken()
              }
            }

            PanelSeparator {
              foreground: root.contentForeground
            }

            PanelSectionHeader {
              text: "DEFAULT FILTER"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Text {
              width: parent.width
              text: "Todoist filter syntax (e.g. \"today | overdue\", \"#Work & !subtask\") — applied as the \"custom\" view."
              wrapMode: Text.WordWrap
              color: Qt.darker(root.contentForeground, 1.3)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Row {
              width: parent.width
              spacing: Style.spacing.sm

              TextField {
                id: filterField
                width: parent.width - filterApplyButton.width - Style.spacing.sm
                text: root.filterQuery
                onAccepted: root.applyFilter(text)
              }

              Button {
                id: filterApplyButton
                text: "Apply"
                onClicked: root.applyFilter(filterField.text)
              }
            }

            PanelSeparator {
              foreground: root.contentForeground
            }

            Column {
              width: parent.width
              spacing: Style.spacing.sm

              PanelSectionHeader {
                text: "KEYBOARD SHORTCUT"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
              }

              Text {
                width: parent.width
                text: root.keybindCombo !== "" ? ("Current: " + root.keybindCombo) : "No shortcut set."
                color: Qt.darker(root.contentForeground, 1.3)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Row {
                visible: !root.recordingKeybind
                spacing: Style.spacing.sm

                Button {
                  text: "Ctrl+Super+Y"
                  selected: root.keybindCombo === "CTRL + SUPER + Y"
                  enabled: root.keybindApplyStatus !== "applying" && root.keybindCombo !== "CTRL + SUPER + Y"
                  onClicked: root.applyKeybindCombo("CTRL + SUPER + Y")
                }

                Button {
                  text: "Record custom…"
                  enabled: root.keybindApplyStatus !== "applying"
                  onClicked: root.startRecordingKeybind()
                }

                Button {
                  text: "Remove"
                  visible: root.keybindCombo !== ""
                  enabled: root.keybindApplyStatus !== "applying"
                  onClicked: root.removeKeybindCombo()
                }
              }

              Column {
                visible: root.recordingKeybind
                width: parent.width
                spacing: Style.spacing.xs

                Rectangle {
                  width: parent.width
                  height: Style.spacing.controlHeight + Style.spacing.sm * 2
                  radius: Style.cornerRadius
                  color: Style.hoverFillFor(root.contentForeground, Color.accent)
                  border.width: 1
                  border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.4)

                  Text {
                    anchors.centerIn: parent
                    text: root.pendingKeybindCombo !== "" ? root.pendingKeybindCombo : "Press a shortcut…"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                  }

                  Item {
                    id: keybindRecorder
                    anchors.fill: parent
                    focus: root.recordingKeybind
                    Keys.onPressed: function(event) { root.handleKeybindRecordKey(event) }
                  }
                }

                Text {
                  width: parent.width
                  text: root.keybindRecordError !== "" ? root.keybindRecordError : "Hold your modifiers and press a key. Esc cancels."
                  color: root.keybindRecordError !== "" ? Color.urgent : Qt.darker(root.contentForeground, 1.4)
                  wrapMode: Text.WordWrap
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }

                Row {
                  spacing: Style.spacing.sm

                  Button {
                    text: "Apply"
                    enabled: root.pendingKeybindCombo !== "" && root.keybindApplyStatus !== "applying"
                    onClicked: root.applyKeybindCombo(root.pendingKeybindCombo)
                  }

                  Button {
                    text: "Cancel"
                    onClicked: root.cancelRecordingKeybind()
                  }
                }
              }

              Text {
                visible: root.keybindApplyStatus === "error"
                width: parent.width
                text: root.keybindApplyError
                color: Color.urgent
                wrapMode: Text.WordWrap
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Text {
                width: parent.width
                text: "Applies immediately by editing ~/.config/hypr/bindings.lua (backed up first) and reloading Hyprland. Any error rolls the change back automatically."
                color: Qt.darker(root.contentForeground, 1.5)
                wrapMode: Text.WordWrap
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

            PanelSeparator {
              foreground: root.contentForeground
            }

            Column {
              width: parent.width
              spacing: Style.spacing.sm

              PanelSectionHeader {
                text: "GENERAL"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
              }

              Row {
                spacing: Style.spacing.sm

                Button {
                  text: root.loading ? "Refreshing…" : "Refresh now"
                  enabled: root.apiToken !== "" && !root.loading
                  onClicked: root.refresh()
                }

                Button {
                  text: "Keyboard shortcuts"
                  onClicked: root.helpOpen = true
                }
              }
            }

            PanelSeparator {
              foreground: root.contentForeground
            }

            Column {
              width: parent.width
              spacing: Style.spacing.sm

              PanelSectionHeader {
                text: "ADVANCED"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
              }

              Text {
                width: parent.width
                text: "Popup size — fixed regardless of task count; content scrolls instead of resizing the panel."
                wrapMode: Text.WordWrap
                color: Qt.darker(root.contentForeground, 1.3)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Row {
                spacing: Style.spacing.sm

                PanelActionButton {
                  iconText: "−"
                  foreground: root.contentForeground
                  onClicked: root.setPanelWidth(root.panelWidth - 20)
                }

                Text {
                  text: "W " + root.panelWidth
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                PanelActionButton {
                  iconText: "+"
                  foreground: root.contentForeground
                  onClicked: root.setPanelWidth(root.panelWidth + 20)
                }
              }

              Row {
                spacing: Style.spacing.sm

                PanelActionButton {
                  iconText: "−"
                  foreground: root.contentForeground
                  onClicked: root.setPanelHeight(root.panelHeight - 20)
                }

                Text {
                  text: "H " + root.panelHeight
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                PanelActionButton {
                  iconText: "+"
                  foreground: root.contentForeground
                  onClicked: root.setPanelHeight(root.panelHeight + 20)
                }
              }
            }
          }

          // ---- Task list view ---------------------------------------------
          Column {
            id: taskColumn
            width: parent.width
            visible: !root.settingsView
            height: visible ? implicitHeight : 0
            spacing: Style.spacing.md

            Row {
              width: parent.width
              spacing: Style.spacing.sm

              TextField {
                id: quickAddField
                width: parent.width - addButton.width - Style.spacing.sm
                enabled: root.apiToken !== ""
                placeholderText: "Add a task… (p1, #Project, tomorrow at 5pm)"
                text: root.quickAddText
                onTextChanged: root.quickAddText = text
                onAccepted: root.submitQuickAdd()
                // Escape here just leaves the field (back to normal keyboard
                // nav) rather than falling through to the panel's own
                // Escape, which would otherwise do nothing while blocked.
                Keys.onEscapePressed: keyCatcher.forceActiveFocus()
              }

              Button {
                id: addButton
                text: root.quickAddSubmitting ? "Adding…" : "Add"
                enabled: root.apiToken !== "" && !root.quickAddSubmitting && root.quickAddText.trim() !== ""
                onClicked: root.submitQuickAdd()
              }
            }

            // Segmented-control look: zero spacing between the three
            // Buttons, differentiated only by the selected-state fill —
            // tab through them with Tab/Shift+Tab.
            Row {
              width: parent.width
              visible: root.apiToken !== ""
              height: visible ? implicitHeight : 0
              spacing: 0

              Button {
                text: "Today"
                selected: root.quickView === "today"
                onClicked: root.selectQuickView("today")
              }

              Button {
                text: "Inbox"
                selected: root.quickView === "inbox"
                onClicked: root.selectQuickView("inbox")
              }

              Button {
                text: "All"
                selected: root.quickView === "all"
                onClicked: root.selectQuickView("all")
              }
            }

            PanelSeparator {
              foreground: root.contentForeground
            }

            PanelSectionHeader {
              visible: root.apiToken !== ""
              height: visible ? implicitHeight : 0
              text: root.quickViewLabel
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            ListView {
              id: taskListView
              width: parent.width
              height: Math.min(contentHeight, Style.space(320))
              spacing: Style.spacing.sm
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              interactive: contentHeight > height
              model: root.tasks
              currentIndex: root.selectedTaskIndex

              delegate: TaskRow {
                id: delegateRow
                required property var modelData
                required property int index
                width: taskListView.width
                task: modelData
                rowIndex: index
                hasCursor: root.taskCursorActive && index === root.selectedTaskIndex
              }
            }

            Text {
              // Only shown for the initial fetch on an empty list — a
              // background/periodic refresh of an already-populated list
              // stays quiet rather than growing the panel with a redundant
              // "Loading…" row underneath tasks that are already showing.
              visible: root.loading && root.tasks.length === 0
              height: visible ? implicitHeight : 0
              width: parent.width
              text: "Loading…"
              color: Qt.darker(root.contentForeground, 1.3)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              visible: !root.loading && root.tasks.length === 0 && root.errorText === "" && root.apiToken !== ""
              height: visible ? implicitHeight : 0
              width: parent.width
              text: "Nothing due. You're clear."
              color: Qt.darker(root.contentForeground, 1.3)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              visible: root.errorText !== ""
              height: visible ? implicitHeight : 0
              width: parent.width
              text: root.errorText
              color: Color.urgent
              wrapMode: Text.WordWrap
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }

      // Overlay, declared after Flickable so it paints on top of it.
      ConfirmDialog {
        id: confirmDialog
        anchors.fill: parent
        message: "Delete \"" + root.pendingDeleteTaskContent + "\"?"
        confirmText: "Delete"
        background: Color.popups.background
        foreground: root.contentForeground
        onCanceled: root.cancelDeleteTask()
        onConfirmed: root.confirmDeleteTask()

        Item {
          anchors.fill: parent
          focus: confirmDialog.opened
          Keys.onPressed: function(event) {
            confirmDialog.handleKey(event)
            event.accepted = true
          }
        }
      }

      // Shortcuts help, toggled by "?" or the header's "?" button. Declared
      // last so it paints above everything, including the confirm dialog.
      Item {
        id: helpOverlay
        anchors.fill: parent
        visible: root.helpOpen

        Rectangle {
          anchors.fill: parent
          color: Util.alpha(Color.background, 0.75)

          MouseArea {
            anchors.fill: parent
            onClicked: root.helpOpen = false
          }

          BorderSurface {
            id: helpCard
            anchors.centerIn: parent
            // Content insets (border + padding) aren't applied to children
            // automatically — they're exposed as contentXInset properties
            // that have to be applied by hand, same as Ui/ConfirmDialog.qml
            // does. Skipping that the first time round is what pushed text
            // right up against (and past) the border.
            width: Math.min(parent.width - Style.space(24), Style.space(340))
            height: Math.min(parent.height - Style.space(24),
              helpCard.contentTopInset + helpCard.contentBottomInset + helpColumn.implicitHeight + Style.space(8))
            color: Color.popups.background
            borderSpec: Border.flat(Color.accent, Style.normalBorderWidth)
            radius: Style.cornerRadius
            padding: Style.space(16)

            MouseArea {
              anchors.fill: parent
              onClicked: {}
            }

            Item {
              anchors.fill: parent
              anchors.topMargin: helpCard.contentTopInset
              anchors.rightMargin: helpCard.contentRightInset
              anchors.bottomMargin: helpCard.contentBottomInset
              anchors.leftMargin: helpCard.contentLeftInset

              Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: helpColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                  id: helpColumn
                  width: parent.width
                  spacing: Style.spacing.sm

                  Text {
                    text: "Keyboard shortcuts"
                    font.bold: true
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.title
                  }

                  Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                    text: "Tab / Shift+Tab — cycle Today → Inbox → All\n"
                      + "t / i / a — jump to Today / Inbox / All\n"
                      + "p — toggle Settings\n"
                      + "↑/↓ or k/j — move task selection\n"
                      + "Enter — open task on Todoist\n"
                      + "Space — complete task\n"
                      + "e — edit task title\n"
                      + "x — delete task\n"
                      + "q — focus Add-a-task\n"
                      + "r — refresh\n"
                      + "Escape — back / close\n"
                      + "? — toggle this help"
                  }
                }
              }
            }
          }

          Item {
            anchors.fill: parent
            focus: root.helpOpen
            Keys.onEscapePressed: root.helpOpen = false
            Keys.onPressed: function(event) {
              if (event.text === "?") { root.helpOpen = false; event.accepted = true }
            }
          }
        }
      }
    }
  }
}
