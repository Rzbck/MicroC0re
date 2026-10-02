# Biology model

This document states what each simulation rule is intended to represent.

## Bacteria in Petri Kernel v0.1

The first organism is a generic rod-shaped, motile bacterium. It is not claimed to be a calibrated model of a specific species.

### Geometry

A bacterium is represented as a 2D spherocylinder:
- center position;
- orientation;
- total length;
- radius.

This is a common simplification for rod-shaped bacteria and lets physical contact affect local ordering.

### Motility

The first motility model is inspired by bacterial run-and-tumble behavior.

A cell:
- moves forward during a run;
- retains a short memory of recently sensed chemical concentration;
- changes its tumble probability depending on whether conditions are improving;
- changes direction stochastically during a tumble.

It does **not** receive the coordinates of a food source.

Berg & Brown (1972) is the primary behavioral reference for this design.

### Nutrient uptake

Nutrient exists in an environmental scalar field.

A cell samples concentration at its own position and removes material locally. Uptake is saturating rather than proportional without bound. v0.1 uses a Monod-like response.

The first implementation uses normalized concentration rather than calibrated molar units.

### Energy and maintenance

Consumed nutrient is converted to internal energy with a yield factor.

Energy is spent on:
- basal maintenance;
- locomotion;
- later, specialized actions such as attack or secretion.

Starvation therefore emerges from insufficient intake relative to costs.

### Growth

Growth changes physical rod length.

Growth is linked to resource/energy state rather than elapsed time. Once a size and energy threshold are reached, the bacterium can undergo binary fission.

### Binary fission

The parent state is replaced by two daughters:
- positioned along the parent axis;
- approximately half-size;
- sharing the parent's energy;
- carrying generation/lineage metadata.

Each daughter now inherits a compact genotype from the parent and receives small seeded mutations. These traits affect propulsion, chemotaxis, nutrient uptake, growth, body size, tumble tendency, and visible appendages. See `docs/EVOLUTION.md`.

### Death and recycling

v0.1 supports energetic death as a state transition.

Later versions should distinguish:
- starvation;
- lysis;
- predation;
- toxin damage;
- dormancy.

Dead biomass should eventually return material to environmental fields rather than simply vanish.

## What is deliberately postponed

- species-specific calibration;
- cell-wall mechanics;
- hydrodynamics;
- explicit hydrodynamic flagellar bundles (the current flagella are a coarse phenotype/propulsion model);
- quorum sensing;
- explicit pilus attachment/conjugation mechanics (the current pili are visible morphology only);
- biofilm ECM;
- predator ingestion;
- eukaryotic membranes/pseudopods.

Those systems should be added only with their own model notes and validation plan.
