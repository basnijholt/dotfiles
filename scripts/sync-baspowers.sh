#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
plugin_root="$repo_root/submodules/baspowers"
codex_bin=${BASPOWERS_CODEX_BIN:-codex}
claude_bin=${BASPOWERS_CLAUDE_BIN:-claude}
local_plugin=baspowers@baspowers-dev
legacy='super''powers'

if [[ ! -f "$plugin_root/.agents/plugins/marketplace.json" ]]; then
  printf 'Baspowers submodule is missing. Run git submodule update --init submodules/baspowers.\n' >&2
  exit 1
fi

ignore_failure() {
  "$@" >/dev/null 2>&1 || true
}

ignore_failure "$codex_bin" plugin remove "$local_plugin"
ignore_failure "$codex_bin" plugin marketplace remove baspowers-dev
"$codex_bin" plugin marketplace add "$plugin_root"
"$codex_bin" plugin add "$local_plugin"

plugins=$("$codex_bin" plugin list --json)
if ! grep -Fq '"pluginId":"baspowers@baspowers-dev"' <<<"${plugins//[[:space:]]/}"; then
  printf 'Codex did not install the local Baspowers plugin.\n' >&2
  exit 1
fi

ignore_failure "$codex_bin" plugin remove "$legacy@$legacy-dev"
ignore_failure "$codex_bin" plugin marketplace remove "$legacy-dev"
ignore_failure "$codex_bin" plugin remove "$legacy@openai-curated"
printf 'Codex Baspowers plugin uses %s\n' "$plugin_root"

ignore_failure "$claude_bin" plugin uninstall "$local_plugin"
ignore_failure "$claude_bin" plugin marketplace remove baspowers-dev
"$claude_bin" plugin marketplace add "$plugin_root"
"$claude_bin" plugin install "$local_plugin"

plugins=$("$claude_bin" plugin list --json)
if ! grep -Fq '"id":"baspowers@baspowers-dev"' <<<"${plugins//[[:space:]]/}"; then
  printf 'Claude did not install the local Baspowers plugin.\n' >&2
  exit 1
fi

ignore_failure "$claude_bin" plugin uninstall "$legacy@$legacy-dev"
ignore_failure "$claude_bin" plugin marketplace remove "$legacy-dev"
ignore_failure "$claude_bin" plugin uninstall "$legacy@claude-plugins-official"
printf 'Claude Baspowers plugin uses %s\n' "$plugin_root"
