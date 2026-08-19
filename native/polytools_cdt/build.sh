#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
python_bin="$script_dir/.venv/bin/python"

if [ ! -x "$python_bin" ]; then
    echo "Native toolchain missing. Run: python3 -m venv native/polytools_cdt/.venv" >&2
    echo "Then: native/polytools_cdt/.venv/bin/python -m pip install -r native/polytools_cdt/requirements-native.txt" >&2
    exit 1
fi

cd "$script_dir"
exec "$python_bin" -m SCons platform=macos arch=arm64 target=template_debug "$@"
