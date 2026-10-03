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

## Horizontal gene transfer

MicroC0re now includes a first **plasmid-conjugation** layer in addition to vertical inheritance.

A minority of bacterial founders carry mobile plasmid modules. A conjugative donor can transfer one missing module to a nearby recipient after sustained direct contact. The transfer is staged over time and rendered as a pixel bridge rather than as an instantaneous copy.

Current qualitative mobile modules:
- **conjugation** — enables plasmid transfer;
- **scavenge** — increases nutrient-uptake capacity;
- **adhesion** — increases effective cell-cell adhesion;
- **stress** — reduces maintenance burden.

All plasmids have a small energetic burden, so carrying every module is not free.

This is intentionally a coarse mobile-gene model. It is not a claim that one real plasmid necessarily carries this exact set of functions.

Biological motivation:
- conjugation is a major horizontal gene-transfer mechanism based on direct cell-cell contact and conjugative mobile elements;
- plasmids can spread adaptive metabolic, biofilm and resistance-related functions through bacterial communities.

Tracked by #31.

## Evolution concepts researched for the next layers

### Natural transformation — #32

Some bacteria become competent and actively take up extracellular DNA. Compatible DNA can recombine with the chromosome, while environmental DNA can also be used as a nutrient source.

Planned MicroC0re model:
- lysis releases a bounded extracellular-DNA field or fragment pool;
- competence is a costly, heritable switching trait;
- competent cells can either catabolize DNA or recombine compatible traits;
- transformation remains distinct from plasmid conjugation.

### Phage transduction — #30

Bacteriophages can move bacterial DNA between hosts. Transduction therefore belongs in the future phage system rather than being folded into conjugation.

The phage layer is also a natural place for **negative frequency-dependent / kill-the-winner dynamics**, where locally dominant host lineages face stronger phage pressure.

### Phenotypic switching / bet-hedging — #33

Genetically similar microbes can occupy different physiological states. This can spread risk under fluctuating environments.

Candidate reversible states:
- motile explorer;
- adhesive/chaining;
- high-growth;
- low-metabolism dormant/persister-like.

Genes should tune state-switching probabilities and environmental thresholds, while the state itself remains non-genetic.

### Cell differentiation / division of labor — #33

Microbial populations can split into functionally different subpopulations. In MicroC0re this can produce visually and ecologically distinct jobs inside one lineage without inventing a new species for every role.

### Quorum sensing and EPS/biofilm — #34

Local signal concentration can regulate density-dependent group behavior. A future autoinducer field can control:
- matrix/EPS secretion;
- adhesion;
- motility suppression;
- competence;
- cooperative resource capture.

Matrix production should have an energetic cost so cooperative and low-contribution strategies can compete.

### Predator-prey eco-evolution

Protist grazing can select for prey defence traits such as aggregation and can interact with standing genetic variation. This motivates future bacterial anti-predator traits rather than treating predation as a fixed one-way mechanic.

Candidate evolvable defences:
- stronger chaining/aggregation;
- larger/smaller morphology;
- EPS/biofilm investment;
- toxin secretion later;
- altered motility.

Predator traits can coevolve in response.

## Research references

- Conjugative plasmid transfer review: https://pmc.ncbi.nlm.nih.gov/articles/PMC7690428/
- Natural competence / DNA uptake specificity: https://pmc.ncbi.nlm.nih.gov/articles/PMC3993363/
- Mobile bacterial gene pool / HGT mechanisms: https://pmc.ncbi.nlm.nih.gov/articles/PMC5665811/
- Phage transduction review: https://pmc.ncbi.nlm.nih.gov/articles/PMC6687093/
- Microbial bet-hedging review: https://pmc.ncbi.nlm.nih.gov/articles/PMC9286555/
- Bacterial differentiation / division of labor review: https://pmc.ncbi.nlm.nih.gov/articles/PMC11237816/
- Quorum sensing / biofilm evolution: https://pmc.ncbi.nlm.nih.gov/articles/PMC2214811/
- Protist/bacteria diversity and predation stability: https://pmc.ncbi.nlm.nih.gov/articles/PMC3965320/
- Predator-prey eco-evolution in microbes: https://pmc.ncbi.nlm.nih.gov/articles/PMC4455795/
- Kill-the-winner phage dynamics: https://pmc.ncbi.nlm.nih.gov/articles/PMC3705297/

## Not implemented yet

- explicit genome sequence;
- speciation clustering;
- lineage tree UI;
- natural transformation;
- phage transduction;
- phenotypic switching/dormancy;
- quorum sensing/EPS;
- explicit coevolutionary defence traits;
- evolvable reaction networks.

These should extend the current inheritance layer rather than replace it.


## Open-ended modular genome — #64

The first structural-genome layer replaces the assumption that ecological roles
must remain a fixed hand-authored guild.

Each bacterium now carries a bounded **variable-length module program** in
addition to quantitative morphology/motility alleles. Current modules can
express:
- dissolved nutrient uptake;
- exudate/cross-feeding uptake;
- detrital scavenging;
- phototrophy;
- EPS/matrix investment;
- quorum-signal production.

Each module also carries:
- expression strength;
- an environmental sensor;
- a regulatory threshold;
- activating or repressing polarity;
- an innovation identifier.

Sensors currently include nutrient, exudate, detritus, light, quorum signal,
damage, low energy and oxygen. Therefore the same inherited module topology can
express a different phenotype in different microenvironments.

Reproduction can now produce point changes **and structural changes**:
- module duplication;
- module deletion;
- new module insertion;
- regulatory sensor rewiring;
- activation/repression flips;
- rare functional rewiring.

Genome size is hard-bounded from 2 to 14 modules in the CPU reference. Expressed
modules and genome complexity have an energetic cost, preventing a trivial
"express everything maximally" strategy.

The old four bacterial guild labels are now only a rendering/morphology
classification derived from the currently expressed program. A cell can become
a photo+matrix, scavenger+crossfeed or other mosaic phenotype without a new
scripted species class.

Natural transformation now carries a sampled functional module in addition to a
scalar allele. Compatible DNA can therefore merge a donor module into the
recipient genome. Conjugation also has a rare Hfr-like chromosomal-module
recombination path in addition to plasmid cargo. Vertical ancestry and
horizontal module acquisition remain distinct counters.

This is **not yet unlimited open-ended evolution**: module function types and
environmental channels are still bounded. #64 phase 4 will replace more
hard-coded metabolic roles with evolvable reaction modules over explicit
chemical channels.


## Shared physical-capability genome — #65

Every current organism family now carries the same bounded, variable-length
physical capability program. Digging, carrying, deposition, burrowing, climbing,
oviposition potential and armor are therefore not permanently owned by a
hard-coded species.

Capability modules have strength, sensor, regulatory threshold, polarity and an
innovation identity. They can duplicate, delete, insert, rewire their sensor,
flip regulation and rarely transmute into another capability. Founder biases
differ, but the representation is shared across bacteria, protists, algae,
decomposers and hyphae.

The first physical expression is terraforming: excavation removes actual
height-field material into an organism's carried-soil store; deposition returns
that mass elsewhere. Slopes feed back on movement, so climbing and burrowing
change what terrain an organism can traverse. Digging, armor, oviposition
potential and below-surface depth also alter visible 3D morphology.

Explicit egg entities and true tunnel occupancy are phase 2 of #65; the
evolvable capability representation is already in place for them.
