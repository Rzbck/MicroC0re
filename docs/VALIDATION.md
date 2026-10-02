# Validation strategy

MicroC0re should be visually experimental but explicit about what is validated.

## Validation levels

### Level A — numerical invariants
Required immediately:
- no NaN/Inf;
- no negative concentrations;
- bounded lengths/energy;
- reproducible fixed-seed runs;
- stable diffusion timestep;
- no invalid IDs.

### Level B — qualitative biological behavior
Examples:
- fed cells grow more than starved cells;
- nutrient disappears when consumed;
- chemotactic population spends more time in favorable regions than an unbiased control;
- rods mechanically exclude each other;
- division occurs only after growth/resource conditions are met.

### Level C — quantitative calibration
Future work:
- measured speed distributions;
- run/tumble duration distributions;
- division-time distributions;
- nutrient diffusion coefficients;
- uptake/yield values;
- colony-front velocity;
- morphology statistics.

Until Level C exists for a parameter set, do not call that parameter set biologically accurate.

## Determinism check

A headless test should run the same seed twice for the same number of ticks and compare a stable state signature.

The signature should eventually include, in deterministic ID order:
- positions;
- orientations;
- lengths;
- energy;
- generation;
- field summary/checksum.

## Diffusion checks

1. Uniform field + diffusion only => remains uniform.
2. Single central impulse => spreads symmetrically on a symmetric grid.
3. Diffusion only => approximate total mass conservation with no-flux boundaries.
4. Diffusion + decay => mass decreases monotonically.
5. Values never become negative.

## Chemotaxis A/B test

Run many cells in the same static gradient:
- A: chemotaxis gain = 0;
- B: chemotaxis gain > 0.

Compare occupancy or mean concentration sampled by cells after a burn-in period.

A single trajectory is not evidence; the test is statistical.

## Mechanical stress test

Seed overlapping rods, then iterate contact resolution.

Check:
- overlap decreases;
- state stays finite;
- boundary constraints hold.

## Performance baselines

Record fixed-step wall time for increasing populations before optimization:
- 100 agents;
- 500 agents;
- 1,000 agents.

v0.1 may remain O(N²). Issue #9 owns the move to deterministic spatial indexing when justified.
