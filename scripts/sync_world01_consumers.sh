#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
polytools_world_dir="${POLYTOOLS_WORLD_DIR:-$project_root/worlds/world01}"
scenemaker_project_dir="${SCENEMAKER_PROJECT_DIR:-$project_root/../SceneMaker}"
world01_project_dir="${WORLD01_PROJECT_DIR:-$project_root/../../BevyProjects/world01}"

scenemaker_sync="$scenemaker_project_dir/scripts/sync_polytools_world.sh"
scenemaker_export="$scenemaker_project_dir/scripts/export_scene.sh"
scenemaker_scene_id="overworld01"
scenemaker_scene_export="$scenemaker_project_dir/workspaces/world01/exports/$scenemaker_scene_id.scene_export.json"
world01_asset_sync="$world01_project_dir/scripts/sync_polytools_characters.sh"
world01_map_sync="$world01_project_dir/scripts/sync_scenemaker_world.sh"

# The steps run by dependency, not by consumer. Two of them depend on nothing
# but the published Catalog and go first, so a failure further down cannot
# starve them; the scene export needs SceneMaker to have the Catalog, and the
# map sync needs both the scene export and world01's content.
#
# world01 asked for this order and gave the reason: the dangerous direction is
# a new map against old content, and keeping the map sync last already locks
# that out — a map naming an Asset they do not have is refused at their gate.
# The reverse, new content against an old map, is a state they can see: their
# build fails loudly on a renamed file and the next map sync refuses the stale
# map with a reason.
#
# Nothing here is atomic: each step writes as it goes, so a failure leaves an
# applied prefix behind. That is why the run reports which steps were applied
# rather than only that it failed — a log that simply stops leaves the reader
# to work out what reached whom.
steps=(
	"PolyTools -> world01 content"
	"PolyTools -> SceneMaker"
	"SceneMaker scene export"
	"SceneMaker -> world01 map"
)
completed=0

fail() {
	trap - EXIT
	printf 'CONSUMER SYNC FAILED: %s\n' "$1" >&2
	printf 'Nothing was applied: the run stopped before its first step.\n' >&2
	exit 1
}

report_incomplete() {
	local status=$?
	trap - EXIT
	if (( status == 0 )); then
		return
	fi
	printf '\nCONSUMER SYNC INCOMPLETE\n' >&2
	local index
	for index in "${!steps[@]}"; do
		if (( index < completed )); then
			printf '  %d/%d applied · %s\n' "$((index + 1))" "${#steps[@]}" "${steps[index]}" >&2
		elif (( index == completed )); then
			printf '  %d/%d FAILED  · %s\n' "$((index + 1))" "${#steps[@]}" "${steps[index]}" >&2
		else
			printf '  %d/%d not run · %s\n' "$((index + 1))" "${#steps[@]}" "${steps[index]}" >&2
		fi
	done
	if (( completed < 1 )); then
		printf 'SceneMaker and world01 are both on their previous state.\n' >&2
	elif (( completed < 2 )); then
		printf "world01's content was updated; SceneMaker and world01's map are on their previous state.\n" >&2
	else
		printf "world01's content and SceneMaker's workspace were updated; world01's map is on its previous state.\n" >&2
	fi
	printf 'The PolyTools Runtime Export is untouched by all of this.\n' >&2
	exit "$status"
}

[[ -d "$polytools_world_dir" ]] || fail "PolyTools World directory not found: $polytools_world_dir"
[[ -x "$scenemaker_sync" ]] || fail "SceneMaker catalog sync is not executable: $scenemaker_sync"
[[ -x "$scenemaker_export" ]] || fail "SceneMaker export is not executable: $scenemaker_export"
[[ -x "$world01_asset_sync" ]] || fail "world01 asset sync is not executable: $world01_asset_sync"
[[ -x "$world01_map_sync" ]] || fail "world01 map sync is not executable: $world01_map_sync"

trap report_incomplete EXIT

printf 'Consumer Sync 1/4: %s\n' "${steps[0]}"
POLYTOOLS_WORLD_DIR="$polytools_world_dir" "$world01_asset_sync"
completed=1

printf 'Consumer Sync 2/4: %s\n' "${steps[1]}"
POLYTOOLS_WORLD_DIR="$polytools_world_dir" "$scenemaker_sync"
completed=2

printf 'Consumer Sync 3/4: %s\n' "${steps[2]}"
"$scenemaker_export" "$scenemaker_project_dir/workspaces/world01" "$scenemaker_scene_id"
completed=3

printf 'Consumer Sync 4/4: %s\n' "${steps[3]}"
SCENEMAKER_EXPORT="$scenemaker_scene_export" "$world01_map_sync"
completed=4

trap - EXIT
printf 'POLYTOOLS CONSUMER SYNC SUCCESS\n'
