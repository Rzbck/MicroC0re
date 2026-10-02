# Evolution model

MicroC0re now has a first **continuous clonal evolution** layer.

This is deliberately simpler than a full artificial-life brain system: bacteria reproduce by binary fission, daughters inherit a genotype, and seeded mutations perturb that genotype. Natural selection can then emerge from competition for the same chemical resources.

## Heritable traits

Each bacterium currently carries:

- `gene_speed` — propulsion potential;
- `gene_chemotaxis` — strength of temporal chemotactic bias;
- `gene_uptake` — nutrient uptake capacity;
- `gene_growth` — efficiency of turning consumed material into growth;
- `gene_size` — body size / division-size tendency;
- `gene_tumble` — baseline run/tumble tendency;
- `flagella_count` — discrete propulsion appendage count;
- `flagella_length` — flagellar length factor;
- `pili_count` — visible short surface appendages;
- `mutation_rate` — inherited mutation probability;
- `lineage_hue` — slowly drifting visible lineage marker.

The visual phenotype is therefore coupled to actual simulated traits rather than being a random decorative skin.

## Mutation

At each binary fission, both daughters inherit the parent's traits.

Each trait has:
- a mutation probability;
- a small Gaussian perturbation when mutation occurs;
- hard bounds preventing numerically absurd values.

Discrete appendage counts mutate by +/-1.

The simulation RNG is seeded, so the same seed and timestep produce the same mutation history.

## Trade-offs

Evolution is only interesting when "more" is not always better.

The first trade-offs are:

- more / longer flagella increase propulsion but also locomotion and appendage energy cost;
- larger cells pay more maintenance and experience more drag;
- higher uptake capacity has an energetic maintenance cost;
- growth efficiency can shorten generation time but only when nutrient is available;
- tumble / chemotaxis traits can help in patchy gradients but do not create omniscient steering.

These are qualitative ALife trade-offs, not calibrated species-specific measurements.

## Selection

There is no fitness score.

A lineage persists only if its organisms:
1. obtain enough nutrient;
2. cover maintenance / locomotion costs;
3. grow;
4. reach the state-dependent fission threshold;
5. produce descendants that continue doing the same under competition.

This lets selection emerge from resource flow rather than from an explicit reward function.

## Visual lineage

Hue changes only slowly across mutation, so relatives remain visually related while long-running descendants can drift.

Body scale, flagella, and pili also reveal phenotype directly.

## Not implemented yet

- neural-network brains;
- sexual reproduction;
- horizontal gene transfer / conjugation;
- explicit genome sequence;
- speciation clustering;
- lineage tree UI;
- evolvable predation / toxins;
- evolvable reaction networks.

Those can be added later without replacing the current deterministic inheritance layer.
