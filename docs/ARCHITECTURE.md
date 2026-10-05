# Architecture

## Core idea

MicroC0re uses a **hybrid agent/continuum** architecture.

- Organisms are discrete agents with geometry and internal state.
- Chemistry is stored in continuous-looking scalar fields sampled from grids.
- The renderer observes snapshots of both.
- The organism simulation uses a fixed timestep and seeded randomness. Expensive chemistry runs at a deterministic sub-rate, while rendering is free to run faster.

```text
       sources / reactions
               |
               v
+------------------------------+
|  scalar chemical fields      |
| nutrient / waste / signals   |
+------------------------------+
       ^                 |
 uptake|                 |sample
       |                 v
+------------------------------+
| discrete organisms           |
| rods / metabolism / sensing  |
+------------------------------+
       |
       | state snapshot
       v
+------------------------------+
| renderer / debug UI          |
| pixel microscope             |
+------------------------------+
```

## Directories

### `src/simulation/`
Pure simulation code:
- scalar fields;
- organisms;
- contact mechanics;
- metabolism;
- chemotaxis;
- reaction modules;
- deterministic stepping.

It must be runnable with `--headless`.

### `src/app/`
Godot-facing presentation:
- scene entry point;
- debug rendering;
- later camera, pixel viewport, shaders, UI.

It may read simulation state but should not mutate biology through rendering code.

### `tests/`
Headless scripts that exercise invariants and deterministic scenarios.

## Fixed-step loop

The app accumulates frame time but advances biology in constant-size ticks.

```text
render frame delta
      |
      v
accumulator += delta
      |
      +--> while accumulator >= fixed_dt:
      |        simulation.step(fixed_dt)
      |        accumulator -= fixed_dt
      |
      v
render latest state
```

This makes biology independent from display FPS.

## Simulation ordering for v0.1

A tick is conceptually:

1. inject environmental sources;
2. diffuse/decay scalar fields;
3. sample local nutrient history;
4. update run/tumble motility;
5. consume nutrient;
6. update energy and growth;
7. integrate movement and boundaries;
8. divide or die;
9. resolve mechanical overlaps iteratively;
10. accumulate waste / bookkeeping.

Ordering is explicit because changing it can change emergent behavior.

## Scaling strategy

Rod contact broad-phase now uses a uniform spatial hash. Buckets are rebuilt in deterministic organism order and neighbors are visited in fixed offset order.

Current multirate loop:
- organism dynamics: 60 Hz fixed step in the visible app;
- chemistry diffusion/source update: 30 Hz;
- contact mechanics: 60 Hz;
- chemical ImageTexture upload: 20 Hz;
- rendering: capped at 144 FPS in the current prototype.

The scalar field is uploaded as one tiny nearest-filtered texture instead of thousands of per-cell draw calls. Chemical grids can later move to compute shaders or GPU textures, but the CPU reference remains useful for validation.
