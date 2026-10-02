# Living biome design

MicroC0re is no longer just a population of cells on top of a nutrient texture. The active direction is a **spatial aquatic micro-ecosystem** where organisms both respond to and modify their environment.

## Design principle

The interesting state should emerge from feedback loops:

```
light / dissolved resources / oxygen / flow
                  ↓
          primary producers
                  ↓
 dissolved organic matter / biomass
           ↙              ↘
 heterotrophs            decomposers
       ↓                     ↓
 grazers / predators ← detritus / damage cues
       ↓                     ↓
     death ─────────────→ recycling
       ↑
 evolution / HGT / phenotype switching
```

There is no global fitness score and no scripted ecological winner.

## Why spatial structure matters

Microbial communities are strongly shaped by short interaction ranges, resource gradients, spatial refuges and niche construction. Spatial structure changes competition, cross-feeding, quorum sensing and evolutionary dynamics.

MicroC0re therefore treats environmental fields and local neighborhoods as first-class simulation state rather than decorative background.

## Current biome fields

### Nutrient

Existing dissolved-resource field used by heterotrophic growth.

### Oxygen

Dynamic diffusing oxygen.

Current effects:
- aerobic energy yield depends partly on local oxygen;
- producer mats and phototrophic ecotypes release oxygen;
- oxygen diffuses and decays.

Future:
- explicit anaerobic guilds;
- redox interfaces;
- diel oxygen oscillation.

### Producer biomass

A coarse continuum representation of cyanobacteria/microalgal microbial mats.

Current behavior:
- biomass is seeded in spatial patches;
- light supports growth;
- active biomass releases oxygen;
- a small dissolved-organic leak feeds the microbial loop.

This field is a bridge to explicit producer organisms in #40. It should not remain the only representation of producers.

### Detritus / carrion

Dead biomass and feeding leakage enter a detritus field instead of disappearing.

Current consumers:
- scavenger bacterial ecotype;
- bacteria carrying the mobile scavenge module.

Future:
- fungal/yeast decomposers;
- extracellular enzyme breakdown;
- particulate aggregates.

### EPS / biofilm matrix

Cells with a biofilm-like phenotype or high adhesion secrete EPS at an energy cost.

Current effects:
- EPS persists spatially;
- high local EPS slows bacterial movement;
- secretion changes the environment.

Future:
- nutrient retention;
- flow reduction;
- predator refuge;
- quorum-controlled secretion;
- cooperative/cheater dynamics.

### Damage / lysis cue

Death, lysis and active predation emit a short-lived diffusing cue.

This represents a generic mixture of soluble material released from damaged cells: amino acids, organic acids and other chemoeffectors. It is intentionally **not called blood** in the aquatic biome.

Current effects:
- scavenger bacteria bias run-and-tumble sensing toward detritus/damage;
- amoebae and ciliates without directly visible prey bias searching toward the plume;
- predation and lysis therefore create observable ecological hotspots.

A true host/blood chemistry module is separately tracked in #52.

### Water/current

A first deterministic flow term advects organisms while preserving self-propulsion.

Future #48:
- vector flow field;
- field advection;
- vortices/wakes;
- EPS flow barriers;
- sedimentation.

### Light

A deterministic spatial light gradient currently drives producer activity and phototroph energy gain.

Future #56:
- day/night cycle;
- self-shading;
- oxygen/redox oscillation;
- diel migration/dormancy.

## Current bacterial ecotypes

The existing generic bacterial genotype now also carries a stable ecological guild.

### Heterotroph

General dissolved-resource competitor.

### Scavenger

Specialized for detrital niches.

- stronger access to detrital energy;
- chemotaxis includes detritus/damage cues;
- overlaps with the mobile scavenge plasmid but is not identical to it.

### Biofilm builder

Slower, more adhesive niche constructor.

- increased EPS secretion;
- reduced free-swimming speed;
- alters local movement conditions.

### Phototroph

Light-assisted producer ecotype.

- reduced motility;
- gains energy from light;
- releases oxygen;
- leaks a small amount of dissolved resource.

These are **ecotypes / functional guilds**, not claims that four real taxonomic species are being simulated.

## Existing predator guilds

### Amoeboid predator

Slow deformable phagocytic grazer with staged engulfment.

### Ciliate-like grazer

Faster directional grazer.

Both:
- can reproduce from prey-derived energy;
- evolve heritable traits;
- can starve;
- now enter a visible death/lysis sequence;
- recycle into detritus;
- can orient toward damage plumes when no direct prey is detected.

## Death and recycling contract

Death must never be only `entity -> delete`.

Observable chain:

1. energetic stress / lethal event;
2. visible dying state;
3. membrane/body deformation or fragmentation;
4. dissolved damage cue;
5. detrital biomass;
6. scavenger/decomposer attraction;
7. resource re-entry into the food web.

Predation similarly has pursuit, contact, handling/engulfment, prey disappearance inside the predator and leakage/recycling.

## Research-backed expansion map

### Microbial loop

Aquatic food webs recycle dissolved organic matter through bacteria, protists and viruses. This motivates producer -> DOM -> bacteria -> grazers -> death/recycling loops.

Reference:
- https://www.nature.com/articles/nrmicro1180
- https://pmc.ncbi.nlm.nih.gov/articles/PMC4962909/

### Cross-feeding

Metabolites produced by one population can become resources for another, with optional or obligate dependencies.

Tracked by #42.

Reference:
- https://pmc.ncbi.nlm.nih.gov/articles/PMC8721230/

### Phycosphere

Microscale bacterial interactions around individual phytoplankton cells can form distinct local niches.

Tracked by #53.

Reference:
- https://www.nature.com/articles/nmicrobiol201765
- https://www.nature.com/articles/s41564-026-02287-6

### Biofilm heterogeneity

Biofilms create nutrient, oxygen, waste and signaling gradients and can intensify local interaction/HGT.

Tracked by #34 and #43.

References:
- https://www.nature.com/articles/nrmicro2415
- https://www.nature.com/articles/s41579-022-00692-2

### Dormancy / microbial seed bank

Dormancy can preserve rare genotypes and stabilize communities through environmental fluctuations.

Tracked by #33 and #51.

Reference:
- https://www.nature.com/articles/nrmicro2504

### Predation / coevolution

Microbial predation can reshape morphology, behavior, genetics and community stability.

Tracked by #35, #45 and #49.

Reference:
- https://www.nature.com/articles/s41579-026-01299-7

### Viral control / viral shunt

Phage infection provides a top-down control while returning host material to dissolved resource pools.

Tracked by #30.

Reference:
- https://www.nature.com/articles/s41579-019-0270-x

### Chemotactic damage cues

Bacteria can respond to many chemoeffectors, including amino acids, organic acids, oxygen and other metabolically informative compounds.

This supports the generic lysis/damage plume mechanic.

Reference:
- https://journals.asm.org/doi/10.1128/jb.00300-24

### Microbial mats / diel gradients

Photosynthetic oxygen production and respiration can generate strong spatial and temporal chemical gradients.

Tracked by #40, #50 and #56.

Reference:
- https://pmc.ncbi.nlm.nih.gov/articles/PMC12168310/

### Larger microfauna

Aquatic micro-food webs can include bacteria, fungi, algae, protozoa and later larger microfauna such as rotifers/nematodes.

Tracked by #44, #54 and #55.

References:
- https://pmc.ncbi.nlm.nih.gov/articles/PMC12372383/
- https://pmc.ncbi.nlm.nih.gov/articles/PMC7120757/

## Issue map

- #38 biome epic
- #39 oxygen/light/detritus/EPS/damage fields
- #40 explicit phototroph/cyanobacterial producers
- #41 scavengers / carrion chemotaxis
- #42 metabolic cross-feeding
- #43 EPS/biofilm ecosystem engineering
- #44 expanded organism guilds/morphologies
- #45 visible feeding/death/recycling animation
- #48 water flow / hydrodynamics
- #49 multi-trophic predation
- #50 pH/temperature/redox/toxicity
- #51 succession/disturbance
- #52 optional host-tissue/blood chemistry
- #53 phycosphere symbiosis
- #54 fungi/yeast/hyphae decomposers
- #55 rotifer/nematode microfauna
- #56 day/night/diel cycle

Evolution continues through #13, #30–#36.

## Performance architecture

The CPU implementation is the deterministic reference, not the final scaling path.

Biome fields are explicitly intended for GPU compute:
- one or more packed field textures/buffers;
- fused diffusion/decay/advection kernels;
- producer/source/sink passes;
- no full per-tick GPU readback;
- visualization should consume GPU-resident fields directly.

Agent populations should remain bounded until GPU-resident agent mechanics is validated.

## Visual contract

The biome must remain readable pixel art.

At overview:
- large environmental structures are visible;
- organisms use consistent LOD markers;
- no single stale LOD path may produce a giant sprite.

At close zoom:
- producer mats, EPS, damage plumes and detrital zones become visually distinguishable;
- feeding and death states are animated;
- organism morphology remains more important than debug overlays.
