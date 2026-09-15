#!/usr/bin/env bash
# PolyTools's side of game04's Consumer Sync: one step, game04's own
# scripts/sync_polytools_assets.sh against the published world01 Catalog.
#
#   GAME04_PROJECT_DIR    the game04 repository (default: ../game04)
#   POLYTOOLS_WORLD_DIR   the World to publish from (default: worlds/world01)
#
# Deliberately independent of sync_world01_consumers.sh in both directions: it
# neither calls nor reads it, and the Editor starts the two as separate
# processes, so a broken or absent world01 or SceneMaker never blocks game04
# and game04 never touches them. game04 shares the world01 World on purpose
# (game04 docs/TASKS.md, SYNC-02). It prints the same STEP| summary the Editor
# parses for the other orchestrator.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
polytools_world_dir="${POLYTOOLS_WORLD_DIR:-$project_root/worlds/world01}"
game04_project_dir="${GAME04_PROJECT_DIR:-$project_root/../game04}"
game04_asset_sync="$game04_project_dir/scripts/sync_polytools_assets.sh"
# Run through bash rather than by its execute bit, which a copy or a synced
# folder can lose without the script being any less there.

step_title="PolyTools -> game04 assets"
step_status="failed"
step_reason=""

# Same rule as the world01 orchestrator: the consumer's last ERROR line, since
# its script closes with a generic banner, otherwise its last non-empty line.
failure_reason() {
	local reason
	reason=$(printf '%s\n' "$1" | sed -n 's/^ERROR: //p' | tail -n1)
	if [[ -z "$reason" ]]; then
		reason=$(printf '%s\n' "$1" | sed '/^[[:space:]]*$/d' | tail -n1)
	fi
	printf '%s' "$reason"
}

if [[ ! -d "$polytools_world_dir" ]]; then
	step_reason="PolyTools World directory not found: $polytools_world_dir"
elif [[ ! -f "$game04_asset_sync" ]]; then
	step_reason="not found: $game04_asset_sync"
else
	printf 'Consumer Sync 1/1: %s\n' "$step_title"
	step_output=""
	if step_output=$(env POLYTOOLS_WORLD_DIR="$polytools_world_dir" bash "$game04_asset_sync" 2>&1); then
		step_status="applied"
	else
		step_reason=$(failure_reason "$step_output")
	fi
	if [[ -n "$step_output" ]]; then
		printf '%s\n' "$step_output"
	fi
fi

printf 'STEP|1|1|%s|%s|%s\n' "$step_status" "$step_title" "$step_reason"

if [[ "$step_status" == "applied" ]]; then
	printf 'POLYTOOLS CONSUMER SYNC SUCCESS\n'
	exit 0
fi
printf 'CONSUMER SYNC FAILED: %s\n' "$step_reason" >&2
printf "game04's assets are on their previous state. The PolyTools Runtime Export is untouched.\n" >&2
exit 1
