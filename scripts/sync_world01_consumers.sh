#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
polytools_world_dir="${POLYTOOLS_WORLD_DIR:-$project_root/worlds/world01}"
scenemaker_project_dir="${SCENEMAKER_PROJECT_DIR:-$project_root/../SceneMaker}"
world01_project_dir="${WORLD01_PROJECT_DIR:-$project_root/../../BevyProjects/world01}"

scenemaker_sync="$scenemaker_project_dir/scripts/sync_polytools_world.sh"
scenemaker_export="$scenemaker_project_dir/scripts/export_scene.sh"
# export_scene.sh takes <workspace> <game> <scene-id>; overworld01 is a Scene
# inside the sandbox Game, not a Game of its own.
scenemaker_game_key="sandbox"
scenemaker_scene_id="overworld01"
# sync_scenemaker_world.sh reads a whole exports directory, not one file,
# and takes it as SCENEMAKER_EXPORTS.
scenemaker_exports_dir="$scenemaker_project_dir/workspaces/world01/$scenemaker_game_key/exports"
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
# One short line per step, filled in only when it is blocked or failed: the
# last non-empty line of its own output, or which step it is waiting on.
# Nothing reads it for a step that applied cleanly.
step_reason=("" "" "" "")

# The tool each step runs. A missing one fails only its own step, so the steps
# that do not need it still run - and game04's sync, which is a separate
# script, never learns about any of this.
step_tool=(
	"$world01_asset_sync"
	"$scenemaker_sync"
	"$scenemaker_export"
	"$world01_map_sync"
)

# The short reason a failed step shows in the Editor: its last ERROR line when
# it printed one, since the consumer scripts close with a generic banner,
# otherwise its last non-empty line.
failure_reason() {
	local reason
	reason=$(printf '%s\n' "$1" | sed -n 's/^ERROR: //p' | tail -n1)
	if [[ -z "$reason" ]]; then
		reason=$(printf '%s\n' "$1" | sed '/^[[:space:]]*$/d' | tail -n1)
	fi
	printf '%s' "$reason"
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
		step_reason[index]="wartet auf Schritt $blocker: ${steps[dependency]}"
		printf 'Consumer Sync %d/%d not run: %s (needs step %s)\n' \
			"$((index + 1))" "${#steps[@]}" "${steps[index]}" "$blocker"
		return 0
	fi
	local missing=""
	if [[ ! -d "$polytools_world_dir" ]]; then
		missing="PolyTools World directory not found: $polytools_world_dir"
	elif [[ ! -x "${step_tool[index]}" ]]; then
		missing="not found or not executable: ${step_tool[index]}"
	fi
	if [[ -n "$missing" ]]; then
		step_result[index]="failed"
		step_reason[index]="$missing"
		printf 'Consumer Sync %d/%d failed: %s (%s)\n' "$((index + 1))" "${#steps[@]}" "${steps[index]}" "$missing" >&2
		return 0
	fi
	printf 'Consumer Sync %d/%d: %s\n' "$((index + 1))" "${#steps[@]}" "${steps[index]}"
	# Captured rather than streamed, so a failure can also carry its own last
	# line as step_reason; still printed below so a human watching the terminal
	# sees the same thing they always did.
	local step_output
	if step_output=$("$@" 2>&1); then
		step_result[index]="applied"
	else
		step_result[index]="failed"
		step_reason[index]=$(failure_reason "$step_output")
		printf 'Consumer Sync %d/%d failed: %s\n' "$((index + 1))" "${#steps[@]}" "${steps[index]}" >&2
	fi
	if [[ -n "$step_output" ]]; then
		printf '%s\n' "$step_output"
	fi
	return 0
}

run_step 0 env POLYTOOLS_WORLD_DIR="$polytools_world_dir" "$world01_asset_sync"
run_step 1 env POLYTOOLS_WORLD_DIR="$polytools_world_dir" "$scenemaker_sync"
run_step 2 "$scenemaker_export" "$scenemaker_project_dir/workspaces/world01" "$scenemaker_game_key" "$scenemaker_scene_id"
run_step 3 env SCENEMAKER_EXPORTS="$scenemaker_exports_dir" "$world01_map_sync"

applied=0
for index in "${!steps[@]}"; do
	if [[ "${step_result[index]}" == "applied" ]]; then
		applied=$((applied + 1))
	fi
done

# Machine-readable step summary for the Editor's checklist, printed exactly
# once per run regardless of outcome. main.gd parses this instead of the
# "N/4" lines above, so it can show one applied/failed/blocked line per step
# rather than a numbered sequence. status is the first word of step_result
# ("blocked 2" becomes "blocked"); the human-readable lines above stay
# unchanged for anyone reading the log by hand.
for index in "${!steps[@]}"; do
	printf 'STEP|%d|%d|%s|%s|%s\n' "$((index + 1))" "${#steps[@]}" "${step_result[index]%% *}" "${steps[index]}" "${step_reason[index]}"
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
