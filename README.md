# Motor Insurance Claim Frequency Analysis in R

A small actuarial learning project using base R to study motor insurance claim frequency. It uses one Poisson generalized linear model (GLM), two grouped predictors and an exposure adjustment. The aim is to explain claim frequency, interpret simple risk relationships and compare predicted with actual claims.

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

Driver-age groups are 18–24, 25–39, 40–59 and 60+; vehicle-age groups are 0–4, 5–9 and 10+. Reference groups are driver age **40–59** and vehicle age **5–9**. The exponentiated **intercept** is the annual claim frequency for a policy in both reference groups. The other exponentiated coefficients are frequency multipliers relative to their respective reference group, holding the other predictor constant.

## Results

The script was run end-to-end in Windows RGui. Figures below are rounded from that run.

| Test-set measure | Result |
|---|---:|
| Training policies | 542,392 |
| Test policies | 135,599 |
| Actual claims | 5,236 |
| Predicted claims | 5,305.44 |
| Actual / predicted | 0.9869 |

The model overpredicted the test-set total by approximately **1.33%** of actual claims. The actual-to-predicted ratio measures how closely the totals agree; it is not an individual prediction accuracy score.

### Driver-age calibration on the test set

| Driver age | Actual claims | Predicted claims | Actual / predicted |
|---|---:|---:|---:|
| 18–24 | 407 | 404.86 | 1.0053 |
| 25–39 | 1,566 | 1,591.15 | 0.9842 |
| 40–59 | 2,386 | 2,460.75 | 0.9696 |
| 60+ | 877 | 848.68 | 1.0334 |

Holding vehicle-age group constant, drivers aged 18–24 had approximately **2.21 times** the fitted frequency of drivers aged 40–59. This is an association in this dataset, not a causal conclusion.

### Additional checks

These support the main analysis; they do not add another fitted risk model.

| Check | Result | Plain-English meaning |
|---|---:|---|
| Constant-rate benchmark test deviance | 34,045.81 | Error score for one annual rate fitted on training data |
| GLM test deviance | 33,800.25 | Lower is better on the same test data |
| Reduction in test deviance | 0.72% | Only a modest improvement over the simple benchmark |
| Training Pearson dispersion | 1.80 | More variability than the Poisson variance assumption allows |

A close overall claim total does not by itself prove a useful model: even a constant-rate benchmark can produce close totals. That is why the error comparison is retained.

## Interview explanation

"I analysed a historical motor insurance dataset in R. I calculated claim frequency as claims divided by years insured, then fitted a simple Poisson GLM using driver-age and vehicle-age groups. I used an exposure offset so that a policy insured for half a year has half the expected claims of an otherwise identical policy insured for a full year. I compared predicted and actual claims on a held-out test set. The totals were close, but the improvement over a constant-rate benchmark was small, so I treat it as a learning model rather than a production pricing model."

The concepts to be comfortable explaining are:

- **Frequency:** 10 claims across 200 policy-years means 0.05 claims per policy-year, or 5 per 100 policy-years. Use total claims / total exposure, not an unweighted average of individual claim/exposure ratios.
- **Poisson model:** it models claim counts. Its conditional variance equals its conditional mean; this is an assumption checked approximately with dispersion.
- **Log link:** it keeps predicted counts positive. Group effects become multiplicative after exponentiating coefficients.
- **Exposure offset:** the coefficient of log(exposure) is fixed at 1. At an annual frequency of 0.08, a half-year policy has expected claims of 0.04.
- **Relativity:** a multiplier of 2.21 means 2.21 times the fitted frequency of the reference driver group, holding vehicle-age group constant. It does not mean a 221% probability of a claim.
- **Held-out validation:** fit on 80% of policies and check the remaining 20%. Actual / predicted near 1 shows close totals; it does not show that each policy prediction is accurate.

The script's download and saving commands are housekeeping. The actuarial analysis is the frequency calculation, exposure adjustment, model interpretation and validation. No severity model, premium calculation or additional machine-learning method is included.

## Limitations

- Pearson dispersion of **1.80** suggests extra variation beyond the Poisson variance assumption. Ordinary Poisson standard errors and p-values should be interpreted cautiously.
- Only two predictors and broad age bands are used; other relevant characteristics are omitted.
- The data are historical and from one portfolio. A random holdout does not demonstrate performance on future periods or other insurers.
- Unusual observations were retained and documented: 1,224 exposures above one year, eight claim counts above four and 97 vehicle ages above 50. No sensitivity analysis was performed.
- Claim severity, expenses and profit loadings are outside the scope, so this is not a complete premium model.

## Run the project

**Requirements:** R; no additional R packages are required. The first run may download an approximately 236 MB archive.

1. Download or clone this repository, then start a fresh R session so an edited in-memory dataset is not reused.
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

