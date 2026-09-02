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

fail() {
	printf 'CONSUMER SYNC FAILED: %s\n' "$1" >&2
	exit 1
}

[[ -d "$polytools_world_dir" ]] || fail "PolyTools World directory not found: $polytools_world_dir"
[[ -x "$scenemaker_sync" ]] || fail "SceneMaker catalog sync is not executable: $scenemaker_sync"
[[ -x "$scenemaker_export" ]] || fail "SceneMaker export is not executable: $scenemaker_export"
[[ -x "$world01_asset_sync" ]] || fail "world01 asset sync is not executable: $world01_asset_sync"
[[ -x "$world01_map_sync" ]] || fail "world01 map sync is not executable: $world01_map_sync"

printf 'Consumer Sync 1/4: PolyTools -> SceneMaker\n'
POLYTOOLS_WORLD_DIR="$polytools_world_dir" "$scenemaker_sync"

printf 'Consumer Sync 2/4: SceneMaker scene export\n'
"$scenemaker_export" "$scenemaker_project_dir/workspaces/world01" "$scenemaker_scene_id"

printf 'Consumer Sync 3/4: PolyTools -> world01 content\n'
POLYTOOLS_WORLD_DIR="$polytools_world_dir" "$world01_asset_sync"

printf 'Consumer Sync 4/4: SceneMaker -> world01 map\n'
SCENEMAKER_EXPORT="$scenemaker_scene_export" "$world01_map_sync"

printf 'POLYTOOLS CONSUMER SYNC SUCCESS\n'
