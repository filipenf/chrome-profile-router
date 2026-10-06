#!/bin/bash
# Install the Chrome Profile Router xdg handler after the plugin itself is installed:
#   omarchy plugin add https://github.com/filipenf/chrome-profile-router.git --enable --yes
#   ./install.sh
set -euo pipefail

PLUGIN_ID="chrome-profile-router"

echo "==> Rescanning shell plugins"
omarchy-shell shell rescanPlugins

echo "==> Enabling ${PLUGIN_ID}"
omarchy plugin enable "${PLUGIN_ID}"

echo "==> Validating plugin"
omarchy plugin validate "$HOME/.config/omarchy/plugins/${PLUGIN_ID}"

echo "==> Installing URL handler wrapper to ~/.local/bin"
install -Dm755 chrome-profile-router-open "$HOME/.local/bin/chrome-profile-router-open"

echo "==> Registering .desktop handler"
install -Dm644 chrome-profile-router.desktop "$HOME/.local/share/applications/chrome-profile-router.desktop"
echo "==> Registering settings window launcher"
install -Dm644 chrome-profile-router-settings.desktop "$HOME/.local/share/applications/chrome-profile-router-settings.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo "==> Setting Chrome Profile Router as the default browser"
xdg-settings set default-web-browser chrome-profile-router.desktop
xdg-mime default chrome-profile-router.desktop x-scheme-handler/http x-scheme-handler/https

echo "==> Verifying (no browser is launched by these)"
omarchy-shell chrome-profile-router ping
xdg-settings get default-web-browser
echo "--- dry run routing ---"
omarchy-shell chrome-profile-router profileFor 'https://x.com/home'
omarchy-shell chrome-profile-router profileFor 'https://github.com/omarchy'
echo "Done. Test for real with: xdg-open 'https://x.com/home'"
