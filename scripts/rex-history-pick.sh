#!/bin/bash
# Fuzzy-search zsh history with fzf and type the pick into a Rex pane.
# Usage: rex-history-pick BLOCK_ID
# Run by the `history_search` action in rex/init.lua, inside a floating pane.

set -euo pipefail

origin="${1:?usage: rex-history-pick BLOCK_ID}"
histfile="${HISTFILE:-$HOME/.zsh_history}"

# zsh writes a multi-line command as lines ending in a backslash, and with
# EXTENDED_HISTORY prefixes each entry with ": <time>:<duration>;". Rebuild
# whole entries, then print them newest first with duplicates dropped, each
# ended by NUL so fzf keeps multi-line commands together.
entries() {
  awk '
    {
      if (pending != "") { line = pending "\n" $0 } else { line = $0; sub(/^: [0-9]+:[0-9]+;/, "", line) }
      if (line ~ /\\$/) { pending = substr(line, 1, length(line) - 1); next }
      pending = ""
      if (line != "") cmds[n++] = line
    }
    END {
      for (i = n - 1; i >= 0; i--) {
        if (!(cmds[i] in seen)) { seen[cmds[i]] = 1; printf "%s%c", cmds[i], 0 }
      }
    }
  ' "$histfile"
}

# Enter types the pick at the prompt. ctrl-x, which Rex sends for cmd+enter
# (see rex/init.lua), types it and presses Enter too.
{
  IFS= read -r -d '' key
  IFS= read -r -d '' pick
} < <(entries | fzf --read0 --print0 --expect=ctrl-x --scheme=history \
  --no-sort --height=100% --prompt='history> ' --border=none) || exit 0

if [ "$key" = ctrl-x ]; then
  pick+=$'\r'
fi
rex send -b "$origin" "$pick"
