import QtQuick
import Quickshell
import Quickshell.Io

// DomainRouter — headless Omarchy service that routes URLs to Chromium
// profile directories based on the domain mappings in config.json.
//
// There is no UI. URLs arrive over IPC (see the IpcHandler at the bottom):
//   omarchy-shell chrome-profile-router routeUrl 'https://x.com/home'
//   omarchy-shell chrome-profile-router profileFor 'https://x.com/home'  (dry run)
//   omarchy-shell chrome-profile-router ping
Item {
  id: root

  // Injected by omarchy-shell. For third-party plugins `shell` is a
  // capability-scoped facade, not the full host object.
  property var shell: null
  property var manifest: null

  // ----- Routing table (defaults; replaced once config.json loads) -----
  property string defaultProfile: "Default"
  property var mappings: ({})

  // Absolute path of the config.json sitting next to this file.
  // Qt.resolvedUrl() keeps working if the plugin folder is renamed or
  // forked; the $HOME path is a fallback for shells that resolve oddly.
  // NOTE: `omarchy plugin add` clones the repo into
  // ~/.config/omarchy/plugins/<manifest-id>/, so with id "chrome-profile-router"
  // the fallback path matches the real install location.
  readonly property string configPath: {
    var fromUrl = String(Qt.resolvedUrl("config.json") || "");
    if (fromUrl.indexOf("file://") === 0) {
      var p = fromUrl.slice(7);
      try {
        return decodeURIComponent(p);
      } catch (e) {
        return p;
      }
    }
    return (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/chrome-profile-router/config.json";
  }

  // Parse one config.json body and apply it to the live properties.
  // Invalid JSON is ignored so a half-saved edit never kills routing.
  function applyConfigText(raw) {
    var parsed = null;
    try {
      parsed = JSON.parse(String(raw || ""));
    } catch (e) {
      console.warn("chrome-profile-router: ignoring invalid config.json:", e);
      return;
    }
    if (!parsed || typeof parsed !== "object")
      return;
    if (typeof parsed.default_profile === "string" && parsed.default_profile !== "")
      root.defaultProfile = parsed.default_profile;
    if (parsed.mappings && typeof parsed.mappings === "object")
      root.mappings = parsed.mappings;
  }

  // Pick a profile for a URL. Case-insensitive substring match against
  // every mapping key; the LONGEST matching domain wins so
  // "mail.github.com" beats "github.com". Falls back to default_profile.
  function profileForUrl(rawUrl) {
    var url = String(rawUrl || "").toLowerCase();
    var bestLen = -1;
    var winner = root.defaultProfile;
    var keys = Object.keys(root.mappings || {});
    for (var i = 0; i < keys.length; i++) {
      var domain = String(keys[i] || "").toLowerCase();
      if (domain === "" || url.indexOf(domain) === -1)
        continue;
      if (domain.length > bestLen) {
        bestLen = domain.length;
        winner = String(root.mappings[keys[i]]);
      }
    }
    return winner;
  }

  // Launch chromium with the routed profile. Fire-and-forget: chromium
  // daemonizes itself, so the shell must not block waiting on it.
  function routeUrl(rawUrl) {
    var url = String(rawUrl || "");
    if (url === "")
      return "error: empty url";
    var profile = profileForUrl(url);
    Quickshell.execDetached(["chromium", "--profile-directory=" + profile, url]);
    return "ok profile=" + profile;
  }

  // config.json loads once at startup and hot-reloads on every save,
  // so editing mappings needs no shell restart.
  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyConfigText(text())
    onLoadFailed: console.warn("chrome-profile-router: cannot read " + root.configPath + ", using defaults")
    onFileChanged: reload()
  }

  Component.onCompleted: configFile.reload()

  // This is the intercept hook: each function becomes
  // `omarchy-shell chrome-profile-router <name> <arg>`.
  // (A pure `service` plugin is NOT reachable via
  // `omarchy-shell shell call <id> ...` — that path only sees
  // panel/overlay/menu loaders — so the service owns its IPC target.)
  IpcHandler {
    target: "chrome-profile-router"

    function ping(): string {
      return "ok";
    }
    function routeUrl(url: string): string {
      return root.routeUrl(url);
    }
    // Dry run: report the profile without launching anything.
    function profileFor(url: string): string {
      return root.profileForUrl(url);
    }
    function configPath(): string {
      return root.configPath;
    }
  }
}
