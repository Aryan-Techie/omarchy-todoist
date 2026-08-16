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
  readonly property string stateDir: homeDir + "/.local/state/omarchy/io.github.aryan-techie.todoist"
  readonly property string settingsPath: stateDir + "/settings.json"

  property string apiToken: ""
  property string filterQuery: "today | overdue"
  property bool settingsLoaded: false
  property bool settingsView: true

  property var tasks: []
  readonly property int taskCount: tasks.length

  property bool loading: false
  property string errorText: ""

  property string tokenDraft: ""
  property string quickAddText: ""
  property bool quickAddSubmitting: false
  property var actionQueue: []

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  // ---- Lifecycle. Matches the clock/weather contract: open() refreshes
  //      before showing so the list is never more than one popup-open stale.
  function open() {
    if (root.apiToken !== "") refresh()
    root.controller.show()
    Qt.callLater(function() {
      if (!root.opened) return
      if (root.settingsView) tokenField.forceActiveFocus()
      else quickAddField.forceActiveFocus()
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
    root.settingsLoaded = true
    root.settingsView = root.apiToken === ""
    if (root.apiToken !== "") refresh()
  }

  function persistSettings() {
    settingsFile.setText(JSON.stringify({ apiToken: root.apiToken, filter: root.filterQuery }, null, 2) + "\n")
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
    if (next === root.filterQuery) return
    root.filterQuery = next
    persistSettings()
    refresh()
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
    listProc.command = ["curl", "-fsS", "--max-time", "10",
      "-H", "Authorization: Bearer " + root.apiToken,
      root.apiBase + "/tasks/filter?query=" + encodeURIComponent(root.filterQuery) + "&lang=en"]
    listProc.running = true
  }

  // ---- Quick add.
  function submitQuickAdd() {
    var content = Model.safeTrim(root.quickAddText)
    if (content === "" || root.quickAddSubmitting || root.apiToken === "") return
    root.quickAddSubmitting = true
    root.errorText = ""
    createProc.command = ["curl", "-fsS", "--max-time", "10", "-X", "POST",
      "-H", "Authorization: Bearer " + root.apiToken,
      "-H", "Content-Type: application/json",
      "-d", JSON.stringify({ content: content }),
      root.apiBase + "/tasks"]
    createProc.running = true
  }

  // ---- Complete task. Removes the row immediately (optimistic); a failed
  //      close re-adds it by re-fetching rather than trying to reinsert it
  //      at the right sorted position by hand.
  function requestComplete(taskId) {
    root.actionQueue.push(taskId)
    root.tasks = root.tasks.filter(function(t) { return !t || t.id !== taskId })
    processActionQueue()
  }

  function processActionQueue() {
    if (actionProc.running || root.actionQueue.length === 0) return
    var taskId = root.actionQueue.shift()
    actionProc.command = ["curl", "-fsS", "--max-time", "10", "-X", "POST",
      "-H", "Authorization: Bearer " + root.apiToken,
      root.apiBase + "/tasks/" + encodeURIComponent(taskId) + "/close"]
    actionProc.running = true
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

    readonly property bool overdue: Model.taskIsOverdue(task)
    readonly property string dueLabel: Model.taskDueLabel(task)
    readonly property color textColor: (task && task.priority === 4) ? Color.urgent : root.contentForeground

    height: Math.max(checkBtn.height, textColumn.implicitHeight) + Style.spacing.sm * 2

    PanelActionButton {
      id: checkBtn
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.topMargin: Style.spacing.sm
      iconText: "○"
      tooltipText: "Mark complete"
      foreground: row.textColor
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
        width: parent.width
        text: row.task ? row.task.content : ""
        color: row.textColor
        wrapMode: Text.WordWrap
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        visible: row.dueLabel !== ""
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
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: tokenField.activeFocus || filterField.activeFocus || quickAddField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

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
          Item {
            width: parent.width
            height: Math.max(titleText.implicitHeight, actionsRow.implicitHeight)

            Text {
              id: titleText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Todoist"
              font.bold: true
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              color: root.contentForeground
            }

            Row {
              id: actionsRow
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.sm

              PanelActionButton {
                iconText: "↻"
                tooltipText: "Refresh"
                foreground: root.contentForeground
                enabled: root.apiToken !== ""
                onClicked: root.refresh()
              }

              PanelActionButton {
                iconText: root.settingsView ? "✕" : "⚙"
                tooltipText: root.settingsView ? "Close settings" : "Settings"
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

            Text {
              width: parent.width
              text: "Filter — Todoist filter syntax (e.g. \"today | overdue\", \"#Work & !subtask\")"
              wrapMode: Text.WordWrap
              color: Qt.darker(root.contentForeground, 1.3)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            TextField {
              id: filterField
              width: parent.width
              text: root.filterQuery
              onAccepted: root.applyFilter(text)
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
                placeholderText: "Add a task…"
                text: root.quickAddText
                onTextChanged: root.quickAddText = text
                onAccepted: root.submitQuickAdd()
              }

              Button {
                id: addButton
                text: root.quickAddSubmitting ? "" : "Add"
                iconText: root.quickAddSubmitting ? "↻" : ""
                iconSpinning: root.quickAddSubmitting
                enabled: root.apiToken !== "" && !root.quickAddSubmitting && root.quickAddText.trim() !== ""
                onClicked: root.submitQuickAdd()
              }
            }

            PanelSeparator {
              foreground: root.contentForeground
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

              delegate: TaskRow {
                id: delegateRow
                required property var modelData
                width: taskListView.width
                task: modelData
              }
            }

            Text {
              visible: root.loading
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
    }
  }
}
