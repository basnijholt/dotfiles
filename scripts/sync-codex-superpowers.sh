#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
plugin_root="$repo_root/submodules/superpowers"
codex_bin=${CODEX_SUPERPOWERS_CODEX_BIN:-codex}

if [[ ! -f "$plugin_root/.agents/plugins/marketplace.json" ]]; then
  printf 'Superpowers submodule is missing. Run git submodule update --init submodules/superpowers.\n' >&2
  exit 1
fi

plugins=$("$codex_bin" plugin list --json)
compact_plugins=${plugins//[[:space:]]/}
if grep -Fq '"pluginId":"superpowers@superpowers-dev"' <<<"$compact_plugins" &&
  ! grep -Fq '"pluginId":"superpowers@openai-curated"' <<<"$compact_plugins"; then
  # Keep a working fallback installed until the local replacement validates.
  "$codex_bin" plugin add superpowers@openai-curated
fi

if grep -Fq '"pluginId":"superpowers@superpowers-dev"' <<<"$compact_plugins"; then
  "$codex_bin" plugin remove superpowers@superpowers-dev
fi

marketplaces=$("$codex_bin" plugin marketplace list --json)
if grep -Fq '"name":"superpowers-dev"' <<<"${marketplaces//[[:space:]]/}"; then
  "$codex_bin" plugin marketplace remove superpowers-dev
fi

"$codex_bin" plugin marketplace add "$plugin_root"
"$codex_bin" plugin add superpowers@superpowers-dev

plugins=$("$codex_bin" plugin list --json)
if ! grep -Fq '"pluginId":"superpowers@superpowers-dev"' <<<"${plugins//[[:space:]]/}"; then
  printf 'Local Superpowers plugin did not install successfully.\n' >&2
  exit 1
fi

if grep -Fq '"pluginId":"superpowers@openai-curated"' <<<"${plugins//[[:space:]]/}"; then
  "$codex_bin" plugin remove superpowers@openai-curated
fi

printf 'Codex Superpowers plugin uses %s\n' "$plugin_root"
