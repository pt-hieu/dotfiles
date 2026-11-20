#!/bin/bash
# Builds "Rex Markdown.app" into ~/Applications and makes it the default app
# for Markdown files, so Cmd-clicking a .md path in Rex opens it in nvim in a
# new pane. Safe to re-run. macOS only; needs duti (brew install duti).

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$HOME/Applications/Rex Markdown.app"
BUNDLE_ID="dev.brianpham.rex-md-opener"
PLIST="$APP/Contents/Info.plist"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

rm -rf "$APP"
mkdir -p "$(dirname "$APP")"
osacompile -o "$APP" "$SRC_DIR/main.applescript"
cp "$SRC_DIR/open-in-rex.sh" "$APP/Contents/Resources/open-in-rex.sh"

pb() { /usr/libexec/PlistBuddy -c "$1" "$PLIST"; }
# osacompile writes some of these keys and not others, so set or add each one.
put() { pb "Set :$1 $3" 2>/dev/null || pb "Add :$1 $2 $3"; }
put CFBundleIdentifier string "$BUNDLE_ID"
put CFBundleName string "Rex Markdown"
put LSUIElement bool true
pb "Delete :CFBundleDocumentTypes" 2>/dev/null || true
pb "Add :CFBundleDocumentTypes array"
pb "Add :CFBundleDocumentTypes:0 dict"
pb "Add :CFBundleDocumentTypes:0:CFBundleTypeName string Markdown Document"
pb "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Editor"
pb "Add :CFBundleDocumentTypes:0:LSHandlerRank string Owner"
pb "Add :CFBundleDocumentTypes:0:LSItemContentTypes array"
pb "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string net.daringfireball.markdown"

codesign --force --sign - "$APP"
"$LSREGISTER" -f "$APP"
duti -s "$BUNDLE_ID" net.daringfireball.markdown all
duti -s "$BUNDLE_ID" .md all
echo "  build   $APP (default for .md: $(duti -x md | tail -1))"
