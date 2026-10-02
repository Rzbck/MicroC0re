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

## Predator guilds

### Amoeboid / protist predators

MicroC0re now includes a separate large amoeboid/protist class.

It:
- moves more slowly than bacteria;
- visually deforms through discrete pixel-art poses;
- senses nearby bacterial prey;
- pulls prey inward over a visible engulfment interval;
- gains energy only after ingestion completes;
- spends energy continuously on maintenance;
- can starve and disappear;
- can reproduce after sufficient feeding.

The predator phenotype is heritable and mutable:
- speed;
- perception range;
- engulfment rate;
- body size;
- metabolism.

This is intended as a qualitative protist-like phagocytosis model, not a calibrated amoeba species.

### Ciliate-like grazers

A second eukaryotic predator guild is faster and more directional.

It:
- swims using a cilia-inspired pixel animation;
- searches a larger area;
- captures bacteria at an oral-side feeding region;
- has a shorter feeding cycle than the amoeboid predator;
- spends energy continuously;
- starves when prey is unavailable;
- reproduces after accumulating prey-derived energy.

Its heritable traits include:
- swimming speed;
- perception;
- capture rate;
- size;
- metabolism.

The two predator guilds intentionally occupy different ecological niches so that the food web can show more than one top-down control strategy.

## Population regulation

The live CPU-reference ecosystem is controlled by two distinct mechanisms.

### Biological regulation
- nutrient enters at a fixed finite rate;
- bacteria compete for the same nutrient field;
- bacterial growth is energy/resource limited;
- amoeboid predators remove bacteria by staged engulfment;
- ciliate-like grazers remove bacteria more quickly in dense patches;
- predators pay maintenance costs and can starve;
- predator reproduction requires successful feeding.

### Performance safety guard
Until GPU-resident agent mechanics replaces the current CPU-reference path:
- bacteria are capped at 420 live agents;
- amoeboid predators are capped at 18;
- ciliates are capped at 16.

The guard suppresses additional reproduction at the ceiling. It does **not** delete arbitrary live cells and is not claimed as biology.

## Planned ecological control

A later layer will investigate bacteriophage "kill-the-winner" dynamics:
- host specificity;
- infection latency;
- lysis;
- burst/replication;
- nutrient recycling through a viral-shunt-like mechanism.

This is tracked separately so phages can use a bounded/GPU-friendly representation rather than millions of literal virus agents.

## What is deliberately postponed

- species-specific calibration;
- cell-wall mechanics;
- hydrodynamics;
- explicit hydrodynamic flagellar bundles (the current flagella are a coarse phenotype/propulsion model);
- quorum sensing;
- explicit pilus attachment/conjugation mechanics (the current pili are visible morphology only);
- mature biofilm ECM;
- calibrated protozoan/ciliate physiology;
- detailed membrane mechanics.

Those systems should be added only with their own model notes and validation plan.
