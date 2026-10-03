# Research notes and primary references

This document is the bibliography and model-selection notebook for MicroC0re.

## Reaction-diffusion / morphogenesis

### Turing, 1952
Alan M. Turing, **The Chemical Basis of Morphogenesis**, Philosophical Transactions of the Royal Society B 237, 37–72.

DOI: https://doi.org/10.1098/rstb.1952.0012

Why it matters:
- establishes reaction-diffusion as a mechanism for spontaneous spatial pattern formation;
- motivates chemical fields that can generate structure without scripted textures.

Use in MicroC0re:
- theoretical foundation;
- later morphogen/environment experiments;
- not a bacterial physiology model by itself.

### Pearson, 1993
J. E. Pearson, **Complex patterns in a simple system**, Science 261, 189–192.

DOI: https://doi.org/10.1126/science.261.5118.189

Why it matters:
- catalogs rich Gray-Scott reaction-diffusion regimes;
- includes spots that grow and split under some parameters.

Use in MicroC0re:
- separate reaction-diffusion laboratory;
- source of emergent chemical/pattern behavior;
- never used to claim that a Gray-Scott spot is literally a bacterium.

## Chemotaxis

### Keller & Segel, 1971
E. F. Keller and L. A. Segel, **Model for chemotaxis**, Journal of Theoretical Biology 30, 225–234.

DOI: https://doi.org/10.1016/0022-5193(71)90050-6

Why it matters:
- foundational mathematical treatment connecting local cellular behavior to macroscopic chemotactic flux.

Use in MicroC0re:
- continuum reference and later population-level validation.

### Berg & Brown, 1972
H. C. Berg and D. A. Brown, **Chemotaxis in Escherichia coli analysed by Three-dimensional Tracking**, Nature 239, 500–504.

DOI: https://doi.org/10.1038/239500a0

Why it matters:
- experimental single-cell trajectories;
- favorable stimuli suppress directional changes rather than steering like a homing missile.

Use in MicroC0re:
- run-and-tumble temporal sensing design.

## Growth / nutrient limitation

### Monod, 1949
Jacques Monod, **The Growth of Bacterial Cultures**, Annual Review of Microbiology 3, 371–394.

DOI: https://doi.org/10.1146/annurev.mi.03.100149.002103

Why it matters:
- classic quantitative treatment of bacterial growth and limiting nutrients.

Use in MicroC0re:
- saturating nutrient-response inspiration;
- eventual calibration of growth regimes.

## Mechanical colony growth

### Farrell et al., 2013
F. D. C. Farrell, O. Hallatschek, D. Marenduzzo, B. Waclaw, **Mechanically Driven Growth of Quasi-Two-Dimensional Microbial Colonies**, Physical Review Letters 111, 168101.

DOI: https://doi.org/10.1103/PhysRevLett.111.168101

Why it matters:
- rod-shaped bacteria consume diffusing nutrient and interact mechanically;
- mechanical interactions can alter colony morphology.

Use in MicroC0re:
- justification for rod geometry + explicit contact mechanics + diffusing nutrient rather than decorative collisions.

## Modern agent-based biofilm review

### Nam et al., 2025
Kee-Myoung Nam et al., **Dissecting the physics of bacterial biofilms with agent-based simulations**, Current Opinion in Solid State and Materials Science 37, 101228.

DOI: https://doi.org/10.1016/j.cossms.2025.101228

Why it matters:
- reviews cell shape, growth, division, forces, ECM, and hybrid modeling choices in modern bacterial colony/biofilm ABMs;
- emphasizes that ABMs are flexible and may use phenomenological ingredients.

Use in MicroC0re:
- architecture reference;
- reminder to label assumptions and avoid false precision.

## Research rules

When adding a paper:
1. write the exact mechanism it supports;
2. state whether it is experimental, theoretical, simulation, or review evidence;
3. do not transplant parameters between species/environments without justification;
4. distinguish “inspired by” from “validated against”;
5. add a validation idea when a paper motivates a new behavior.


## Horizontal gene transfer and microbial evolution

### Conjugation

Review: **Plasmid Transfer by Conjugation in Gram-Negative Bacteria: From the Cellular to the Community Level**

https://pmc.ncbi.nlm.nih.gov/articles/PMC7690428/

Why it matters:
- direct cell-cell DNA transfer is a major HGT mechanism;
- conjugative plasmids can spread metabolic, biofilm and resistance-related functions;
- contact and pili/T4SS-like machinery justify a staged physical interaction.

Use in MicroC0re:
- #31 direct-contact plasmid transfer;
- visible pixel mating bridge;
- mobile trait modules with fitness cost.

### Natural transformation

Review: **Natural Competence and the Evolution of DNA Uptake Specificity**

https://pmc.ncbi.nlm.nih.gov/articles/PMC3993363/

Why it matters:
- competent bacteria can actively import extracellular DNA;
- homologous incoming DNA may alter genotype by recombination;
- extracellular DNA can also provide nutrients.

Use in MicroC0re:
- #32 extracellular DNA after lysis;
- competence state;
- trait recombination vs nutrient use.

### Phage transduction

Review: **Genetic transduction by phages and chromosomal islands: The new and noncanonical**

https://pmc.ncbi.nlm.nih.gov/articles/PMC6687093/

Use in MicroC0re:
- phage-mediated HGT belongs to #30, not to conjugation.

## Phenotypic heterogeneity / differentiation

Review: **Diversity of bet-hedging strategies in microbial communities**

https://pmc.ncbi.nlm.nih.gov/articles/PMC9286555/

Review: **Bacterial cell differentiation enables population level survival strategies**

https://pmc.ncbi.nlm.nih.gov/articles/PMC11237816/

Why they matter:
- one genotype can generate multiple physiological states;
- switching may support environmental adaptation, division of labor and bet-hedging.

Use in MicroC0re:
- #33 reversible motile / adhesive / high-growth / dormant states;
- evolvable switching thresholds/rates.

## Quorum sensing and biofilm evolution

Review/model study: **The Evolution of Quorum Sensing in Bacterial Biofilms**

https://pmc.ncbi.nlm.nih.gov/articles/PMC2214811/

Why it matters:
- density-dependent signaling can regulate attachment, EPS and competence;
- matrix secretion has social benefits and costs;
- cooperative and cheating strategies are plausible evolutionary outcomes.

Use in MicroC0re:
- #34 autoinducer field + EPS/matrix;
- colony structure and social evolution.

## Predator-prey eco-evolution

### Protist diversity and stability

**Diversity of protists and bacteria determines predation performance and stability**

https://pmc.ncbi.nlm.nih.gov/articles/PMC3965320/

Why it matters:
- multiple predator/prey types can change community stability and productivity;
- predator identity matters.

### Rapid prey defence evolution

**Environmental fluctuations restrict eco-evolutionary dynamics in predator-prey system**

https://pmc.ncbi.nlm.nih.gov/articles/PMC4455795/

Why it matters:
- bacterial prey can evolve anti-predator defence such as aggregation;
- ecological population change and evolutionary trait change feed back on one another.

### Kill the winner

**Understanding Bacteriophage Specificity in Natural Microbial Communities**

https://pmc.ncbi.nlm.nih.gov/articles/PMC3705297/

Why it matters:
- host-specific phages can impose negative frequency-dependent selection;
- common host lineages can experience stronger phage pressure.

Use in MicroC0re:
- #30 host-lineage-specific phage pressure;
- diversity maintenance rather than unlimited dominance by one bacterial lineage.


## Living aquatic biome research

The current ecosystem expansion is summarized in `docs/BIOME.md`.

### Spatial structure and niche construction

Recent review:
https://pmc.ncbi.nlm.nih.gov/articles/PMC12892361/

Use in MicroC0re:
- local gradients rather than globally mixed resources;
- patchy producer/carrion/biofilm niches;
- short-range ecological and evolutionary interactions.

### Aquatic microbial loop

Protist predation / microbial loop review:
https://www.nature.com/articles/nrmicro1180

Aquatic viral-particle ecology:
https://pmc.ncbi.nlm.nih.gov/articles/PMC4962909/

Use:
- dissolved material -> bacteria -> protist grazers;
- predation/lysis -> detritus / dissolved resources;
- later viral shunt.

### Cross-feeding

Review:
https://pmc.ncbi.nlm.nih.gov/articles/PMC8721230/

Use:
- one guild's secreted/waste metabolite becomes another guild's resource;
- optional vs obligate dependencies;
- spatially local public goods.

### Phytoplankton / phycosphere

Review:
https://www.nature.com/articles/nmicrobiol201765

2026 attachment review:
https://www.nature.com/articles/s41564-026-02287-6

Use:
- explicit producer organisms around #40;
- microscale organic exudate halos;
- bacterial attachment, mutualism/parasitism and nutrient exchange (#53).

### Phytoplankton-associated recyclers

Review:
https://www.nature.com/articles/nrmicro3326

Use:
- producer bloom -> detrital/recycler succession;
- decomposer guilds and organic-matter transformation.

### Biofilm matrix / chemical heterogeneity

Reviews:
https://www.nature.com/articles/nrmicro2415
https://www.nature.com/articles/s41579-022-00692-2

Use:
- EPS as ecosystem engineering;
- local nutrient/oxygen/waste gradients;
- increased contact/HGT;
- motility/transport changes.

### Dormancy / microbial seed banks

Review:
https://www.nature.com/articles/nrmicro2504

Use:
- reversible low-metabolism state;
- persistence of rare lineages;
- recovery after disturbance;
- succession / long-term stability.

### Predation and coevolution

2026 review:
https://www.nature.com/articles/s41579-026-01299-7

Use:
- different searching/handling modes;
- visible predation states;
- prey defence evolution;
- community-level feedbacks.

### Viral shunt

Review:
https://www.nature.com/articles/s41579-019-0270-x

Use:
- phage infection links top-down mortality to resource recycling;
- later #30 host-specific kill-the-winner dynamics.

### Chemotactic damage / carrion cues

2024 amino-acid chemotaxis review:
https://journals.asm.org/doi/10.1128/jb.00300-24

The review emphasizes that bacteria can respond to amino acids plus many organic/inorganic chemoeffectors.

Use:
- current generic `damage_cue` for material released by lysis/predation;
- scavenger chemotaxis;
- predator search cue.

This does **not** imply literal blood sensing in the current aquatic biome. Host-tissue chemistry is #52.

### Microbial mats, light and oxygen gradients

Review:
https://pmc.ncbi.nlm.nih.gov/articles/PMC12168310/

Use:
- producer-biomass field;
- light-driven oxygenation;
- diel cycle;
- later pH/redox layering.

### Aquatic micro-food web diversity

Recent study/background:
https://pmc.ncbi.nlm.nih.gov/articles/PMC12372383/

General aquatic microbiology reference:
https://pmc.ncbi.nlm.nih.gov/articles/PMC7120757/

Use:
- bacteria;
- fungi;
- microalgae;
- protozoa;
- later rotifer/nematode-like microfauna.

### Resource trade-offs and coexistence

Review:
https://pmc.ncbi.nlm.nih.gov/articles/PMC4389539/

Use:
- no universally best trait;
- resource-use trade-offs;
- spatial heterogeneity + predators + parasites support coexistence.

### Succession / colonization trade-off

Study:
https://pmc.ncbi.nlm.nih.gov/articles/PMC9710175/

Use:
- explorer vs strong-competitor ecotypes;
- patch disturbance/recolonization;
- priority effects.


## Open-ended artificial evolution / implementation direction

### Karl Sims — evolving morphology and control
Karl Sims, **Evolving Virtual Creatures**, SIGGRAPH 1994.

https://www.karlsims.com/papers/siggraph94.pdf

Use in MicroC0re:
- variable-size structured genotypes rather than only fixed scalar knobs;
- developmental/genotype-to-phenotype separation;
- mutation/recombination can change structure, not only parameter values.

### NEAT — structural innovation + speciation
Stanley & Miikkulainen, **Evolving Neural Networks through Augmenting
Topologies**, Evolutionary Computation 10(2), 2002.

https://direct.mit.edu/evco/article/10/2/99/1123/

Use:
- incremental complexification is more evolvable than starting with maximal
  structure;
- structural innovations need time/protection rather than immediate comparison
  only against an established optimum;
- MicroC0re borrows variable topology + innovation identity, not the task
  fitness function.

### Artificial gene regulatory networks
Cussat-Blanc, Harrington & Banzhaf, **Artificial Gene Regulatory Networks—A
Review**, Artificial Life 24(4), 2018.

https://direct.mit.edu/artl/article/24/4/296/2909/

Use:
- environmental signals mediate genotype -> phenotype;
- regulation lets one genome express different strategies in different local
  conditions;
- current #64 module sensors/thresholds are a deliberately small first GRN.

### Avida / digital evolution
Review: **Digital Evolution for Ecology Research**, Frontiers in Ecology and
Evolution, 2021.

https://www.frontiersin.org/journals/ecology-and-evolution/articles/10.3389/fevo.2021.750779/full

Use:
- implicit fitness: survival/reproductive success emerges from the simulated
  ecology rather than a designer score;
- effectively large genotype spaces + ecological interactions are core to
  interesting eco-evolution.

### Tangled Nature
Christensen et al., **Tangled Nature: a model of evolutionary ecology**,
Journal of Theoretical Biology 216(1), 2002.

https://doi.org/10.1006/jtbi.2002.2530

Use:
- interactions among coexisting genotypes can make species/ecological
  organizations emerge;
- useful target behavior is alternating reorganization and quasi-stable
  communities, not monotonic march toward one optimum.

### Novelty / stepping stones
Lehman & Stanley, **Abandoning Objectives**, Evolutionary Computation 19(2),
2011.

https://pubmed.ncbi.nlm.nih.gov/20868264/

Secretan et al., **Picbreeder**, Evolutionary Computation 19(3), 2011.

https://pubmed.ncbi.nlm.nih.gov/20964537/

Use:
- avoid assuming that a single global objective defines interesting evolution;
- later #64 novelty archive is observational/diversity-preserving support, not
  a replacement global fitness function.

### MAP-Elites / quality diversity
Mouret & Clune, **Illuminating search spaces by mapping elites**, 2015.

https://arxiv.org/abs/1504.04909

Use:
- later offline/headless analysis can retain representative high-performing
  ecotypes across phenotype niches instead of reporting only one winner.

### Open-ended evolution
Taylor et al., **Open-Ended Evolution: Perspectives from the OEE Workshop in
York**, Artificial Life 22(3), 2016.

https://doi.org/10.1162/ARTL_a_00210

Packard et al., **An Overview of Open-Ended Evolution**, Artificial Life 25(2),
2019.

https://pubmed.ncbi.nlm.nih.gov/31150285/

Use:
- continuous novelty is not guaranteed by "having mutations";
- distinguish exploratory novelty inside a fixed space from later expansive /
  transformational innovation that changes what phenotypes can exist.

### Creatures
Grand et al., **The Creatures Global Digital Ecosystem**, Artificial Life 5(1),
1999.

https://direct.mit.edu/artl/article/5/1/77/2314/

Use:
- a commercial ALife example where genetically specified internal systems,
  recurrent control, sexual recombination and gene duplication allowed
  combinations not explicitly authored as individual creatures.

Engineering rule for MicroC0re: use these mechanisms as architecture
inspiration while keeping the ecological selection local and physically paid
for. Do not bolt a hidden "interestingness fitness" onto the live simulation.


## Living terrain / bioturbation / isometric world

### Burrowing fauna as ecosystem engineers
Loreggian et al., **The inclusion of burrowing animals in soil hydro-physical
equations and models: A review**, Earth-Science Reviews 281 (2026).
https://doi.org/10.1016/j.earscirev.2026.105591

Use:
- excavation is physical material transport, not a decal;
- burrowing affects surface transport, mixing, infiltration and soil structure;
- terrain and organism dynamics need two-way coupling.

### Global zoogeomorphology
**Global diversity and energy of animals shaping the Earth's surface**, PNAS
(2025).
https://pmc.ncbi.nlm.nih.gov/articles/PMC11874378/

Use:
- agents can alter terrain by bioturbation, bioerosion, bioconstruction and
  bioprotection.

### Termite mound morphogenesis
Ocko, Heyde & Mahadevan, **Morphogenesis of termite mounds**, PNAS (2019).
https://pmc.ncbi.nlm.nih.gov/articles/PMC6397510/

Use:
- local building changes geometry;
- geometry changes heat/mass transport and signals;
- signals alter later building, closing a stigmergic feedback loop.

### Surface curvature and stigmergy
**Surface curvature guides early construction activity in mound-building
termites**, Phil. Trans. R. Soc. B (2019).
https://pmc.ncbi.nlm.nih.gov/articles/PMC6553597/

Use:
- persistent topography can act as external memory;
- later builders should sense slope/curvature and evolve deposition rules.

### Godot 4.7
Camera3D orthogonal projection:
https://docs.godotengine.org/en/latest/classes/class_camera3d.html
ArrayMesh:
https://docs.godotengine.org/en/4.7/classes/class_arraymesh.html
MultiMesh:
https://docs.godotengine.org/en/4.7/tutorials/performance/using_multimesh.html

Use:
- orthographic Camera3D provides a rotatable isometric-like view;
- procedural meshes support mutable terrain;
- MultiMesh batches large organism populations and capability appendages.
