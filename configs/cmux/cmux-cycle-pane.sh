#!/bin/zsh
# Cycle focus through cmux panes in order, wrapping at the ends (iTerm-style
# cmd+] / cmd+[). Workaround for https://github.com/manaflow-ai/cmux/pull/2639:
# cmux's goto_split:next/previous only move directionally left/right and skip
# vertically-split panes. Bound via Karabiner-Elements, scoped to cmux.
# Usage: cmux-cycle-pane.sh next|prev
set -euo pipefail

cli=/Applications/cmux.app/Contents/Resources/bin/cmux

panes=()
focused_idx=-1
i=0
while IFS= read -r line; do
  # list-panes lines look like: "* pane:4  [1 surface]  [focused]"
  pane=$(echo "$line" | grep -o 'pane:[0-9]*' | head -1) || continue
  [[ -n "$pane" ]] || continue
  panes+=("$pane")
  [[ "$line" == *'[focused]'* ]] && focused_idx=$i
  ((i += 1))
done < <("$cli" list-panes)

count=${#panes[@]}
((count > 1)) || exit 0
((focused_idx >= 0)) || focused_idx=0

if [[ "${1:-next}" == "prev" ]]; then
  target=$(((focused_idx - 1 + count) % count))
else
  target=$(((focused_idx + 1) % count))
fi

# zsh arrays are 1-based
exec "$cli" focus-pane --pane "${panes[$((target + 1))]}"
