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

# The steps run by dependency, not by consumer, and each one declares what it
# cannot run without. The first two are siblings rather than a sequence: both
# need nothing but the published Catalog, so neither is allowed to cost the
# other its run. A step is skipped only when its own input is missing, and it
# names the step it was waiting for.
#
# world01 asked for this order and gave the reason: the dangerous direction is
# a new map against old content, and keeping the map sync last already locks
# that out - a map naming an Asset they do not have is refused at their gate.
# The reverse, new content against an old map, is a state they can see: their
# build fails loudly on a renamed file and the next map sync refuses the stale
# map with a reason.
#
# Nothing here is atomic: each step writes as it goes, so a failure leaves an
# applied prefix behind. That is why the run reports every step and what it
# leaves each consumer on, rather than only that it failed - a log that simply
# stops leaves the reader to work out what reached whom.
steps=(
	"PolyTools -> world01 content"
	"PolyTools -> SceneMaker"
	"SceneMaker scene export"
	"SceneMaker -> world01 map"
)
# Indices into `steps`, space separated, of what each step needs applied first.
step_requires=(
	""
	""
	"1"
	"0 2"
)
step_result=("pending" "pending" "pending" "pending")

fail() {
	printf 'CONSUMER SYNC FAILED: %s\n' "$1" >&2
	printf 'Nothing was applied: the run stopped before its first step.\n' >&2
	exit 1
}

run_step() {
	local index="$1"
	shift
	local blocker=""
	local dependency
	for dependency in ${step_requires[index]}; do
		if [[ "${step_result[dependency]}" != "applied" ]]; then
			blocker="$((dependency + 1))"
			break
		fi
	done
	if [[ -n "$blocker" ]]; then
		step_result[index]="blocked $blocker"
		printf 'Consumer Sync %d/%d not run: %s (needs step %s)\n' \
			"$((index + 1))" "${#steps[@]}" "${steps[index]}" "$blocker"
		return 0
	fi
	printf 'Consumer Sync %d/%d: %s\n' "$((index + 1))" "${#steps[@]}" "${steps[index]}"
	if "$@"; then
		step_result[index]="applied"
	else
		step_result[index]="failed"
		printf 'Consumer Sync %d/%d failed: %s\n' "$((index + 1))" "${#steps[@]}" "${steps[index]}" >&2
	fi
	return 0
}

[[ -d "$polytools_world_dir" ]] || fail "PolyTools World directory not found: $polytools_world_dir"
[[ -x "$scenemaker_sync" ]] || fail "SceneMaker catalog sync is not executable: $scenemaker_sync"
[[ -x "$scenemaker_export" ]] || fail "SceneMaker export is not executable: $scenemaker_export"
[[ -x "$world01_asset_sync" ]] || fail "world01 asset sync is not executable: $world01_asset_sync"
[[ -x "$world01_map_sync" ]] || fail "world01 map sync is not executable: $world01_map_sync"

run_step 0 env POLYTOOLS_WORLD_DIR="$polytools_world_dir" "$world01_asset_sync"
run_step 1 env POLYTOOLS_WORLD_DIR="$polytools_world_dir" "$scenemaker_sync"
run_step 2 "$scenemaker_export" "$scenemaker_project_dir/workspaces/world01" "$scenemaker_scene_id"
run_step 3 env SCENEMAKER_EXPORT="$scenemaker_scene_export" "$world01_map_sync"

applied=0
for index in "${!steps[@]}"; do
	if [[ "${step_result[index]}" == "applied" ]]; then
		applied=$((applied + 1))
	fi
done

if (( applied == ${#steps[@]} )); then
	printf 'POLYTOOLS CONSUMER SYNC SUCCESS\n'
	exit 0
fi

printf '\nCONSUMER SYNC INCOMPLETE\n' >&2
for index in "${!steps[@]}"; do
	case "${step_result[index]}" in
		applied)
			printf '  %d/%d applied · %s\n' "$((index + 1))" "${#steps[@]}" "${steps[index]}" >&2
			;;
		failed)
			printf '  %d/%d FAILED  · %s\n' "$((index + 1))" "${#steps[@]}" "${steps[index]}" >&2
			;;
		*)
			printf '  %d/%d not run · %s (needs step %s)\n' "$((index + 1))" "${#steps[@]}" "${steps[index]}" "${step_result[index]#blocked }" >&2
			;;
	esac
done

# Each consumer is named on its own, because the steps no longer fall over in a
# single line: world01 can hold new content while SceneMaker is still on its
# previous state, and the other way round.
if [[ "${step_result[0]}" == "applied" ]]; then
	printf "world01's content was updated.\n" >&2
else
	printf "world01's content is on its previous state.\n" >&2
fi
if [[ "${step_result[1]}" == "applied" ]]; then
	printf "SceneMaker's workspace was updated.\n" >&2
else
	printf "SceneMaker's workspace is on its previous state.\n" >&2
fi
if [[ "${step_result[3]}" == "applied" ]]; then
	printf "world01's map was updated.\n" >&2
else
	printf "world01's map is on its previous state.\n" >&2
fi
printf 'The PolyTools Runtime Export is untouched by all of this.\n' >&2
exit 1
