# Rabbit model: settings reference

*6 November 2026, for the Pascal program on branch `named-model-settings` of `rabbit/Pascal_program`
(settings interface 2).*

All inputs of the rabbit model in one place: how settings are passed, the run settings, the
demographic rates, the RHD settings, and the habitat and dispersal parameters that the calibration
estimates. **TODO** marks a cell we don't have enough information to fill in.

- **Default** is the value used when the setting is not given: the value in
  `data/rabbit/Rabbit_demography_values.txt` for the demographic rates, otherwise the default in
  the program code.
- **Range** is the range that makes sense biologically or that the calibration uses (its prior).
  Where only the technically valid range is known, that is given and marked as such.

**Contents**

- [Passing settings](#passing-settings)
- [Run settings](#run-settings)
- [Demographic rates](#demographic-rates)
- [RHD settings](#rhd-settings)
- [Habitat and dispersal parameters (calibrated)](#habitat-and-dispersal-parameters-calibrated)
- [Deciding the default RHD mode](#deciding-the-default-rhd-mode)
- [Fixed in the code](#fixed-in-the-code)
- [Known issues](#known-issues)

## Passing settings

Every setting in this document has a name, and can be set in two places; **later wins**:

1. the **rates file**, `--rates_file=<file>` (required): `data/rabbit/Rabbit_demography_values.txt`,
   on top of the defaults in the program code (`general_define_units.pas`)
2. **`--name=value`** on the command line, to override the file for a run (calibrated parameters,
   scenarios, test cases, parameter uncertainty)

```
Rabbit_x86_64-win64.exe --output_dir=sim --start_year=2017 --end_year=2024
  --rates_file=Rabbit_demography_values.txt --habitat_folder=K_maps.kbin --climate_folder=clim
  --dens_opt=7 --lambda=0.3 --sigma=2.8 --seed=42 --RHD_mode=immunity --RHD_spread=0.3
```

- The rates file has one `name value` pair per line; empty lines, lines starting with `#` and
  anything after whitespace + `#` are skipped.
- **Unknown names stop the program** (with a suggestion for the closest name), in the file and on
  the command line. So do values that are not valid, values outside their valid range, a name given
  twice in the file or twice on the command line, and missing required settings.
- Numbers always use `.` as decimal mark, whatever the Windows language setting.
- `rates_file` can only be given on the command line.
- `--version` prints `settings_interface 2` (the R code checks this with `check_rabbit_model()`);
  `--help` lists all settings with their type, valid range and default.
- The program prints every setting given on the command line, with the value it replaced
  (`Setting RHD_spread = 0.3 (command line; was 0.2 from …)`), and writes all settings to
  `settings_used.txt` in `output_dir`. A run can be repeated with
  `--rates_file=settings_used.txt --output_dir=<new folder>`.
- In R, `rabbit_model_args()` (`rabbit/functions/rabbit_model_args.R`) turns a named list into these
  arguments, and `model_param_settings()` turns calibrated parameters (`R_lambda`, `log10_RHD_spark`,
  `RHDMort`, …) into setting names.

**Deprecated: positional arguments.** When the first argument does not start with `--`, the old
form of 9 to 14 positional arguments is still accepted, with a warning: 1 `output_dir`,
2 `start_year`, 3 `end_year`, 4 `rates_file`, 5 `mapname_rabbit`, 6 `habitat_folder`,
7 `climate_folder`, 8 `create_all_month_maps`, 9 `rabbit_start_file`, 10 `dens_opt`, 11 `lambda`,
12 `sigma`, 13 `seed`, 14 an RHD settings file (`0` = none; read after the rates file, only in this
form). They count as command line values, and give
output identical to the old program. Positional and named arguments cannot be mixed. This form will
be removed once the R code and the LifeWatch components use named arguments.

## Run settings

| Name | Meaning | Default | Valid | Notes |
| --- | --- | --- | --- | --- |
| `output_dir` | Folder for the output (`maps/`, RHD logs, `settings_used.txt`). Created if missing. | required | path | |
| `start_year` | First simulated year; the simulation starts in January. | required | year | The first year is spin‑up (the population starts at carrying capacity). |
| `end_year` | Last simulated year; the simulation runs to December. | required | ≥ `start_year` | |
| `habitat_folder` | Carrying capacity per month: a binary `K_maps.kbin` file with all months; a folder with one `<year>_<month>.txt` map per month; or `0` = the static map `mapname_rabbit`. | `0` | file, folder or `0` | The binary file is what `create_K_map_gaussian()` writes. Months after the last stored one reuse the last month. |
| `mapname_rabbit` | Static habitat map (carrying capacity per cell). | – | path | Required when `habitat_folder` is `0`. |
| `climate_folder` | Folder with `breeding_months_<year>.txt` and `consecutive_dry_months_<year>.txt` per year. | required | path | Written by `calculate_BM_cDM()`. |
| `create_all_month_maps` | `1` = write a population map for every month. | `0` | `0`/`1` | Census-month maps are always written (see [Fixed in the code](#fixed-in-the-code)). |
| `rabbit_start_file` | `0` = start with as many rabbits per cell as the carrying capacity of the first month; otherwise a map with the starting number of rabbits per cell. | `0` | `0` or path | Starting rabbits get a random age of 0–11 months. |
| `seed` | Random seed; the same seed and settings give the same output. | `-1` (none) | integer ≥ −1 | |

## Demographic rates

In the rates file (`data/rabbit/Rabbit_demography_values.txt`; all of these are required). Ages are in months.
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
| `MinLitSize`, `MaxLitSize` | Smallest and largest litter; draws outside are set to these limits. | kits | 1, 9 | species range 3–9 young | Optional (code default 1, 9). Before: `SdLitSize` (not in the file, so 0) limited every litter to exactly 4. `SdLitSize` no longer exists, so it is now an unknown name. |
| `r_int` | Reproduction: intercept (logit) of the monthly chance that a non‑pregnant female from `young_age` conceives, in a breeding month. | logit | −2 | TODO | Chance = logistic(`r_int` + age effect − `r_dens_effect` × `Kdens`). Pregnancy and lactation take one month each. |
| `r_dens_effect` | Reproduction: decrease with `Kdens`. | logit per unit `Kdens` | 3 | TODO | |
| `r_second_effect` | Reproduction: extra for females from `adult_age`. | logit | 1 | TODO | |
| `r_later_effect` | Reproduction: extra for females from `old_age` (replaces `r_second_effect`). | logit | 5 | TODO | With −2 + 5 = 3, conception chance is 0.95 at low density. |
| `MortP_at_month_old` | Share of kits that die in their first month (while with the mother). | probability | 0.5 | 0–1 (valid) | Surviving kits join the population at 1 month old. |
| `s_int` | Survival: intercept (logit) of the monthly survival chance. | logit | 8 | TODO | Survival = logistic(`s_int` [− `s_extra_juv`] − `s_dens_effect` × `Kdens`) × (1 − exp(−`s_food_effect` / dry months)). |
| `s_extra_juv` | Survival: lower for juveniles (below `young_age`). | logit | 3 | TODO | |
| `s_dens_effect` | Survival: decrease with `Kdens`. | logit per unit `Kdens` | 3 | TODO | |
| `s_food_effect` | Survival: effect of the number of consecutive dry months (food shortage). | – | 20 | TODO | Larger = less effect of drought. |
| `dens_opt` | Dispersal: preferred number of rabbits in the destination cell. | rabbits per cell | 3 | 3–20 (calibration prior) | Must be a whole number. The calibration passes it per run. Before the fix on branch `rhd-immunity` command line values had no effect (see [Known issues](#known-issues)). |
| `lambda` | Dispersal: how strongly rabbits avoid cells far from `dens_opt`. | – | 0.1 | 0.2–0.5 (calibration prior) | R calls it `R_lambda`. |
| `sigma` | Dispersal: how quickly the chance of moving falls with distance. | – | 2.5 | 2–4 (calibration prior) | R calls it `R_sigma`. |
| `RHDFreq_L`, `RHDFreq_U` | RHD `schedule` mode: each cell gets an outbreak every L–U months (drawn once per cell). | months | 24, 36 | TODO | Only used in `schedule` mode. |
| `RHDMort_L`, `RHDMort_U` | RHD `schedule` mode: share of rabbits older than `adult_age` killed per outbreak, drawn once per cell between L and U. | probability | 0.15, 0.25 | 0–1 (valid); calibration prior 0.1–0.9 | Only used in `schedule` mode. The calibration in schedule mode estimates one value, `RHDMort`, for both. |

## RHD settings

In the rates file (with `RHD_mode schedule` until the [comparison](#deciding-the-default-rhd-mode)),
overridden per run as `--name=value`. The R defaults (`rhd_default_settings()`,
`rabbit/functions/rhd_settings.R`) are the same as the program's, except `RHD_mode` (`immunity`),
`RHD_spark` (0.002) and `RHD_spread` (0.2); the R code passes them as `--name=value`.

**Arrival dates: a manual first outbreak.** With an arrival year of 0 (default) the strain is present
from the start: each cell starts with an immune share between `RHD_init_immune_lo` and `_hi`, so the
population is already mid-cycle. With an arrival date after the start (e.g. `RHD2_arrival_year 2019`,
`RHD2_arrival_month 4`) there is no disease and no immunity until then; in that month the virus
reaches `RHD_seed_share` of the occupied cells, and from then on the normal immunity process runs.
An arrival year up to `start_year` (date not after the start) also means present from the start.
**Setting only `RHD1_arrival_year` while `RHD2_arrival_year` is 0 has no effect**: RHDV2 is then
present from the start (`SetupRHD`, `rabbit_population_dynamics.pas`). Set `RHD2_arrival_year` too
(its arrival year, or 9999 = never). The program warns about these cases.

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
(`create_K_map_gaussian()`), and the dispersal ones are passed as `--dens_opt`, `--lambda` and
`--sigma`. Ranges are the
priors in `rabbit/Workflow_calibration.R`; estimates are in `rabbit/results/posterior_samples.csv`.

| Name | Meaning | Unit | Default | Range (prior) | Notes |
| --- | --- | --- | --- | --- | --- |
| `K_max` | Carrying capacity of a cell with ideal habitat. | rabbits per 500 m cell | – | 15–45 | Rounded to a whole number. K = `K_max` × weighted suitability + 1, and 0 in flooded cells. |
| `ndvi_opt`, `ndvi_sigma` | Optimum and width of the suitability curve (Gaussian) for the monthly mean NDVI. | NDVI | – | 0.1–0.9, 0.01–0.5 | |
| `ndvi_sd_opt`, `ndvi_sd_sigma` | As above, for the within‑cell SD of NDVI. | NDVI | – | 0.1–0.9, 0.01–0.5 | |
| `height_opt`, `height_sigma` | As above, for vegetation height. | TODO (probably m) | – | 0–2, 0.01–1 | |
| `ndvi_w`, `ndvi_sd_w`, `height_w` | Weights of the three suitabilities (normalised to sum to 1). | – | – | 0–1 each | |
| `dens_opt`, `R_lambda`, `R_sigma` | Dispersal settings `dens_opt`, `lambda`, `sigma`. | | | 3–20, 0.2–0.5, 2–4 | The current posterior was estimated while these had no effect (see [Known issues](#known-issues)). |
| `RHD_f_crit`, `log10_RHD_spark`, `RHD_spread`, `RHD_mortality` | RHD settings, calibrated in `immunity` mode (`log10_RHD_spark` on the log10 scale). | | | 0.2–0.9, −4 to −1.5, 0–1, 0.3–0.9 | |
| `RHDMort` | Calibrated in `schedule` mode: sets `RHDMort_L` = `RHDMort_U`. | probability | | 0.1–0.9 | |

## Deciding the default RHD mode

`RHD_mode` stays explicit (`schedule`) in the rates file until the three modes are compared. Make
`immunity` the default only if it fits the observed KAI better than `schedule` (and `none`).

- **Same setup for every mode:** the same censuses and period (2017–2024), spin-up, drivers, priors
  of the 13 shared parameters, `nb_simul` (300), `p_acc_min` (0.05) and seeds. Calibrate on the two
  shared KAI statistics only (median r and median r of the changes over the transects): calibration
  component `rhdMode = none / schedule / immunity` with `rhdStatistic = FALSE`. Schedule calibrates
  its mortality (`RHDMort`, prior 0.1–0.9) with the 24–36 month interval of the rates file;
  immunity calibrates its 4 settings.
- **Not the final ABC tolerance:** each run scales its distances by its own first sample, so they
  cannot be compared between runs.
- **Posterior predictive fit:** 200 parameter sets per posterior (by weight) × 3 fixed seeds, the
  same seeds for every mode; compare median r, median r of changes and scaled RMSE, with bootstrap
  95 % intervals of the differences.
- **Held-out year** (immunity has 4 extra parameters, so it could fit better by overfitting):
  calibrate to 2023, predict 2024; score the scaled error, the sign of the change 2023 → 2024 per
  transect, and the correlation across transects. Weak with one census year; say so.
- **Demographic noise:** 50 seeds at the posterior mean of each mode; a difference between modes
  counts only if it is larger than this spread.
- **Decision:** `immunity` becomes the default if it is better than `schedule` in-sample (interval
  of the difference excludes 0) and not worse on the held-out year. Otherwise `schedule` stays.
  Then change the default in the code, both rates files and `rhd_default_settings()` together, and
  record the result here.

`rabbit/compare_rhd_modes.R` runs this comparison.

## Fixed in the code

| What | Value | Where |
| --- | --- | --- |
| Dispersal range | up to 3 cells in each direction (7 × 7 cells, 1.5 km) | `disp_x`, `disp_y`, `disp_dist` in `general_define_units.pas` |
| Neighbours for `RHD_spread` | the 8 surrounding cells | `RHDStep` in `rabbit_vital_rates.pas` |
| Population maps written | months 3, 6 and 9 of every year, and every month of 2017, 2018, 2023 and 2024 | `Rabbit_calibration.lpr` |
| Map values below 0 (e.g. −9999 for the sea) | read as 0 (no habitat) | `ReadMap` in `general_functions.pas` |
| Start population | carrying capacity of the first month (or `rabbit_start_file`), random ages 0–11 months, half female | `Startpopulation_rabbit` |

## Known issues

| Issue | Effect | Status |
| --- | --- | --- |
| Command line dispersal values (arguments 10–12) were overwritten by the `lambda`, `dens_opt` and `sigma` in the demographic rates file. | The model always used 3, 0.1 and 2.5; the calibrated dispersal parameters had no effect (same output for very different values). | Fixed on branch `rhd-immunity`: command line values are applied after the file is read. Recalibration needed. |
| RHD `schedule` mode only set up cells with carrying capacity above 0 in the first month. | Other cells never had outbreaks. | Fixed on branch `rhd-immunity`. |
| `SdLitSize` was not in the demographic rates file, and litters were limited to mean ± 2 × `SdLitSize`. | Every litter had exactly 4 kits. | Fixed on branch `rhd-immunity`: litters are now a shifted Poisson limited to `MinLitSize`–`MaxLitSize` (1–9). |
| `model_fn()` returns the failure value when a transect's observed KAI does not vary (SD 0) in the calibration period. | Such runs are rejected even though that statistic is not used. | Open; only a problem for short calibration periods. |
| The rates file was read with `StrToFloat`, which uses the Windows decimal mark. | On a Windows with a decimal comma (e.g. Spanish), `0.15` could not be read. | Fixed on branch `named-model-settings`: all numbers are read with `Val` (always `.`). |
| The rates file reader ignored unknown and misspelled names, and rates missing from the file were silently 0. | A typing error went unnoticed. | Fixed on branch `named-model-settings`: unknown names and missing required settings stop the program. |
| On an error the console version waited for a key press (`Readln` in `ShowErrorAndExit`). | A run started from R could hang until its timeout. | Fixed on branch `named-model-settings`: the error goes to stderr and the program exits with code 1. |
