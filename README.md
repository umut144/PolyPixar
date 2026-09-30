# PolyTools

A Godot 4 editor for drawing 2D game assets as Bézier outlines, turning them into triangle meshes, and exporting them as engine-neutral JSON packages that other projects can load.

<!-- TODO: Screenshot of the editor with one asset open (Create > Single, Outliner on the left, Canvas with a Bézier outline and its handles). Suggested asset: Wizard or Potion from worlds/world01. Save as docs/images/editor-create.png. -->

## Motivation and goal

The goal is to create vector-based assets for 2D games, mesh them, and animate them later. Animation is the planned next stage; the current editor covers authoring, meshing and export (see Status).

## What it does today

Each asset is authored once as topology and the rest is derived from it.

- **Create:** draw an asset as Components made of Bézier points, edges and chains, optionally over a reference image. `Single` is one asset, `Set` assembles member assets into a larger one (for example a bridge from posts and planks), `Palette` groups interchangeable variants of one kind of asset. Assets have one of seven types: character, props, weapons, terrain, items, icon, symbols.
- **Mesh:** `Sampling` places points along the outline, `Seeding` fills the interior with points, `Meshing` builds a constrained triangulation from both. Each step shows a preview and is accepted explicitly.
- **Style:** `Weighting` stores a scalar weight per mesh vertex (uniform and axis-gradient methods).
- **Export Runtime:** writes one `manifest.json` per valid asset plus one `catalog.json` per world.

Not included, as stated in `docs/AI_CONTEXT.md`: texture and material authoring, and UV or SDF authoring. Motion authoring exists in the code but is not reachable from the editor. There is no checked-in native build for Windows or Linux (see Setup).

## Workflow

1. Create an asset in `Create > Single` and draw its Components on the Canvas.
2. In `Mesh`, run Sampling, Seeding and Meshing and accept the result of each step. Automatic recipes derive the Sampling and Seeding settings from the size of the outline, so the defaults need no tuning.
3. In `Style > Weighting`, add weighting styles where needed.
4. Run `Export Runtime`. The package appears under `worlds/<world>/`.

<!-- TODO: Short GIF (10-20 s): draw a few points in Create, switch to Mesh > Meshing, show the triangle preview, press Bake Preview, then Export Runtime. Save as docs/images/workflow.gif. -->

## Data format and interface

A world is stored as plain JSON below `worlds/<world>/` (`world01.json`, `assets/`, `geometry/`). The editor's document schema is version 73 (`configs/app_config.json`); `docs/SCHEMA_HISTORY.md` lists the steps.

Runtime Export is the interface for other projects. Its layout:

```text
worlds/<world_key>/
├── catalog.json                        schema 3: the authoritative list of assets
└── PolyToolsRuntimeExports/
    └── <asset_key>/manifest.json       schema 23: one asset
```

A consumer reads `catalog.json`, then each listed manifest. Coordinates are 2D, x right, y up, in meters; a Component's vertices are pivot-relative, and its transform is `T(position) * R(rotation) * S(scale)`. A trimmed Component entry:

```json
{
  "component_id": "component_6",
  "name": "body",
  "local_transform": {"position":[0,0], "rotation_radians":0, "scale":[1,1]},
  "mesh": {"vertices":[[0,0],[1,0],[0,1]], "indices":[0,1,2]}
}
```

The field-level contract is `docs/RUNTIME_EXPORT_CONTRACT.md`. Consumers must reject other schema versions. `catalog.json` and `PolyToolsRuntimeExports/` are generated and not tracked: run `Export Runtime` once after a fresh clone.

`scripts/sync_world01_consumers.sh` and `scripts/sync_game04_consumers.sh` copy exports into two sibling projects (SceneMaker and world01). Those projects are not part of this repository, so the scripts only work with that local layout.

## Technology

- **Godot 4.7.1.** The toolchain lock names the Mono build, but the project contains no C# code; the standard build is enough (CI uses it).
- **GDScript** for everything except triangulation: about 36,000 lines in 56 scripts under `scripts/`. `main.gd` composes the editor; the views only render and emit signals, and the services are static and hold no editor state (`docs/ARCHITECTURE.md`).
- **C++ GDExtension** (`native/polytools_cdt/`, about 200 lines) wraps the constrained Delaunay triangulation library [CDT](https://github.com/artem-ogre/CDT) 1.4.5. The library is C++, so the adapter is the thin boundary: it receives copied vertices and constraint index pairs and returns triangle indices. Sampling, validation and persistence stay in GDScript. Built with SCons against godot-cpp (4.5 branch); both dependencies are Git submodules.

## Setup

Requirements: Godot 4.7.1 (standard or Mono build). Rebuilding the native extension additionally needs Git, Python 3 with SCons 4.8.1 (`native/polytools_cdt/requirements-native.txt`) and a C++ compiler.

```bash
git clone https://github.com/umut144/PolyTools.git
cd PolyTools
```

On macOS arm64 a debug build of the extension is checked in, so the editor runs without compiling. On Linux, or after changing the C++ adapter, fetch the two submodules (godot-cpp is about 130 MB) and build:

```bash
git submodule update --init --recursive
native/polytools_cdt/build.sh -j"$(nproc)"
```

Then open the project in Godot (`godot --path . --editor`, or import `project.godot` from the project manager). The main scene is `scenes/main.tscn`. The repository contains one example world, `worlds/world01`; open it from the editor to try the workflow above. Details and the exact toolchain are in `native/polytools_cdt/README.md`.

## Project structure

- `scripts/`: editor code (`main.gd`, views, services, Sampling/Seeding/Meshing, export)
- `native/polytools_cdt/`: C++ triangulation adapter, build script, pinned dependencies
- `tests/`: headless test suites and the native smoke test
- `tools/`: `verify.sh` and Inspector render probes
- `docs/`: architecture, geometry and export documents; start with `AI_CONTEXT.md`
- `worlds/world01/`: example world (assets, geometry, reference images)
- `scenes/`, `assets/`, `configs/`: main scene, icons, app state
- `.github/workflows/verify.yml`: CI

`TASKS.md` is the list of open and deliberately deferred work.

## Tests and quality

`tools/verify.sh` runs four steps: headless editor parse, native CDT smoke test, the test suite, and `git diff --check`. It fails on a non-zero exit code, on any `SCRIPT ERROR`, `ERROR:` or leak line, and when a runner's pass line is missing. The suite consists of five files in `tests/` covering topology, geometry, editor behaviour, persistence and motion (107 test functions). GitHub Actions runs the same script on Linux for every push to `main` and every pull request, building the native extension there.

```bash
tools/verify.sh            # everything
tools/verify.sh tests      # one step
```

## Status and next steps

Work in progress. The editor is used to author the assets in `worlds/world01`; the document and export schemas are versioned and have changed often (73 and 23), and older export schemas are not supported. Open work is listed in `TASKS.md`: mostly refactoring and diagnostics (extracting more of the 14,800-line `main.gd`, replacing string literals with constants, optional Auto Mesh refinements). The checked-in native build is macOS arm64; Linux is covered by CI, Windows is not addressed.

## License and credits

Copyright © 2026 Umut Coşkun. All rights reserved. PolyTools is proprietary: no permission to use, copy, modify or distribute it is granted without written permission. The source is public for viewing only. The full terms are in [`LICENSE`](LICENSE). Third-party components keep their own licenses:

- [CDT](https://github.com/artem-ogre/CDT) 1.4.5, Mozilla Public License 2.0
- [godot-cpp](https://github.com/godotengine/godot-cpp), see its `LICENSE.md`
- [Godot Engine](https://godotengine.org)

See `native/polytools_cdt/THIRD_PARTY_NOTICES.md`.
