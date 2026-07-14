#!/usr/bin/env bash
#
# Builds a standalone Release JiraBoard.app and zips it for a GitHub Release.
#
#   TEAM=2N6726VA44 Scripts/build-release.sh      # signed with your Apple team
#   Scripts/build-release.sh                        # ad-hoc (local machine only)
#
# Output: dist/JiraBoard.app  and  dist/JiraBoard.zip
#
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=Release
DERIVED=build
APP_PATH="$DERIVED/Build/Products/$CONFIG/JiraBoard.app"
TEAM="${TEAM:-}"

# Unique, monotonically increasing build number so WidgetKit invalidates its
# cached widget metadata (supportedFamilies, display name) on every install.
BUILD_NUMBER="$(date +%s)"

args=(-project JiraBoard.xcodeproj -scheme JiraBoard -configuration "$CONFIG"
      -derivedDataPath "$DERIVED" -destination 'platform=macOS'
      CURRENT_PROJECT_VERSION="$BUILD_NUMBER")
if [ -n "$TEAM" ]; then
  args+=(DEVELOPMENT_TEAM="$TEAM" -allowProvisioningUpdates)
else
  echo "· No TEAM set → ad-hoc signing (runs only on this Mac)."
  args+=(CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES)
fi

echo "· Building $CONFIG…"
rm -rf "$DERIVED" dist
xcodebuild "${args[@]}" build >/dev/null

echo "· Packaging…"
mkdir -p dist
cp -R "$APP_PATH" dist/
xattr -cr dist/JiraBoard.app 2>/dev/null || true
( cd dist && zip -qry JiraBoard.zip JiraBoard.app )

echo "✓ dist/JiraBoard.app"
echo "✓ dist/JiraBoard.zip  (attach this to a GitHub Release)"
