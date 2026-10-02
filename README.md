# MicroC0re

MicroC0re is a generative microbial ecosystem built in Godot 4.7.x.

The long-term goal is a visually rich **pixel-art microscope** in which organisms live inside a continuous chemical world: they sense, move, consume resources, grow, divide, compete, attack, die, recycle matter, and eventually evolve more complex interactions.

The project deliberately separates **simulation** from **rendering**. The biology/math kernel must run headlessly and deterministically; the renderer is a replaceable view of that state.

## Current milestone — Petri Kernel v0.1

The first milestone is intentionally small but physically meaningful:

- 2D scalar chemical fields with diffusion, sources, sinks, and decay.
- Rod-shaped bacteria represented as spherocylinders.
- Deterministic fixed-step simulation.
- Run-and-tumble motility with temporal chemical sensing.
- Resource uptake, maintenance cost, growth, death, and binary fission.
- Mechanical contact resolution between rods.
- Headless smoke/validation tests.
- An interactive living-microscope renderer with zoom, pan, organism inspection, animated appendages, and a low-resolution chemical texture.
- Heritable genotype, visible phenotype, seeded mutation, and lineage drift.
- A separate Turing / Gray-Scott reaction-diffusion laboratory for emergent chemistry.

Track the milestone in GitHub Issue #1 and its child issues.

## Scientific stance

MicroC0re is **science-inspired generative art**, not a validated microbiology package.

We use real mathematical structures where they help:
- reaction-diffusion;
- diffusion/advection-style scalar fields;
- Monod-like uptake;
- run-and-tumble chemotaxis;
- spherocylinder contact mechanics;
- agent-based microbial growth.

Every approximation should be documented. Parameters are considered **uncalibrated** until validation work explicitly says otherwise.

See:
- **[AI handoff](docs/HANDOFF.md)** — session bootstrap, GitHub Project workflow and connector rules
- **[Current direction](docs/CURRENT_DIRECTION.md)** — read this first; it overrides stale visual priorities
- **[Project status](docs/STATUS.md)** — IN PROGRESS / REVIEW / TODO / BACKLOG map
- [Research references](docs/RESEARCH.md)
- [Mathematical model](docs/MATH.md)
- [Biology model](docs/BIOLOGY.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Validation strategy](docs/VALIDATION.md)
- [Evolution model](docs/EVOLUTION.md)
- [Art direction](docs/ART_DIRECTION.md)
- [Performance budget](docs/PERFORMANCE.md)
- [Optimization architecture](docs/OPTIMIZATION_STRATEGY.md)
- [Roadmap](docs/ROADMAP.md)

## Repository layout

```text
MicroC0re/
├─ project.godot
├─ AGENTS.md
├─ src/
│  ├─ app/              # Godot presentation/debug view
│  └─ simulation/       # renderer-independent simulation kernel
├─ tests/               # headless checks
├─ scripts/             # local developer helpers
└─ docs/                # design, math, biology, research, validation
```

## Local Godot setup

The simulation is intended to work with Godot 4.7.1.

On the current Windows workstation:

```powershell
$env:GODOT_BIN = "C:\Godot\Godot_v4.7.1-stable_win64_console.exe"
```

Then launch the visible simulation:

```powershell
./scripts/run_simulation.ps1
```

The separate headless command is only for automated validation:

```powershell
./scripts/run_headless.ps1
```

or directly:

```powershell
& $env:GODOT_BIN --headless --path . --script res://tests/smoke_test.gd
```

The local executable path is **not** stored in project settings.

## Engineering rules

1. Fixed timestep for simulation.
2. Seeded RNG for reproducibility.
3. Simulation state never depends on drawing.
4. No collision->delete shortcuts for predation.
5. No spawn timers standing in for growth/division.
6. No negative chemical concentrations.
7. New biological behavior needs a documented model and validation idea.
8. Keep contact broad-phase deterministic; the current kernel uses a uniform spatial hash.
9. Artistic exaggeration is allowed only when documented as artistic.

## Status

**Current gate: Epic #14 — Visual Rebuild v0.2. First implementation pass: draft PR #19.**

The first visible renderer is intentionally considered a rejected debug baseline: it exposed grey outside the world, dropped to ~5–8 FPS at close zoom in the observed test, and read as vector/procedural rather than true pixel art. Agents should read `docs/CURRENT_DIRECTION.md` before adding features.

Bootstrap work is happening on `bootstrap/petri-kernel-v0.1`.
