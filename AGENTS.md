# AGENTS.md — MicroC0re

This file is the working contract for coding agents.

## Mission

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

## Performance policy

The first correct implementation may be simple. Profile before optimizing.

For contact mechanics, O(N²) is acceptable for the initial small-population kernel. Move to a deterministic spatial hash only after the baseline is measured.

## Non-negotiables

Never implement:
- food as a magic target position known to every cell;
- reproduction as a periodic spawn timer;
- predation as collision -> delete;
- visual interpolation that feeds back into simulation state;
- undocumented random behavior;
- machine-specific paths inside `project.godot`.
