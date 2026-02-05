#!/bin/bash
# Wrapper that uses sccache if available, otherwise falls back to rustc
if command -v sccache &> /dev/null; then
    exec sccache "$@"
else
    exec rustc "$@"
fi
