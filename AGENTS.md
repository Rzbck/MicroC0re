# AGENTS.md — MicroC0re

This file is the working contract for coding agents.

### READ FIRST — current product direction

Before changing code or art, read **`docs/HANDOFF.md`**, **`docs/CURRENT_DIRECTION.md`** and **`docs/STATUS.md`**. For any hot-path, scaling, threading, GPU or storage change, also read **`docs/OPTIMIZATION_STRATEGY.md`**.

Epic #14 is the current visual/performance gate. Until that gate passes, prioritize:
1. #17 performance/profiling/LOD;
2. #16 camera/background/zoom;
3. #15 true pixel-art pipeline/art bible;
4. #18 readable animation/interactions.

Do not expand deeper ecology simply because the simulation can support it. The visible experience must first become fast, intentional, and genuinely pixel-art.

## Session bootstrap / GitHub handoff

A fresh agent must recover state from GitHub instead of asking the maintainer to reconstruct it.

At session start:
1. read `docs/HANDOFF.md`;
2. inspect the GitHub Project `MicroC0re` (#2) when Project access is available;
3. inspect active PR #19 and relevant Issues;
4. continue blocking `In Progress` / `Review` work before starting unrelated `Todo` items.

For GitHub bookkeeping, use the GitHub connector/agent tools. Do not ask the maintainer to run PowerShell or `gh` merely to move cards, update Issues, labels or PR metadata.

If Project V2 mutation is not exposed by the current connector, use the `status:*` compatibility labels documented in `docs/HANDOFF.md`. The default-branch Project sync workflow is responsible for translating those labels to real Project Status values.

# Mission

Build a deterministic, headless-capable microbial simulation in Godot 4.7.x, then render it as generative pixel art.

The simulation should produce interesting behavior because of interacting physical/biological rules, not because of scripted animations.

## Local engine

Preferred local version: Godot 4.7.1.

Do not hardcode a workstation path into project settings. Developer scripts use `GODOT_BIN` when available.

Example on the maintainer's Windows machine:

```powershell
$env:GODOT_BIN = "C:\Godot\Godot_v4.7.1-stable_win64_console.exe"

# Normal visible simulation
./scripts/run_simulation.ps1

# Automated validation only
./scripts/run_headless.ps1
```

## Architectural boundaries

- `src/simulation/` must not depend on scenes, sprites, cameras, shaders, or UI.
- `src/app/` may read simulation state but must not own biological state.
- Use a fixed simulation timestep.
- Randomness must come from seeded `RandomNumberGenerator` instances owned by the simulation.
- Prefer data-oriented state and explicit equations over Node-per-particle designs.
- Godot Physics is not the biological truth layer for organisms.

## Modeling rules

- Distinguish **measured biology**, **qualitative model**, and **artistic rule**.
- Record source papers in `docs/RESEARCH.md`.
- Record equations/assumptions in `docs/MATH.md`.
- Record organism-level interpretation in `docs/BIOLOGY.md`.
- Record validation limits in `docs/VALIDATION.md`.
- Do not describe an uncalibrated parameter as biologically accurate.

## Required checks before PR completion

Run:

```powershell
./scripts/run_headless.ps1
```

At minimum verify:
- no parser/runtime errors;
- no NaN/Inf state;
- no negative field values;
- deterministic fixed-seed behavior;
- no renderer dependency in the kernel.

If a local Godot binary is unavailable, state that tests were not executed instead of claiming success.

## GitHub workflow

- One focused issue per behavior or subsystem.
- Feature work happens on a branch and lands through a PR.
- Link PRs to issues.
- Keep Issue #1 as the v0.1 epic.
- Add acceptance criteria to issues before expanding scope.
- Avoid giant “rewrite everything” commits.

## GPU-first desktop policy

For desktop performance work, prefer the GPU for workloads with high data parallelism:
- MultiMesh/bulk-buffer rendering;
- chemical/reaction-diffusion fields;
- large independent per-agent kernels;
- future spatial binning and local interaction kernels.

The project uses Forward+ on desktop. Keep a CPU/headless reference path, but do not treat CPU as the default execution target for scalable workloads.

Never add a design that requires synchronous full GPU -> CPU readback every tick. Godot RenderingDevice readbacks synchronize or consume significant transfer bandwidth; keep bulk state resident whenever possible.

GPU migration is tracked by #27.

## Performance policy

Profile before optimizing and record measured before/after numbers.

Current visible-performance contract:
- target 120+ FPS during normal microscope inspection;
- 60 FPS is the development floor;
- biological simulation is currently 60 Hz and chemistry 30 Hz;
- simulation tick rate and render FPS are separate metrics;
- off-screen organisms must be culled;
- use explicit far/mid/near/macro LOD;
- distant organisms must never pay for close-up appendage/detail rendering;
- prefer cached/batched sprite rendering over rebuilding procedural geometry every frame;
- no hot-loop Dictionary/temporary-array allocation when a preallocated packed structure can be used;
- preserve stable biological IDs separately from dense simulation indices;
- future parallel random draws must not depend on thread execution order;
- never introduce synchronous full GPU readback in a per-tick path without measured justification.

The contact broad-phase currently uses a deterministic spatial hash. Do not regress to global O(N²) contact checks without a measured reason.

## UI discipline

- Do not put a permanent profiler/status block over the microscope artwork.
- Escape owns the pause/settings menu.
- Organism details belong in the left-side inspector opened by clicking an organism.
- Empty-world click or Escape closes the inspector.
- Minimum camera zoom is cover-fit; never reintroduce a tiny-world zoom-out view.
- Keep profiling in benchmarks/development tooling unless the maintainer explicitly requests an on-screen diagnostic.

## Visual non-negotiables

- The current procedural capsule/line renderer is temporary debug art, not the final style.
- Nearest-neighbor filtering alone does not make something pixel art.
- No Godot default grey/clear background may be visible at supported zoom.
- Final organism art should follow the sprite/palette/cluster rules in `docs/ART_DIRECTION.md`.
- Important interactions must be readable as staged/persistent states, not instantaneous debug events.
- A visual PR that drops the agreed baseline below 60 FPS requires an explicit documented exception.

## Non-negotiables

Never implement:
- food as a magic target position known to every cell;
- reproduction as a periodic spawn timer;
- predation as collision -> delete;
- visual interpolation that feeds back into simulation state;
- undocumented random behavior;
- machine-specific paths inside `project.godot`.
