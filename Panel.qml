import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons

// Settings window for the Chrome Profile Router service: edit the
// domain -> profile table without touching config.json by hand.
//
// Summoned with: omarchy-shell shell summon chrome-profile-router "{}"
// (the launcher .desktop entry carries exactly that command).
// The service (DomainRouter.qml) stays the single source of truth —
// this window only snapshots its state on open and writes back on Save.
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null
  property var manifest: null
  // The live service singleton, injected because this property exists.
  property var service: null

  property bool opened: false
  property bool closingFromHost: false
  property string statusText: ""

  readonly property string pluginId: (manifest && manifest.id) ? String(manifest.id) : "chrome-profile-router"

  function open(payloadJson) {
    root.closingFromHost = false
    root.statusText = ""
    root.reloadFromService()
    root.opened = true
    window.visible = true
  }

  function close() {
    root.closingFromHost = true
    root.opened = false
    window.visible = false
  }

  function hideViaShell() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
    else
      root.close()
  }

  // Snapshot the service state into the editable row model.
  // Leaves statusText alone so a "Saved" note survives live refreshes.
  function reloadFromService() {
    rowModel.clear()
    var maps = (root.service && root.service.mappings) ? root.service.mappings : {}
    var keys = Object.keys(maps)
    keys.sort()
    for (var i = 0; i < keys.length; i++)
      rowModel.append({ domain: keys[i], profile: String(maps[keys[i]]) })
    defaultField.text = (root.service && root.service.defaultProfile)
      ? String(root.service.defaultProfile) : "Default"
  }

  function saveAll() {
    if (!root.service || typeof root.service.setProfileFor !== "function") {
      root.statusText = "Service not loaded — close and reopen this window."
      return
    }
    // Copy first: each write below re-triggers the config file watcher,
    // which refreshes rowModel while we are still iterating it.
    var pending = []
    for (var i = 0; i < rowModel.count; i++) {
      var entry = rowModel.get(i)
      var d = String(entry.domain || "").trim()
      var p = String(entry.profile || "").trim()
      if (d === "" || p === "")
        continue
      pending.push({ domain: d, profile: p })
    }
    for (var j = 0; j < pending.length; j++)
      root.service.setProfileFor(pending[j].domain, pending[j].profile)
    root.service.setDefaultProfile(defaultField.text)
    root.service.saveConfig()
    root.reloadFromService()
    root.statusText = "Saved \u2713 (" + pending.length + " rule" + (pending.length === 1 ? "" : "s") + ")"
  }

  // Follow outside edits (terminal setProfile, hand-edited file) live.
  Connections {
    target: root.service
    function onSettingsChanged() {
      if (root.opened)
        root.reloadFromService()
    }
  }

  ListModel {
    id: rowModel
  }

  FloatingWindow {
    id: window
    title: "Chrome Profile Router"
    color: Color.background
    implicitWidth: 560
    implicitHeight: 520
    minimumSize: Qt.size(480, 400)

    onVisibleChanged: {
      if (!visible && !root.closingFromHost)
        root.hideViaShell()
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 8

      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
          Layout.fillWidth: true
          text: "Website"
          color: Color.foreground
        }
        Text {
          Layout.preferredWidth: 160
          text: "Profile"
          color: Color.foreground
        }
        // Spacer matching the delete button below, so columns line up.
        Item {
          Layout.preferredWidth: 40
        }
      }

      ScrollView {
        id: scrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        Column {
          id: scrollColumn
          width: scrollView.availableWidth
          spacing: 8

          Text {
            width: parent.width
            visible: rowModel.count === 0
            wrapMode: Text.WordWrap
            text: "No rules yet — every link opens in the default profile."
            color: Color.foreground
          }

          Repeater {
            model: rowModel
            delegate: RowLayout {
              width: scrollColumn.width
              spacing: 8
              TextField {
                Layout.fillWidth: true
                placeholderText: "example.com"
                text: model.domain
                onTextChanged: rowModel.setProperty(index, "domain", text)
              }
              TextField {
                Layout.preferredWidth: 160
                placeholderText: "Profile 1"
                text: model.profile
                onTextChanged: rowModel.setProperty(index, "profile", text)
              }
              Button {
                Layout.preferredWidth: 40
                text: "\u2715"
                onClicked: rowModel.remove(index)
              }
            }
          }
        }
      }

      Button {
        text: "+ Add rule"
        onClicked: rowModel.append({ domain: "", profile: "" })
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
          text: "Default profile:"
          color: Color.foreground
        }
        TextField {
          id: defaultField
          Layout.fillWidth: true
          placeholderText: "Default"
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
          Layout.fillWidth: true
          elide: Text.ElideRight
          text: root.statusText
          color: Color.accent
        }
        Button {
          text: "Cancel"
          onClicked: root.hideViaShell()
        }
        Button {
          text: "Save"
          onClicked: root.saveAll()
        }
      }
    }
  }
}
