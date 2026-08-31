#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
python_bin="$script_dir/.venv/bin/python"

case "$(uname -s)" in
    Darwin) platform=macos ;;
    Linux) platform=linux ;;
    *)
        echo "PolyTools CDT supports macOS and Linux." >&2
        exit 1
        ;;
esac

case "$(uname -m)" in
    arm64 | aarch64) arch=arm64 ;;
    x86_64 | amd64) arch=x86_64 ;;
    *)
        echo "Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

if [ ! -x "$python_bin" ]; then
    # The pinned local toolchain is the documented path on macOS. Fall back to a
    # system SCons so a Linux CI runner can build without provisioning a venv.
    if [ "$platform" = "linux" ] && python3 -c "import SCons" >/dev/null 2>&1; then
        python_bin=python3
    else
        echo "Native toolchain missing. Run: python3 -m venv native/polytools_cdt/.venv" >&2
        echo "Then: native/polytools_cdt/.venv/bin/python -m pip install -r native/polytools_cdt/requirements-native.txt" >&2
        exit 1
    fi
fi

cd "$script_dir"
exec "$python_bin" -m SCons "platform=$platform" "arch=$arch" target=template_debug "$@"
