# Rabbit model: settings reference

*2 November 2026, for the Pascal program on branch `rhd-immunity` of `rabbit/Pascal_program`.*

All inputs of the rabbit model in one place: the command line arguments of the Pascal program, the
demographic rates file, the RHD settings file, and the habitat and dispersal parameters that the
calibration estimates. **TODO** marks a cell we don't have enough information to fill in.

- **Default** is the value used when the setting is not given: the value in
  `data/rabbit/Rabbit_demography_values.txt` for the demographic rates, otherwise the default in
  the program code.
- **Range** is the range that makes sense biologically or that the calibration uses (its prior).
  Where only the technically valid range is known, that is given and marked as such.

**Contents**

- [Command line arguments](#command-line-arguments)
- [Demographic rates file](#demographic-rates-file)
- [RHD settings file](#rhd-settings-file)
- [Habitat and dispersal parameters (calibrated)](#habitat-and-dispersal-parameters-calibrated)
- [Fixed in the code](#fixed-in-the-code)
- [Known issues](#known-issues)

## Command line arguments

The program is called as
`Rabbit_x86_64-win64.exe <1> <2> ... <14>`; `run_simulation()` and `model_fn()` in
`rabbit/functions` build this call.

| # | Name | Meaning | Default | Range | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | `output_dir` | Folder for the output (`maps/`, RHD logs). Created if missing. | required | path | |
| 2 | `start_year` | First simulated year; the simulation starts in January. | required | year | The first year is spin‑up (the population starts at carrying capacity). |
| 3 | `end_year` | Last simulated year; the simulation runs to December. | required | ≥ `start_year` | |
| 4 | `paramname_rabbit` | Demographic rates file (see below). | required | path | |
| 5 | `mapname_rabbit` | Static habitat map (carrying capacity per cell), used when argument 6 is `0`. | required | path | The R code passes the K map file here as well; it is not used then. |
| 6 | `habitat_folder` | Carrying capacity per month: `0` = the static map of argument 5; a folder with one `<year>_<month>.txt` map per month; or one binary `K_maps.kbin` file with all months. | required | `0`, folder or file | The binary file is what `create_K_map_gaussian()` writes. Months after the last stored one reuse the last month. |
| 7 | `climate_folder` | Folder with `breeding_months_<year>.txt` and `consecutive_dry_months_<year>.txt` per year. | required | path | Written by `calculate_BM_cDM()`. |
| 8 | `create_all_month_maps` | `1` = write a population map for every month. | `0` | `0` or `1` | Census-month maps are always written (see [Fixed in the code](#fixed-in-the-code)). |
| 9 | `rabbit_start_file` | `0` = start with as many rabbits per cell as the carrying capacity of the first month; otherwise a map with the starting number of rabbits per cell. | required | `0` or path | Starting rabbits get a random age of 0–11 months. |
| 10 | `dens_opt` | Dispersal: preferred number of rabbits in the destination cell. | value in the demographic rates file (3) | 3–20 (calibration prior) | Overrides the file value. Before the fix on branch `rhd-immunity` it had no effect (see [Known issues](#known-issues)). |
| 11 | `lambda` | Dispersal: how strongly rabbits avoid cells far from `dens_opt`. | value in the file (0.1) | 0.2–0.5 (calibration prior) | As for argument 10. |
| 12 | `sigma` | Dispersal: how quickly the chance of moving falls with distance. | value in the file (2.5) | 2–4 (calibration prior) | As for argument 10. |
| 13 | `seed` | Random seed; the same seed and inputs give the same output. | `-1` (no fixed seed) | integer; `-1` = none | Needs arguments 10–12. |
| 14 | `rhd_settings` | RHD settings file (see below); `0` = none. | `0` | `0` or path | Needs arguments 10–13. Without it the disease runs in `schedule` mode with the settings of the demographic rates file. |

## Demographic rates file

`data/rabbit/Rabbit_demography_values.txt`, one `name value` pair per line. Ages are in months.
Rates are applied per cell per month, in this order: RHD, reproduction, survival, ageing; then
dispersal over the whole map. `Kdens` is the number of rabbits in a cell divided by its carrying
capacity that month.

| Name | Meaning | Unit | Default | Range | Notes |
| --- | --- | --- | --- | --- | --- |
| `max_age` | Rabbits of this age or older die. | months | 82 | TODO | |
| `young_age` | Below this age a rabbit is a juvenile: juvenile survival, and no reproduction. | months | 4 | TODO | |
| `adult_age` | From this age, reproduction gets the `r_second_effect`. | months | 6 | TODO | |
| `old_age` | From this age, reproduction gets the `r_later_effect` instead. | months | 9 | TODO | |
| `disp_age` | Rabbits disperse in the month they reach this age. | months | 4 | TODO | Also the reference for `RHD_min_age`. |
| `MeanLitSize` | Mean litter size. Litters are 1 + Poisson(`MeanLitSize` − 1): at least one kit, mean `MeanLitSize`, variance `MeanLitSize` − 1 (SD 1.58 at 3.5). | kits | 3.5 | about 3.5–3.9: 3.90 embryos per female in wild *O. c. algirus*, southern Portugal (Gonçalves et al. 2002); births are somewhat fewer than embryos. TODO: choose | Species‑wide 4–6 at the height of the breeding season, 3–4 at its start and end. |
| `MinLitSize`, `MaxLitSize` | Smallest and largest litter; draws outside are set to these limits. | kits | 1, 9 | species range 3–9 young | Before: `SdLitSize` (not in the file, so 0) limited every litter to exactly 4. `SdLitSize` is no longer used. |
| `r_int` | Reproduction: intercept (logit) of the monthly chance that a non‑pregnant female from `young_age` conceives, in a breeding month. | logit | −2 | TODO | Chance = logistic(`r_int` + age effect − `r_dens_effect` × `Kdens`). Pregnancy and lactation take one month each. |
| `r_dens_effect` | Reproduction: decrease with `Kdens`. | logit per unit `Kdens` | 3 | TODO | |
| `r_second_effect` | Reproduction: extra for females from `adult_age`. | logit | 1 | TODO | |
| `r_later_effect` | Reproduction: extra for females from `old_age` (replaces `r_second_effect`). | logit | 5 | TODO | With −2 + 5 = 3, conception chance is 0.95 at low density. |
| `MortP_at_month_old` | Share of kits that die in their first month (while with the mother). | probability | 0.5 | 0–1 (valid) | Surviving kits join the population at 1 month old. |
| `s_int` | Survival: intercept (logit) of the monthly survival chance. | logit | 8 | TODO | Survival = logistic(`s_int` [− `s_extra_juv`] − `s_dens_effect` × `Kdens`) × (1 − exp(−`s_food_effect` / dry months)). |
| `s_extra_juv` | Survival: lower for juveniles (below `young_age`). | logit | 3 | TODO | |
| `s_dens_effect` | Survival: decrease with `Kdens`. | logit per unit `Kdens` | 3 | TODO | |
| `s_food_effect` | Survival: effect of the number of consecutive dry months (food shortage). | – | 20 | TODO | Larger = less effect of drought. |
| `lambda` | Dispersal, see argument 11. | – | 0.1 | see argument 11 | Overridden by argument 11. |
| `dens_opt` | Dispersal, see argument 10. | rabbits per cell | 3 | see argument 10 | Overridden by argument 10. Read as a whole number. |
| `sigma` | Dispersal, see argument 12. | – | 2.5 | see argument 12 | Overridden by argument 12. |
| `RHDFreq_L`, `RHDFreq_U` | RHD `schedule` mode: each cell gets an outbreak every L–U months (drawn once per cell). | months | 24, 36 | TODO | Only used in `schedule` mode. |
| `RHDMort_L`, `RHDMort_U` | RHD `schedule` mode: share of rabbits older than `adult_age` killed per outbreak, drawn once per cell between L and U. | probability | 0.15, 0.25 | 0–1 (valid) | Only used in `schedule` mode. |
| `mapname_rabbit` | Optional: overrides argument 5. | path | not set | path | Read after the command line, so it wins over argument 5. |
| `climate_folder` | Optional: overrides argument 7. | path | not set | path | As above. |

## RHD settings file

Command line argument 14; written by `write_rhd_settings()` (`rabbit/functions/rhd_settings.R`).
One `name value` pair per line; empty lines and lines starting with `#` are skipped, and an unknown
name stops the program. The R defaults (`rhd_default_settings()`) are the same as the program's,
except `RHD_mode` (`immunity`), `RHD_spark` (0.002) and `RHD_spread` (0.2).

| Name | Meaning | Unit | Default (program) | Range | Notes |
| --- | --- | --- | --- | --- | --- |
| `RHD_mode` | `none` = no disease; `schedule` = the old fixed schedule (see `RHDFreq_*`, `RHDMort_*`); `immunity` = outbreaks driven by immunity (below). | – | `schedule` | `none`, `schedule`, `immunity` | `schedule` reproduces the old program exactly (same seed, same output), apart from the bug fix below. |
| `RHD_min_age` | Minimum age to be infected, at the time of the disease step (before the month's ageing). | months | 3 | 0 – `max_age` | 3 = susceptible in the month a rabbit turns 4 and disperses, so dispersers can carry the virus. Kits below this age are treated as protected (maternal antibodies, about 2 months). |
| `RHD_f_crit` | Susceptible share (non‑immune among rabbits of at least `RHD_min_age`) at which an exposed cell has a 50% chance of an outbreak. | share | 0.5 | 0–1 (valid); prior 0.2–0.9 | Calibrated. The main control of the outbreak interval per cell. |
| `RHD_f_slope` | Steepness of the outbreak chance around `RHD_f_crit`: chance = 1 / (1 + exp(−slope × (f − `RHD_f_crit`))). | – | 20 | TODO | Large = close to a hard threshold. |
| `RHD_spark` | Chance per occupied cell per month that the virus arrives from outside (background introduction). | probability per month | 0 (R default 0.002) | 0–1 (valid); prior 10⁻⁴ – 10⁻¹·⁵ | Calibrated. |
| `RHD_spread` | Chance per neighbouring cell with an outbreak last month that the virus reaches the cell (vectors, carcasses). | probability | 0 (R default 0.2) | 0–1 (valid); prior 0–1 | Calibrated. Needed for park‑wide waves: with spread by dispersal only, outbreaks die out after one or two steps. |
| `RHD_mortality` | Share of infected rabbits that die (RHDV1, and RHDV2 unless `RHD2_mortality` is set). | probability | 0.6 | 0–1 (valid); prior 0.3–0.9 | Calibrated against the documented declines (first wave about 55–75%, RHDV2 more than 80%). TODO: adult mortality per strain from the literature, if available. |
| `RHD2_mortality` | As `RHD_mortality`, for RHDV2. | probability | −1 (= use `RHD_mortality`) | −1 or 0–1 | Only if one value cannot reproduce both declines. |
| `RHD1_arrival_year`, `RHD1_arrival_month` | Arrival of RHDV1. Year 0 = before the simulation (disease present from the start). | year, month | 0, 1 | TODO (about 1988–1990; first Spanish cases June 1988, first wave in Doñana around 1990) | Before the arrival there is no disease and no immunity. |
| `RHD2_arrival_year`, `RHD2_arrival_month` | Arrival of RHDV2. Year 0 = before the simulation; 9999 = never. | year, month | 0, 1 | TODO (2011–2012) | At the arrival, RHDV1 immunity is kept only with chance `RHD2_cross_immunity`. |
| `RHD_seed_share` | Share of occupied cells where the virus is introduced at an arrival. | share | 0.05 | TODO | The alternative of a list of cells (first known locations) is not implemented yet. |
| `RHD2_cross_immunity` | Chance that RHDV1 immunity also protects against RHDV2. | probability | 0 | 0–1; TODO (partial, not quantified in the literature) | |
| `RHD_init_immune_lo`, `RHD_init_immune_hi` | For runs that start after an arrival: each cell starts with an immune share drawn between these values. | share | 0.2, 0.8 | TODO | Spreads cells over the outbreak cycle, so the run does not start with one park‑wide outbreak. |
| `RHD_log` | `1` = write `rhd_outbreaks.csv` and `rhd_monthly.csv` to the output folder (immunity mode). | – | 1 | 0 or 1 | |
| `RHDFreq_L`, `RHDFreq_U`, `RHDMort_L`, `RHDMort_U` | As in the demographic rates file; can also be set here. | | | | `schedule` mode only. |

## Habitat and dispersal parameters (calibrated)

Not read by the Pascal program directly: the habitat parameters set the carrying capacity maps
(`create_K_map_gaussian()`), and the dispersal ones are passed as arguments 10–12. Ranges are the
priors in `rabbit/Workflow_calibration.R`; estimates are in `rabbit/results/posterior_samples.csv`.

| Name | Meaning | Unit | Default | Range (prior) | Notes |
| --- | --- | --- | --- | --- | --- |
| `K_max` | Carrying capacity of a cell with ideal habitat. | rabbits per 500 m cell | – | 15–45 | Rounded to a whole number. K = `K_max` × weighted suitability + 1, and 0 in flooded cells. |
| `ndvi_opt`, `ndvi_sigma` | Optimum and width of the suitability curve (Gaussian) for the monthly mean NDVI. | NDVI | – | 0.1–0.9, 0.01–0.5 | |
| `ndvi_sd_opt`, `ndvi_sd_sigma` | As above, for the within‑cell SD of NDVI. | NDVI | – | 0.1–0.9, 0.01–0.5 | |
| `height_opt`, `height_sigma` | As above, for vegetation height. | TODO (probably m) | – | 0–2, 0.01–1 | |
| `ndvi_w`, `ndvi_sd_w`, `height_w` | Weights of the three suitabilities (normalised to sum to 1). | – | – | 0–1 each | |
| `dens_opt`, `R_lambda`, `R_sigma` | Dispersal, arguments 10–12. | | | 3–20, 0.2–0.5, 2–4 | The current posterior was estimated while these had no effect (see [Known issues](#known-issues)). |

## Fixed in the code

| What | Value | Where |
| --- | --- | --- |
| Dispersal range | up to 3 cells in each direction (7 × 7 cells, 1.5 km) | `disp_x`, `disp_y`, `disp_dist` in `general_define_units.pas` |
| Neighbours for `RHD_spread` | the 8 surrounding cells | `RHDStep` in `rabbit_vital_rates.pas` |
| Population maps written | months 3, 6 and 9 of every year, and every month of 2017, 2018, 2023 and 2024 | `Rabbit_calibration.lpr` |
| Map values below 0 (e.g. −9999 for the sea) | read as 0 (no habitat) | `ReadMap` in `general_functions.pas` |
| Start population | carrying capacity of the first month (or argument 9), random ages 0–11 months, half female | `Startpopulation_rabbit` |

## Known issues

| Issue | Effect | Status |
| --- | --- | --- |
| Command line dispersal values (arguments 10–12) were overwritten by the `lambda`, `dens_opt` and `sigma` in the demographic rates file. | The model always used 3, 0.1 and 2.5; the calibrated dispersal parameters had no effect (same output for very different values). | Fixed on branch `rhd-immunity`: command line values are applied after the file is read. Recalibration needed. |
| RHD `schedule` mode only set up cells with carrying capacity above 0 in the first month. | Other cells never had outbreaks. | Fixed on branch `rhd-immunity`. |
| `SdLitSize` was not in the demographic rates file, and litters were limited to mean ± 2 × `SdLitSize`. | Every litter had exactly 4 kits. | Fixed on branch `rhd-immunity`: litters are now a shifted Poisson limited to `MinLitSize`–`MaxLitSize` (1–9). |
| `model_fn()` returns the failure value when a transect's observed KAI does not vary (SD 0) in the calibration period. | Such runs are rejected even though that statistic is not used. | Open; only a problem for short calibration periods. |
