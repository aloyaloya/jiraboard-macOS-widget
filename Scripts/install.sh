#!/usr/bin/env bash
#
# Installs the built app into /Applications so its widget persists WITHOUT Xcode
# running. Run Scripts/build-release.sh first (or pass a path to a .app).
#
#   Scripts/install.sh                 # installs dist/JiraBoard.app
#   Scripts/install.sh /path/to.app    # installs a specific build
#
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${1:-dist/JiraBoard.app}"
if [ ! -d "$APP" ]; then
  echo "✗ Not found: $APP  — run Scripts/build-release.sh first."; exit 1
fi

DEST="/Applications/JiraBoard.app"
echo "· Installing → $DEST"
rm -rf "$DEST"
cp -R "$APP" "$DEST"
xattr -cr "$DEST" 2>/dev/null || true

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# CRITICAL: unregister every OTHER copy of the app that shares our bundle id
# (leftover build/, dist/ and DerivedData copies). If several bundles with the
# same id are registered, WidgetKit may load a STALE one — the widget then looks
# unchanged (old name, old sizes, old layout) no matter how many times you build.
echo "· Unregistering stale duplicate copies…"
for stale in \
  "$(pwd)/build/Build/Products/Release/JiraBoard.app" \
  "$(pwd)/dist/JiraBoard.app" \
  "$HOME"/Library/Developer/Xcode/DerivedData/JiraBoard-*/Build/Products/*/JiraBoard.app
do
  [ -e "$stale" ] || continue
  # Unregister BOTH the app AND its embedded widget extension: the .appex gets
  # its OWN LaunchServices registration, and a leftover .appex alone is enough to
  # make WidgetKit resolve the widget to a stale copy — the visible symptom is
  # "Edit Widget" silently doing nothing. Unregistering the .app does NOT cascade.
  "$LSREGISTER" -u "$stale/Contents/PlugIns/JiraBoardWidget.appex" 2>/dev/null || true
  "$LSREGISTER" -u "$stale" 2>/dev/null || true
done

# Register the /Applications copy as the canonical one.
"$LSREGISTER" -f "$DEST"

# Force the desktop-widget host to drop the OLD cached binary. Without this,
# macOS keeps rendering the previously-loaded widget code even after copying a
# new build over it — the widget looks unchanged until the next system reload.
echo "· Reloading widget host (chronod)…"
killall JiraBoardWidget 2>/dev/null || true
killall chronod 2>/dev/null || true   # launchd restarts it automatically
sleep 2

open "$DEST"

echo "✓ Installed. Add the widget: right-click desktop → Edit Widgets → “Jira Board”."
echo "  Configure it: right-click the widget → Edit Widget."
