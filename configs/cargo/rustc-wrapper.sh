#!/usr/bin/env sh
# Wrapper that uses sccache if available, otherwise falls back to rustc
if command -v sccache >/dev/null 2>&1; then
	exec sccache "$@"
else
	exec "$@"
fi
