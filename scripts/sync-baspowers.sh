#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
plugin_root="$repo_root/submodules/baspowers"
codex_bin=${CODEX_BASPOWERS_CODEX_BIN:-codex}
claude_bin=${CODEX_BASPOWERS_CLAUDE_BIN:-claude}
legacy_name='super''powers'
codex_local=baspowers@baspowers-dev
codex_fallback="$legacy_name@openai-curated"
claude_local=baspowers@baspowers-dev
claude_fallback="$legacy_name@claude-plugins-official"
legacy_local="$legacy_name@$legacy_name-dev"
legacy_marketplace="$legacy_name-dev"

if [[ ! -f "$plugin_root/.agents/plugins/marketplace.json" ]]; then
  printf 'Baspowers submodule is missing. Run git submodule update --init submodules/baspowers.\n' >&2
  exit 1
fi

plugins=$("$codex_bin" plugin list --json)
compact_plugins=${plugins//[[:space:]]/}
if { grep -Fq "\"pluginId\":\"$codex_local\"" <<<"$compact_plugins" ||
  grep -Fq "\"pluginId\":\"$legacy_local\"" <<<"$compact_plugins"; } &&
  ! grep -Fq "\"pluginId\":\"$codex_fallback\"" <<<"$compact_plugins"; then
  # Keep a working fallback installed until the local replacement validates.
  "$codex_bin" plugin add "$codex_fallback"
fi

if grep -Fq "\"pluginId\":\"$codex_local\"" <<<"$compact_plugins"; then
  "$codex_bin" plugin remove "$codex_local"
fi
if grep -Fq "\"pluginId\":\"$legacy_local\"" <<<"$compact_plugins"; then
  "$codex_bin" plugin remove "$legacy_local"
fi

marketplaces=$("$codex_bin" plugin marketplace list --json)
compact_marketplaces=${marketplaces//[[:space:]]/}
if grep -Fq '"name":"baspowers-dev"' <<<"$compact_marketplaces"; then
  "$codex_bin" plugin marketplace remove baspowers-dev
fi
if grep -Fq "\"name\":\"$legacy_marketplace\"" <<<"$compact_marketplaces"; then
  "$codex_bin" plugin marketplace remove "$legacy_marketplace"
fi

"$codex_bin" plugin marketplace add "$plugin_root"
"$codex_bin" plugin add "$codex_local"

plugins=$("$codex_bin" plugin list --json)
if ! grep -Fq "\"pluginId\":\"$codex_local\"" <<<"${plugins//[[:space:]]/}"; then
  printf 'Local Baspowers plugin did not install successfully.\n' >&2
  exit 1
fi

if grep -Fq "\"pluginId\":\"$codex_fallback\"" <<<"${plugins//[[:space:]]/}"; then
  "$codex_bin" plugin remove "$codex_fallback"
fi

printf 'Codex Baspowers plugin uses %s\n' "$plugin_root"

plugins=$("$claude_bin" plugin list --json)
compact_plugins=${plugins//[[:space:]]/}
if { grep -Fq "\"id\":\"$claude_local\"" <<<"$compact_plugins" ||
  grep -Fq "\"id\":\"$legacy_local\"" <<<"$compact_plugins"; } &&
  ! grep -Fq "\"id\":\"$claude_fallback\"" <<<"$compact_plugins"; then
  "$claude_bin" plugin install "$claude_fallback"
fi

if grep -Fq "\"id\":\"$claude_local\"" <<<"$compact_plugins"; then
  "$claude_bin" plugin uninstall "$claude_local"
fi
if grep -Fq "\"id\":\"$legacy_local\"" <<<"$compact_plugins"; then
  "$claude_bin" plugin uninstall "$legacy_local"
fi

marketplaces=$("$claude_bin" plugin marketplace list --json)
compact_marketplaces=${marketplaces//[[:space:]]/}
if grep -Fq '"name":"baspowers-dev"' <<<"$compact_marketplaces"; then
  "$claude_bin" plugin marketplace remove baspowers-dev
fi
if grep -Fq "\"name\":\"$legacy_marketplace\"" <<<"$compact_marketplaces"; then
  "$claude_bin" plugin marketplace remove "$legacy_marketplace"
fi

"$claude_bin" plugin marketplace add "$plugin_root"
"$claude_bin" plugin install "$claude_local"

plugins=$("$claude_bin" plugin list --json)
if ! grep -Fq "\"id\":\"$claude_local\"" <<<"${plugins//[[:space:]]/}"; then
  printf 'Local Baspowers plugin did not install successfully in Claude.\n' >&2
  exit 1
fi

if grep -Fq "\"id\":\"$claude_fallback\"" <<<"${plugins//[[:space:]]/}"; then
  "$claude_bin" plugin uninstall "$claude_fallback"
fi

printf 'Claude Baspowers plugin uses %s\n' "$plugin_root"
