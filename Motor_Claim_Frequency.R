# MOTOR INSURANCE CLAIM FREQUENCY ANALYSIS
# Base R only. Run in RGui using File > Source R code, or paste sections
# into the Console. Choose a project folder with File > Change dir first.
# Outputs and a reusable data cache are saved under getwd().
# Source: CASdatasets 1.2-0, freMTPL2freq.
# Documentation: https://dutangc.github.io/CASdatasets/reference/freMTPL.html

# 1. Load data: reuse your current session or a saved copy first.
dir.create("data", showWarnings = FALSE)
dir.create("outputs", showWarnings = FALSE)
cache <- file.path("data", "freMTPL2freq.rds")
if (!exists("freMTPL2freq")) {
  if (file.exists(cache)) {
    freMTPL2freq <- readRDS(cache)
  } else {
    # First-time fallback: approximately 236 MB download.
    options(timeout = max(300, getOption("timeout")))
    archive <- file.path(tempdir(), "CASdatasets.tar.gz")
    download.file("https://cas.uqam.ca/pub/src/contrib/CASdatasets_1.2-0.tar.gz",
                  destfile = archive, mode = "wb")
    untar(archive, exdir = tempdir())
    load(file.path(tempdir(), "CASdatasets", "data", "freMTPL2freq.rda"))
  }
}
if (!file.exists(cache)) saveRDS(freMTPL2freq, cache)

# 2. Data checks. Keep unusual observations; document them.
motor <- freMTPL2freq[c("IDpol", "ClaimNb", "Exposure", "DrivAge", "VehAge")]
print(summary(motor))
print(colSums(is.na(motor)))
stopifnot(!anyNA(motor), all(motor$Exposure > 0),
          all(motor$ClaimNb >= 0), all(motor$ClaimNb == floor(motor$ClaimNb)))
quality <- data.frame(
  DuplicateIDs = sum(duplicated(motor$IDpol)),
  ExposureAbove1 = sum(motor$Exposure > 1),
  ClaimsAbove4 = sum(motor$ClaimNb > 4),
  VehicleAgeAbove50 = sum(motor$VehAge > 50))
print(quality)

# 3. Frequency = total claims / total years of exposure.
annual_frequency <- sum(motor$ClaimNb) / sum(motor$Exposure)
portfolio <- data.frame(Policies = nrow(motor), Claims = sum(motor$ClaimNb),
  ExposureYears = sum(motor$Exposure), ClaimsPer100Years = 100 * annual_frequency)
print(portfolio)
motor$DriverGroup <- cut(motor$DrivAge, c(18, 25, 40, 60, Inf),
  right = FALSE, labels = c("18-24", "25-39", "40-59", "60+"))
motor$VehicleGroup <- cut(motor$VehAge, c(0, 5, 10, Inf),
  right = FALSE, labels = c("0-4", "5-9", "10+"))
stopifnot(!anyNA(motor$DriverGroup), !anyNA(motor$VehicleGroup))
age_summary <- aggregate(cbind(ClaimNb, Exposure) ~ DriverGroup, motor, sum)
age_summary$ClaimsPer100Years <- 100 * age_summary$ClaimNb / age_summary$Exposure
print(age_summary)
png("outputs/claim_frequency_by_age.png", width = 1000, height = 700)
barplot(age_summary$ClaimsPer100Years, names.arg = age_summary$DriverGroup,
  main = "Claim Frequency by Driver Age", xlab = "Driver age group",
  ylab = "Claims per 100 policy-years", col = "steelblue", ylim = c(0, 20))
abline(h = 100 * annual_frequency, col = "red", lty = 2, lwd = 2)
legend("topright", "Portfolio average", col = "red", lty = 2, lwd = 2, bty = "n")
dev.off()

# 4. Fixed reference groups and reproducible 80/20 random split.
motor$DriverGroup <- relevel(motor$DriverGroup, ref = "40-59")
motor$VehicleGroup <- relevel(motor$VehicleGroup, ref = "5-9")
set.seed(123)
train_rows <- sample(seq_len(nrow(motor)), floor(0.8 * nrow(motor)), replace = FALSE)
train <- motor[train_rows, ]
test <- motor[-train_rows, ]

# 5. Poisson GLM predicts claim COUNTS during each policy's exposure.
# log(expected count) = log(exposure) + intercept + group coefficients.
# The offset fixes the coefficient on log(exposure) at 1.
frequency_model <- glm(
  ClaimNb ~ DriverGroup + VehicleGroup + offset(log(Exposure)),
  family = poisson(link = "log"), data = train)
print(summary(frequency_model))
relativities <- data.frame(Term = names(coef(frequency_model)),
  ExponentiatedCoefficient = unname(exp(coef(frequency_model))))
print(relativities)
# Exponentiated intercept = reference annual rate; other terms = rate multipliers.

# 6. Evaluate once on the held-out test set.
test$PredictedClaims <- predict(frequency_model, newdata = test, type = "response")
validation_total <- data.frame(ActualClaims = sum(test$ClaimNb),
  PredictedClaims = sum(test$PredictedClaims),
  ActualToPredicted = sum(test$ClaimNb) / sum(test$PredictedClaims))
validation <- aggregate(cbind(ClaimNb, PredictedClaims) ~ DriverGroup, test, sum)
validation$ActualToPredicted <- validation$ClaimNb / validation$PredictedClaims
baseline_rate <- sum(train$ClaimNb) / sum(train$Exposure)
baseline_predictions <- test$Exposure * baseline_rate
poisson_family <- poisson()
baseline_deviance <- sum(poisson_family$dev.resids(test$ClaimNb, baseline_predictions, 1))
glm_deviance <- sum(poisson_family$dev.resids(test$ClaimNb, test$PredictedClaims, 1))
comparison <- data.frame(BaselineDeviance = baseline_deviance,
  GLMDeviance = glm_deviance,
  ImprovementPercent = 100 * (baseline_deviance - glm_deviance) / baseline_deviance)
dispersion <- sum(residuals(frequency_model, type = "pearson")^2) / df.residual(frequency_model)
print(validation_total)
print(validation)
print(comparison)
print(dispersion)
# Dispersion > 1 suggests extra variation beyond the Poisson assumption.
# Treat ordinary Poisson standard errors/p-values cautiously.
# A/P near 1 is aggregate calibration, NOT individual prediction accuracy.

# 7. Save small, reusable results.
write.csv(quality, "outputs/data_checks.csv", row.names = FALSE)
write.csv(portfolio, "outputs/portfolio.csv", row.names = FALSE)
write.csv(age_summary, "outputs/age_summary.csv", row.names = FALSE)
write.csv(relativities, "outputs/model_relativities.csv", row.names = FALSE)
write.csv(validation_total, "outputs/test_total.csv", row.names = FALSE)
write.csv(validation, "outputs/test_by_driver_age.csv", row.names = FALSE)
write.csv(comparison, "outputs/model_comparison.csv", row.names = FALSE)
write.csv(data.frame(PearsonDispersion = dispersion), "outputs/dispersion.csv", row.names = FALSE)
saveRDS(frequency_model, "outputs/frequency_model.rds")
capture.output(sessionInfo(), file = "outputs/session_info.txt")
cat("Finished. Results saved in:", normalizePath("outputs"), "\n")
