#!/bin/bash
# Opens each file given as an argument in nvim, in a new Rex pane split to the
# right of the pane focused in the Rex app. Launches Rex first when it isn't
# running, and falls back to TextEdit when Rex doesn't come up. Called by the
# Rex Markdown app, which macOS uses as the default opener for Markdown files.

set -uo pipefail

REX_BUNDLE_ID="com.superlogical.rex"
WAIT_SECONDS=10

# Apps launched by macOS get a minimal PATH, so look in the Rex install too.
REX="$(command -v rex || true)"
if [ -z "$REX" ]; then
  REX="$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"
fi

# Prints the session the Rex app shows, or nothing when the app isn't
# connected. The server doesn't say which session is on screen, so with
# several sessions open this takes the first one the app has.
app_session() {
  "$REX" --autostart=false client ls --json 2>/dev/null |
    /usr/bin/python3 -c '
import json, sys
for c in json.load(sys.stdin)["clients"]:
    if c.get("info", {}).get("kind") == "app" and c.get("session_ids"):
        print(c["session_ids"][0])
        break
' 2>/dev/null
}

session="$(app_session)"
if [ -z "$session" ]; then
  open -b "$REX_BUNDLE_ID" 2>/dev/null
  for _ in $(seq "$WAIT_SECONDS"); do
    sleep 1
    session="$(app_session)"
    [ -n "$session" ] && break
  done
fi

for path in "$@"; do
  if [ -z "$session" ] || ! "$REX" --autostart=false split -s "$session" \
      -c "$(dirname "$path")" --label nvim -- nvim "$path" >/dev/null; then
    open -a TextEdit "$path"
  fi
done
