#!/usr/bin/env bash
# PolyTools verification wrapper.
#
# Runs what AGENTS.md requires after a change and fails the way CI fails, so a
# local run and the GitHub Actions run agree on what a failure is:
#
#   editor      headless editor parse (also refreshes .godot/, which the suite
#               needs for its global class cache on a fresh checkout)
#   smoke       native CDT smoke test
#   tests       the test suite
#   whitespace  git diff --check
#
# Usage:
#   tools/verify.sh                # all four steps, in that order
#   tools/verify.sh tests          # one step
#   tools/verify.sh editor tests   # several steps, in the order given
#
# Every Godot step fails on a non-zero exit code, on any line matching
# ERROR_PATTERN below, and — for smoke and tests — when the runner's own pass
# line is missing. The last check matters because a runtime error aborts only
# the GDScript function it occurs in: a SCRIPT ERROR inside a test, a helper or
# main.gd returns null to its caller and the run continues, so the runner's exit
# code alone is not a verdict. Godot can also exit zero after printing an ERROR.
# All steps run even after one fails; the summary at the end names each verdict
# and the exit code is non-zero if any step failed.
#
# Godot is located through, in order: $GODOT_BIN, the "application" path in
# native/polytools_cdt/toolchain-lock.json, then `godot` on PATH.
#
# Logs are written below $VERIFY_LOG_DIR (default: .verify/ in the repository,
# ignored by Git) and are kept after the run, so a failing log can be read or
# diffed without re-running Godot.
#
# The whitespace step checks the working tree and the index. With
# VERIFY_DIFF_BASE set to a commit, it checks that commit against HEAD instead,
# which is how CI checks the pushed range.

set -euo pipefail

ERROR_PATTERN='^(SCRIPT ERROR|ERROR:|WARNING: .*leaked)'
TESTS_PASS_LINE='All PolyTools tests passed.'
SMOKE_PASS_LINE='Native CDT smoke test passed.'

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

log_dir="${VERIFY_LOG_DIR:-$repo_root/.verify}"
mkdir -p "$log_dir"

failed_steps=""
passed_steps=""

# --- Godot -------------------------------------------------------------------

resolve_godot() {
	if [ -n "${GODOT_BIN:-}" ]; then
		printf '%s\n' "$GODOT_BIN"
		return
	fi
	local lock="$repo_root/native/polytools_cdt/toolchain-lock.json"
	if [ -f "$lock" ]; then
		# The lock file is small and flat; one line holds "application": "...".
		local from_lock
		from_lock=$(sed -n 's/.*"application"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$lock" | head -n 1)
		if [ -n "$from_lock" ] && [ -x "$from_lock" ]; then
			printf '%s\n' "$from_lock"
			return
		fi
	fi
	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return
	fi
	printf '%s\n' ""
}

godot=""
require_godot() {
	if [ -n "$godot" ]; then
		return 0
	fi
	godot=$(resolve_godot)
	if [ -z "$godot" ]; then
		echo "verify: no Godot binary found. Set GODOT_BIN, or fix the application path in native/polytools_cdt/toolchain-lock.json." >&2
		return 1
	fi
	if [ ! -x "$godot" ]; then
		echo "verify: Godot binary is not executable: $godot" >&2
		return 1
	fi
	echo "verify: using $godot"
}

# --- Step machinery -----------------------------------------------------------

# run_godot_step NAME LOG PASS_LINE ARGS...
#
# Runs Godot with ARGS, mirrors its output to the terminal and to LOG, and
# returns non-zero if the exit code was non-zero, any line matched
# ERROR_PATTERN, or PASS_LINE (when not empty) did not appear.
run_godot_step() {
	local name="$1" log="$2" pass_line="$3"
	shift 3
	require_godot || return 1

	echo "=== verify: $name ==="
	local status=0
	"$godot" "$@" 2>&1 | tee "$log" || status=$?

	local verdict=0
	if [ "$status" -ne 0 ]; then
		echo "verify: $name — Godot exited with status $status."
		verdict=1
	fi
	if grep -Eq "$ERROR_PATTERN" "$log"; then
		echo "verify: $name — Godot reported an error:"
		grep -E "$ERROR_PATTERN" "$log" | sed 's/^/    /'
		verdict=1
	fi
	if [ -n "$pass_line" ] && ! grep -Fxq "$pass_line" "$log"; then
		echo "verify: $name — the pass line \"$pass_line\" is missing; the runner did not reach its summary."
		verdict=1
	fi
	return "$verdict"
}

step_editor() {
	run_godot_step "headless editor parse" "$log_dir/editor.log" "" \
		--headless --path . --editor --quit
}

step_smoke() {
	run_godot_step "native CDT smoke test" "$log_dir/native-smoke.log" "$SMOKE_PASS_LINE" \
		--headless --path . -s res://tests/native_cdt_smoke.gd
}

step_tests() {
	run_godot_step "test suite" "$log_dir/tests.log" "$TESTS_PASS_LINE" \
		--headless --path . -s res://tests/run_tests.gd
}

step_whitespace() {
	echo "=== verify: whitespace ==="
	local base="${VERIFY_DIFF_BASE:-}"
	if [ -n "$base" ]; then
		if git cat-file -e "$base^{commit}" 2>/dev/null; then
			git diff --check "$base" HEAD
		else
			echo "verify: whitespace — base commit $base is not reachable; skipping the range check."
		fi
		return
	fi
	# Working tree against HEAD covers both unstaged and staged changes.
	git diff --check HEAD
}

run_step() {
	local step="$1"
	local status=0
	case "$step" in
		editor) step_editor || status=$? ;;
		smoke) step_smoke || status=$? ;;
		tests) step_tests || status=$? ;;
		whitespace) step_whitespace || status=$? ;;
		*)
			echo "verify: unknown step '$step'. Known steps: editor smoke tests whitespace" >&2
			exit 2
			;;
	esac
	if [ "$status" -eq 0 ]; then
		passed_steps="$passed_steps $step"
	else
		failed_steps="$failed_steps $step"
	fi
}

# --- Main ---------------------------------------------------------------------

if [ "$#" -eq 0 ]; then
	set -- editor smoke tests whitespace
fi

for step in "$@"; do
	run_step "$step"
done

echo "=== verify: summary ==="
for step in $passed_steps; do
	echo "  ok    $step"
done
for step in $failed_steps; do
	echo "  FAIL  $step"
done
echo "verify: logs in $log_dir"

if [ -n "$failed_steps" ]; then
	exit 1
fi
