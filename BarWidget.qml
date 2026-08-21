import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar entry point: the Todoist mark, plus an optional task count to its
// right (Settings → Bar Count) — a plain WidgetButton with hand-built
// content instead of BarIconButton, since BarIconButton centers its icon
// slot and its inherited text label on the exact same point (no side-by-
// side layout) and this plugin wants both visible together. Host for the
// task-list popup. All Todoist state (token, tasks, fetching) lives in
// Panel.qml; this file only reads it back to decide what the pill shows.
BarWidget {
  id: root
  moduleName: "io.github.aryan-techie.todoist"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  // ---- Shape contract for shell.summon/hide/toggle routing:
  //      Bar.findPanelWidget requires open/close/opened on this root.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  readonly property bool hasToken: panelLoader.item ? panelLoader.item.apiToken !== "" : false
  readonly property int taskCount: panelLoader.item ? panelLoader.item.taskCount : 0

  // ---- Bar count (Settings → Bar Count). "hide" is the default — icon
  //      only, count shows in the tooltip. Any other mode also shows a
  //      plain number to the icon's right (see contentRow below).
  readonly property string barCountMode: panelLoader.item ? panelLoader.item.barCountMode : "hide"
  readonly property int barCountValue: panelLoader.item ? panelLoader.item.barCountValue : 0
  readonly property string barCountModeLabel: panelLoader.item ? panelLoader.item.barCountModeLabel : ""

  readonly property string tooltipText: {
    if (!root.hasToken) return "Todoist — not connected"
    if (root.barCountMode === "hide") {
      return root.taskCount > 0
        ? ("Todoist — " + root.taskCount + (root.taskCount === 1 ? " task" : " tasks"))
        : "Todoist — all clear"
    }
    return "Todoist — " + root.barCountValue + " " + root.barCountModeLabel
  }

  function injectPanelAndRefresh() {
    injectPanel()
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanelAndRefresh)
    }
  }

  IpcHandler {
    target: "io.github.aryan-techie.todoist"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.tooltipText
    labelVisible: false
    hasVisualContent: true
    fixedWidth: root.vertical ? -1 : Math.ceil(contentRow.implicitWidth + Style.spaceReal(horizontalMargin) * 2)
    fixedHeight: root.vertical ? Math.ceil(contentRow.implicitHeight + Style.spaceReal(verticalPadding) * 2) : -1

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(4)

      TodoistIcon {
        anchors.verticalCenter: parent.verticalCenter
        // Matches DropboxIcon/TailscaleIcon's own sizing convention: a bit
        // smaller than a full bar-icon slot so the mark has breathing room.
        iconSize: Style.space(12)
        color: root.bar ? root.bar.barForeground : Color.foreground
        opacity: root.hasToken ? 1.0 : 0.6
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hasToken && root.barCountMode !== "hide"
        text: root.barCountMode !== "hide" ? String(root.barCountValue) : ""
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.bar.iconFont
        renderType: Text.NativeRendering
      }
    }

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
