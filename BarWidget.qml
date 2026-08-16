import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar entry point: a small text pill ("✓" or "✓ 3") and the host for the
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

  readonly property string displayLabel: {
    if (!panelLoader.item || panelLoader.item.apiToken === "") return "✓"
    var count = panelLoader.item.taskCount
    return count > 0 ? ("✓ " + count) : "✓"
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

  // Reserves room for the widest realistic label ("✓ 999") so the pill's
  // own width — and with it the popup's centered-under-icon anchor point —
  // never shifts as the task count's digit-length changes (e.g. "✓ 7" vs
  // "✓ 15"). Horizontal bar mode only; vertical mode already uses a fixed
  // icon-slot width regardless of label.
  TextMetrics {
    id: widthMetrics
    font.family: button.fontFamily
    font.pixelSize: button.fontSize
    text: "✓ 999"
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayLabel
    tooltipText: "Todoist"
    horizontalMargin: 8.75
    verticalPadding: 8.75
    fixedWidth: root.vertical ? -1 : Math.ceil(widthMetrics.width + Style.spaceReal(horizontalMargin) * 2)

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
