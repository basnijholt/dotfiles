#!/usr/bin/env python3
import os
import sys
import struct
import glob
import json
import urllib.request
import datetime

CACHE_DIR = os.path.expanduser("~/.cache/llama.cpp/")

# GGUF Value Types
GGUF_TYPE_UINT8 = 0
GGUF_TYPE_INT8 = 1
GGUF_TYPE_UINT16 = 2
GGUF_TYPE_INT16 = 3
GGUF_TYPE_UINT32 = 4
GGUF_TYPE_INT32 = 5
GGUF_TYPE_FLOAT32 = 6
GGUF_TYPE_BOOL = 7
GGUF_TYPE_STRING = 8
GGUF_TYPE_ARRAY = 9
GGUF_TYPE_UINT64 = 10
GGUF_TYPE_INT64 = 11
GGUF_TYPE_FLOAT64 = 12


def read_string(f):
    len_bytes = f.read(8)
    if not len_bytes:
        return None
    length = struct.unpack("<Q", len_bytes)[0]
    # Safety cap for strings
    if length > 1000000:
        return f.read(length).decode("utf-8", errors="ignore")
    return f.read(length).decode("utf-8", errors="ignore")


def skip_value(f, val_type):
    if val_type == GGUF_TYPE_STRING:
        read_string(f)
    elif val_type == GGUF_TYPE_ARRAY:
        arr_type = struct.unpack("<I", f.read(4))[0]
        arr_len = struct.unpack("<Q", f.read(8))[0]
        for _ in range(arr_len):
            skip_value(f, arr_type)
    else:
        size_map = {
            GGUF_TYPE_UINT8: 1,
            GGUF_TYPE_INT8: 1,
            GGUF_TYPE_BOOL: 1,
            GGUF_TYPE_UINT16: 2,
            GGUF_TYPE_INT16: 2,
            GGUF_TYPE_UINT32: 4,
            GGUF_TYPE_INT32: 4,
            GGUF_TYPE_FLOAT32: 4,
            GGUF_TYPE_UINT64: 8,
            GGUF_TYPE_INT64: 8,
            GGUF_TYPE_FLOAT64: 8,
        }
        if val_type in size_map:
            f.seek(size_map[val_type], 1)
        else:
            raise ValueError(f"Unknown type {val_type}")


def read_value_scalar(f, val_type):
    if val_type == GGUF_TYPE_UINT32:
        return struct.unpack("<I", f.read(4))[0]
    if val_type == GGUF_TYPE_INT32:
        return struct.unpack("<i", f.read(4))[0]
    if val_type == GGUF_TYPE_UINT64:
        return struct.unpack("<Q", f.read(8))[0]
    if val_type == GGUF_TYPE_INT64:
        return struct.unpack("<q", f.read(8))[0]
    # If not a scalar type we care about, skip
    skip_value(f, val_type)
    return None


def read_gguf_info(filepath):
    try:
        with open(filepath, "rb") as f:
            magic = f.read(4)
            if magic != b"GGUF":
                return None

            f.read(4)  # Skip version
            tensor_count = struct.unpack("<Q", f.read(8))[0]
            kv_count = struct.unpack("<Q", f.read(8))[0]

            candidates_ctx = {}
            candidates_layers = {}

            for _ in range(kv_count):
                key = read_string(f)
                if key is None:
                    break

                val_type = struct.unpack("<I", f.read(4))[0]

                if key.endswith(".context_length") or key.endswith(
                    ".context_length_train"
                ):
                    val = read_value_scalar(f, val_type)
                    if val is not None:
                        candidates_ctx[key] = val
                elif key.endswith(".block_count"):
                    val = read_value_scalar(f, val_type)
                    if val is not None:
                        candidates_layers[key] = val
                else:
                    skip_value(f, val_type)

            # Resolve Context
            ctx = None
            non_train = {
                k: v for k, v in candidates_ctx.items() if not k.endswith("_train")
            }
            if non_train:
                ctx = max(non_train.values())
            elif candidates_ctx:
                ctx = max(candidates_ctx.values())

            # Resolve Layers
            layers = None
            if candidates_layers:
                # Usually there's only one block_count, e.g. llama.block_count
                layers = max(candidates_layers.values())

            return {
                "ctx": ctx,
                "layers": layers,
                "tensor_count": tensor_count,
            }

    except Exception:
        # print(f"Error parsing {filepath}: {e}")
        return None


def find_files(query):
    if os.path.exists(query) and os.path.isfile(query):
        return [query]

    repo = query
    tag = None

    if ":" in query:
        repo, tag = query.split(":", 1)

    safe_repo = repo.replace("/", "_")

    pattern = os.path.join(CACHE_DIR, f"*{safe_repo}*")
    candidates = glob.glob(pattern)

    valid_files = []
    for c in candidates:
        if c.endswith(".json") or c.endswith(".etag") or "downloadInProgress" in c:
            continue

        if tag:
            if tag.lower() not in c.lower():
                continue

        valid_files.append(c)

    return valid_files


def fetch_hf_date(repo):
    try:
        url = f"https://huggingface.co/api/models/{repo}"
        with urllib.request.urlopen(url, timeout=5) as response:
            data = json.load(response)
            date_str = data.get("createdAt")
            if date_str:
                dt = datetime.datetime.fromisoformat(date_str.replace("Z", "+00:00"))
                return dt.strftime("%Y-%m-%d")
    except Exception:
        pass
    return None


def main():
    if len(sys.argv) < 2:
        print("Usage: get_model_info.py <repo/name:tag> or <path/to/file>")
        sys.exit(1)

    query = sys.argv[1]
    files = find_files(query)

    repo_name = None
    if ":" in query and not os.path.exists(query):
        repo_name = query.split(":", 1)[0]
    elif not os.path.exists(query):
        repo_name = query

    if not files:
        print(f"No files found for '{query}'")
        sys.exit(1)

    total_size = sum(os.path.getsize(f) for f in files)
    size_gb = total_size / (1024**3)

    main_file = files[0]
    for f in files:
        if "mmproj" not in f and "split" not in f and f.endswith(".gguf"):
            main_file = f
            break
        elif "00001-of-" in f:
            main_file = f

    info = read_gguf_info(main_file)
    ctx = info["ctx"] if info else None
    layers = info["layers"] if info else "?"

    # Only print tensors if layers not found, or maybe just don't print tensors?
    # User specifically asked about "layers" being wrong.

    date_str = None
    if repo_name:
        date_str = fetch_hf_date(repo_name)

    if not date_str:
        date_str = "????"

    ctx_str = str(ctx) if ctx else "????"
    layers_str = str(layers) if layers != "?" and layers is not None else "?"

    print(
        f"# Uploaded {date_str}, size {size_gb:.1f} GB, max ctx: {ctx_str}, "
        f"layers: {layers_str}"
    )


if __name__ == "__main__":
    main()
