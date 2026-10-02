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
