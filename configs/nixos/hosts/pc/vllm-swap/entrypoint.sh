#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "[vllm-swap] ERROR: $*" >&2
  exit 1
}

require_model() {
  local model_dir="$1"
  local label="$2"
  local weights

  [[ -f "$model_dir/config.json" ]] || fail "$label is missing config.json: $model_dir"
  shopt -s nullglob
  weights=("$model_dir"/*.safetensors "$model_dir"/*.bin)
  shopt -u nullglob
  ((${#weights[@]} > 0)) || fail "$label has no model weight files: $model_dir"
}

apply_embedding_patch() {
  local package_dir=/usr/local/lib/python3.12/dist-packages/vllm
  local patch_file=/etc/club3090/qwen3_5-embed-quant.patch

  if patch --batch --forward --dry-run -p1 -d "$package_dir" <"$patch_file" >/dev/null 2>&1; then
    patch --batch --forward -p1 -d "$package_dir" <"$patch_file"
    echo "[vllm-swap] applied pinned HyperQwen quantized-embedding patch" >&2
  elif patch --batch --reverse --dry-run -p1 -d "$package_dir" <"$patch_file" >/dev/null 2>&1; then
    echo "[vllm-swap] quantized-embedding patch already applied" >&2
  else
    fail "quantized-embedding patch does not apply cleanly in either direction"
  fi
}

: "${TARGET_MODEL:?TARGET_MODEL must be set}"
: "${DRAFT_MODEL:?DRAFT_MODEL must be set}"
: "${SERVED_MODEL_NAME:?SERVED_MODEL_NAME must be set}"

require_model "$TARGET_MODEL" "target model"
require_model "$DRAFT_MODEL" "DFlash2 draft model"

if [[ "${PATCH_EMBEDDING:-0}" == 1 ]]; then
  apply_embedding_patch
fi

# The following pinned installers are idempotent and refuse startup on anchor
# drift. Keep them ahead of vLLM so a partial patch set can never serve traffic.
source /etc/club3090/detect_nvlink.sh
bash /etc/club3090/pr48375/install.sh
bash /etc/club3090/gdn-async-order/install.sh
bash /etc/club3090/dflash-dense-kv/install.sh
FI_PINQ_LIB_ALL=0 bash /etc/club3090/flashinfer-decode-pin/install.sh
bash /etc/club3090/fa2/install.sh
source /etc/club3090/fa2-runtime.env

all_reduce_args=()
if [[ "${_CUSTOM_AR_ENABLED:-${_NVLINK_ENABLED:-0}}" != 1 ]]; then
  all_reduce_args+=(--disable-custom-all-reduce)
fi

speculative_config=$(printf \
  '{"method":"dflash","model":"%s","num_speculative_tokens":7}' \
  "$DRAFT_MODEL")

exec vllm serve \
  "${all_reduce_args[@]}" \
  "$@" \
  --speculative-config "$speculative_config" \
  --override-generation-config \
  '{"temperature":0.7,"top_p":0.8,"top_k":20,"min_p":0.0,"presence_penalty":1.5,"repetition_penalty":1.0}'
