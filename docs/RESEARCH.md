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
