# Motor Insurance Claim Frequency Analysis in R

A personal actuarial project using a Poisson generalized linear model (GLM) to estimate claim frequency from driver age, vehicle age and time insured. The project uses base R and focuses on interpretable risk factors, exposure adjustment and held-out validation.

## Data

The `freMTPL2freq` dataset from **CASdatasets 1.2-0** contains historical French motor third-party liability insurance records.

- **677,991 policies**, **26,444 claims** and approximately **358,482.8 policy-years** of exposure.
- Overall frequency: **7.38 claims per 100 policy-years**.
- Selected fields: policy ID, claim count, exposure, driver age and vehicle age.
- No missing values in these fields or duplicate policy IDs.

[Dataset documentation](https://dutangc.github.io/CASdatasets/reference/freMTPL.html) · [CASdatasets source](https://cas.uqam.ca/)

The original dataset is not redistributed in this repository. The script downloads the official source archive when neither an in-memory dataset nor a local cache is available.

## Method

1. Check missing values, duplicate IDs and unusual observations.
2. Calculate exposure-weighted frequency overall and by driver-age group.
3. Split policies randomly into 80% training and 20% test sets using seed 123.
4. Fit a Poisson GLM with a log link and `offset(log(Exposure))`.
5. Compare test predictions with actual claims and a constant-rate benchmark fitted on training data.
6. Check training Pearson dispersion and save results.

```r
frequency_model <- glm(
  ClaimNb ~ DriverGroup + VehicleGroup + offset(log(Exposure)),
  family = poisson(link = "log"),
  data = train
)
```

The offset adjusts expected claim counts for the time each policy was insured. At the same risk characteristics, doubling exposure doubles expected claims.

Driver-age groups are 18–24, 25–39, 40–59 and 60+; vehicle-age groups are 0–4, 5–9 and 10+. Reference groups are driver age **40–59** and vehicle age **5–9**. Exponentiated coefficients give frequency multipliers relative to those reference groups.

## Results

The script was run end-to-end in Windows RGui. Figures below are rounded from that run.

| Test-set measure | Result |
|---|---:|
| Training policies | 542,392 |
| Test policies | 135,599 |
| Actual claims | 5,236 |
| Predicted claims | 5,305.44 |
| Actual / predicted | 0.9869 |
| Constant-rate benchmark Poisson deviance | 34,045.81 |
| GLM Poisson deviance | 33,800.25 |
| Reduction in test deviance | 0.72% |
| Training Pearson dispersion | 1.80 |

The model overpredicted the test-set total by approximately **1.33%** of actual claims. The **0.72% reduction in deviance** is a modest improvement over predicting one annual rate for all policies. The actual-to-predicted ratio measures aggregate calibration; it is not a classification accuracy score.

### Driver-age calibration on the test set

| Driver age | Actual claims | Predicted claims | Actual / predicted |
|---|---:|---:|---:|
| 18–24 | 407 | 404.86 | 1.0053 |
| 25–39 | 1,566 | 1,591.15 | 0.9842 |
| 40–59 | 2,386 | 2,460.75 | 0.9696 |
| 60+ | 877 | 848.68 | 1.0334 |

Holding vehicle-age group constant, drivers aged 18–24 had approximately **2.21 times** the fitted frequency of drivers aged 40–59. This is an association in this dataset, not a causal conclusion.

## Limitations

- Pearson dispersion of **1.80** suggests extra variation beyond the Poisson variance assumption. Ordinary Poisson standard errors and p-values should be interpreted cautiously.
- Only two predictors and broad age bands are used; other relevant characteristics are omitted.
- The data are historical and from one portfolio. A random holdout does not demonstrate performance on future periods or other insurers.
- Unusual observations were retained and documented: 1,224 exposures above one year, eight claim counts above four and 97 vehicle ages above 50. No sensitivity analysis was performed.
- Claim severity, expenses and profit loadings are outside the scope, so this is not a complete premium model.

## Run the project

**Requirements:** R; no additional R packages are required. The first run may download an approximately 236 MB archive.

1. Download or clone this repository.
2. Set R's working directory to the repository folder. In Windows RGui, use **File > Change dir**.
3. Run:

```r
source("Motor_Claim_Frequency.R")
```

The script creates `data/` for its reusable dataset cache and `outputs/` for the chart, summary tables, saved model and session information. Paths are relative to the working directory, so choose the repository folder before running.

Outputs include:

- `claim_frequency_by_age.png`
- `data_checks.csv`, `portfolio.csv` and `age_summary.csv`
- `model_relativities.csv`
- `test_total.csv` and `test_by_driver_age.csv`
- `model_comparison.csv` and `dispersion.csv`
- `frequency_model.rds` and `session_info.txt`

The dataset cache and generated outputs are excluded from version control. Run the script to generate them locally. Exact numerical reproduction can depend on the R version and random-sampling settings; `session_info.txt` records the environment used for each run.
