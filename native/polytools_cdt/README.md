# PolyTools CDT GDExtension

This extension is the narrow native boundary between PolyTools and
[`artem-ogre/CDT`](https://github.com/artem-ogre/CDT). PolyTools remains the
owner of recipes, sampled topology, IDs, validation, domain filtering, seam
duplication, persistence, and diagnostics. Native code only receives copied
vertices plus constraint-index pairs and returns copied triangle indices.

The checked-in debug framework lets the pinned Godot Mono 4.7.1 editor run
without a local rebuild. Rebuild only after changing the C++ adapter, the CDT
version, `godot-cpp`, or native compiler settings. Ordinary GDScript, UI,
Sampling, and Seeding changes do not require a native build.

## Rebuild on this Mac

```bash
git submodule update --init --recursive
python3 -m venv native/polytools_cdt/.venv
native/polytools_cdt/.venv/bin/python -m pip install -r native/polytools_cdt/requirements-native.txt
native/polytools_cdt/build.sh -j8
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://tests/native_cdt_smoke.gd
```

The first build compiles `godot-cpp` and is intentionally slower. Later builds
are incremental. After the initial submodule checkout and 4.1 MB SCons wheel,
the build and tests require no network access. Exact versions and commits are
recorded in `toolchain-lock.json`.

## Build on Linux

macOS is the authoring platform and the only one with a checked-in build. Linux
is supported as a build-from-source target so the headless suite can run
without a Mac, which is what a CI runner needs. Its product is not checked in.

```bash
git submodule update --init --recursive
native/polytools_cdt/build.sh -j"$(nproc)"
godot --headless --path . -s res://tests/native_cdt_smoke.gd
```

`build.sh` derives platform and architecture from `uname`. On Linux it accepts a
system SCons when the pinned `.venv` is absent, so a runner does not have to
provision one. Both `x86_64` and `arm64` are declared in
`bin/polytools_cdt.gdextension`; Godot only consults the entry matching the host,
so an undeclared or unbuilt variant costs nothing on the other platforms.

Without this extension the Meshing pipeline reports a clear load failure and
every Meshing, UV, SDF, and Weighting test fails. Sampling, Seeding, topology,
hierarchy, history, and Runtime Export do not depend on it.

Invalid inputs are rejected in GDScript before crossing the native boundary.
The wrapper additionally validates array shape, indices, duplicate positions,
and finite coordinates, catches all C++ exceptions, and never retains Godot
array pointers after a call.
