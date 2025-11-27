# DINO Subgrid Momentum

[![DOI](https://zenodo.org/badge/776021044.svg)](https://doi.org/10.5281/zenodo.13851911)

## Context and Motivation

[A DIabatic NeverwOrld2](https://github.com/vopikamm/DINO) coupled with Python subgrid momentum forcing.

#### Variations
- **GZ21** : DINO coupled with [Guillaumin and Zanna, 2021](https://doi.org/10.1029/2021MS002534) ML model 

## Requirements

### Compilation

- NEMO version : [v4.2.1](https://forge.nemo-ocean.eu/nemo/nemo/-/releases/4.2.1) patched with [morays](https://github.com/morays-community/Patches-NEMO/tree/main/NEMO_v4.2.1) and local `CONFIG/my_src` sources.

- Code Compilation manager : none, use standard `makenemo` script


### Python

- Eophis version : [v1.1.0](https://github.com/alexis-barge/eophis/tree/v1.1.0)
- **GZ21** dependencies:
  ```bash
  cd DINO_Subgrid_Momentum.GZ21/INFERENCES/gz21_ocean_momentum
  pip install -e .
  ```


### Run

- NEMO Production Manager : none, use submission script `job.ksh` in `RUN`


### Post-Process

- No Post-Process libraries

- Plotting : Python script `plots_res.py` in `POSTPROCESS`

