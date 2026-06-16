# treemmm-r

**R port of [TreeMMM](https://github.com/jamesyoung93/treemmm)**: tree-based Marketing Mix Modeling with SHAP attribution for customer-level panel data.

*Status: v0.3.1. Docs at [jamesyoung93.github.io/treemmm-r](https://jamesyoung93.github.io/treemmm-r/).*

This is the R companion to the Python TreeMMM package, at feature parity for R users who want to verify, extend, or run TreeMMM in their existing R analytics stack. The v0.3.x budget-simulation layer (`reallocate`, `reallocate_curve`) mirrors the Python API and, because it is RNG-free, reproduces the Python budget figures to floating-point tolerance. The original paper and Python implementation: https://github.com/jamesyoung93/treemmm

## Installation

```r
# install.packages("devtools")  # if not already installed
devtools::install_github("jamesyoung93/treemmm-r")
```

## Capability tour

The blocks below run top to bottom: step 1 builds `ds`, step 2 builds `config` and `result`, and the later blocks reuse them. The synthetic DGPs name their columns `customer_id` / `period` / `outcome`, so the tour reads roles from `ds$columns` rather than hard-coding names.

### 1. Generate a dataset with known ground truth

Six DGP generators each return a list with `$df` (the panel), `$columns` (the role mapping), and `$ground_truth` (the planted attribution shares and interactions every model is scored against).

```r
library(treemmm)

ds <- generate_pharma_dataset(n_customers = 500, n_periods = 24, random_state = 42)

head(ds$df)                              # one row per (customer, period)
ds$columns                                # id / time / outcome / promo / control
ds$ground_truth$attribution_shares        # the reference shares models must recover
ds$ground_truth$interactions              # the planted channel interactions
```

The other five generators follow the same shape:

```r
generate_cpg_dataset(n_customers = 200, n_periods = 36)
generate_saas_dataset(n_customers = 500, n_periods = 24)
generate_linear_dataset(n_customers = 500, n_periods = 24)   # Gaussian honesty test
generate_pharma_adstock_dataset(n_customers = 500, n_periods = 24)
generate_geo_panel_dataset(n_regions = 200, n_weeks = 52)    # note: region/week args
```

### 2. Fit the model

`treemmm_run()` runs the full pipeline: distribution detection, LightGBM with monotone constraints and a fixed-grid search, SHAP attribution, link-aware decomposition, and rolling-origin temporal CV.

```r
config <- run_config(
  columns = column_spec(
    customer_id  = ds$columns$customer_id,
    time_col     = ds$columns$time_col,
    outcome_col  = ds$columns$outcome_col,
    promo_vars   = ds$columns$promo_vars,
    control_vars = ds$columns$control_vars
  ),
  objective = "auto"   # auto-detects Poisson / Tweedie / Gamma / Gaussian
)

result <- treemmm_run(ds$df, config)

# Per-channel attribution shares (sums to 1, includes "_base")
sort(unlist(result$attribution_shares), decreasing = TRUE)

# Backtest accuracy per fold
result$fold_metrics
```

**Running on your own data:** replace `ds$df` with your panel and set the `column_spec()` fields to your column names. The package only needs a long-format `data.frame` with one row per (customer, period).

### 3. Discover channel interactions

The tree-to-GLMM hybrid mines candidate interactions from the fitted tree, then refits them into a smooth GLMM. The discovered pairs are returned alongside the refit model.

```r
hybrid <- fit_glmm_hybrid(ds$df, config, n_interactions = 3)
hybrid$discovered_interactions   # ranked (var1, var2) pairs found in the tree
```

### 4. Regime diagnostics

Check that the panel supports the attribution before trusting it.

```r
# Outcome-distribution detection on the raw outcome vector
diagnose_distribution(ds$df[[ds$columns$outcome_col]])$family

feat <- result$prepared_data$feature_cols
X <- as.data.frame(result$prepared_data$df[, feat, with = FALSE], check.names = FALSE)

# Are counterfactual rows inside the training support?
coverage_check(X_train = X, X_simulated = X)

# Cross-sectional vs temporal variation per feature
variation_decomposition(ds$df, unit_col = ds$columns$customer_id,
                        feature_cols = ds$columns$promo_vars)

# Effective observations per ensemble parameter
tree_ess_per_param(n_train = nrow(X), n_estimators = 300, max_depth = 6)

# Do SHAP signs agree with the monotone constraints?
shap_sign_audit(result$shap_result)
```

### 5. Baselines

Each baseline takes `(df, config)` and returns `$model`, `$attribution_shares`, `$formula`, and `$objective`. The oracle variants additionally take the planted interactions.

```r
naive  <- fit_glmm_naive(ds$df, config)
oracle <- fit_glmm_oracle(ds$df, config,
                          planted_interactions = ds$ground_truth$interactions)
sort(unlist(naive$attribution_shares), decreasing = TRUE)

# Distributional-GLM ablation (Poisson / Tweedie / Gamma likelihood)
fit_glmm_distributional(ds$df, config)

# Bayesian hierarchical baselines need brms + a Stan backend (optional, not run here):
# fit_bayesian_hier_naive(ds$df, config, n_chains = 2, n_iter = 1000)
# fit_bayesian_hier_oracle(ds$df, config, ds$ground_truth$interactions)
```

### 6. mROI response curves

Sweep a channel's spend and read off response curves, a marginal-ROI ranking, and a constrained budget optimizer. Per-customer levels stay inside the observed support.

```r
ch <- ds$columns$promo_vars

simulate_response(result, channel = ch[1])   # response curve for one channel
mroi_ranking(result, channels = ch)          # marginal-ROI ranking across channels
optimize_budget(result, channels = ch)       # coordinate-ascent allocation
mroi_benchmark(result, ds)                    # model mROI rank-correlation vs the DGP truth
```

### 7. Budget reallocation (v0.3.x)

Given a committed budget change, `reallocate()` water-fills the extra touches into customer-periods with headroom below a per-customer cap and predicts the incremental outcome; `reallocate_curve()` sweeps that across budget levels into a planner decision table. Figures are in model-outcome and touch units; layer a cost or revenue per touch in downstream.

```r
feat <- result$prepared_data$feature_cols
X <- as.data.frame(result$prepared_data$df[, feat, with = FALSE], check.names = FALSE)

# A single committed budget increase on one channel
plan <- reallocate(result, X, budget_delta_pct = 25,
                   channel = "rep_visits", cap_percentile = 95)
plan$predicted_incremental_outcome
plan$predicted_lift_pct
plan$diagnostics$unallocatable_fraction   # fraction of the plan blocked by the cap

# Sweep the decision across budget levels
curve <- reallocate_curve(result, X, budget_deltas = c(10, 25, 50, 100),
                          channel = "rep_visits", cap_percentile = 95)
curve$table                  # one row per level: added touches, lift, marginal return
curve$max_allocatable_delta  # largest level that fully lands inside support
```

`reallocate()` accepts `channels = c(...)` to spread across several channels, or neither `channel` nor `channels` to target every channel the model treats as promotional (inferred from its monotone constraints, matching Python's `_infer_channels`). The Python equivalent passes the bare fitted fold model as the first argument; the R version accepts the whole `pipeline_result` and pulls the predictor out of it.

## Verification

Attribution-share MAPE at full scale (n = 3000 customers × 36 periods, Python's `_promo_only_shares` renormalization, `min_share = 0.005` filter):

| DGP | Python (N=5 seeds) | R port (N=3 seeds) |
|---|---|---|
| Pharma (NegBin)   | 17.9% ± 0.2% | 16.6% ± 0.6% |
| CPG (Tweedie)     | 22.5% ± 0.3% | 25.6% ± 0.3% |
| SaaS (ZI-Gamma)   | 16.7% ± 0.2% | 18.4% ± 0.1% |
| Linear (Gaussian) |  0.4% ± 0.1% |  6.9% ± 0.6% |

Pharma reproduces within standard error. CPG and SaaS land 2 to 3pp wide of Python. The Linear gap is the largest: trees redistribute about 5% of mass from the dominant channel to weaker ones on each seed, which the fixed-grid LightGBM search in v0.2.1 does not tune away. Closing it needs Optuna-equivalent hyperparameter search; `mlr3tuning` integration is deferred to a future release.

Re-run the verification yourself with `Rscript inst/verify/benchmark_all_dgps.R` (about 6 min on a laptop).

The v0.3.x reallocation layer is verified differently: it is deterministic (water-fill arithmetic plus model predictions, no RNG), and R's `quantile(type = 7)` equals numpy's default `np.percentile`, so on identical inputs the R and Python implementations agree to floating-point tolerance. `tests/testthat/test-reallocate-parity.R` reads fixtures produced by the Python package and asserts the R outputs reproduce them to 1e-8.

## How this differs from the Python package

| Component | Python | R |
|---|---|---|
| GBT engine | LightGBM (Python bindings) | `lightgbm` R package |
| SHAP | `shap.TreeExplainer` | `predict(model, X, type = "contrib")` (LightGBM built-in) |
| Hyperparameter search | Optuna (TPE) | fixed grid for v0.2.1; `mlr3tuning` deferred |
| Mixed-effects baseline | `statsmodels.MixedLM` | `lme4::lmer` |
| Bayesian baseline | PyMC + nutpie | `brms` (Stan) |
| Interaction discovery | `discover_interactions()` standalone | surfaced through `fit_glmm_hybrid()` |
| Panel manipulation | pandas | `data.table` |
| Figures | matplotlib | `ggplot2` |
| `reallocate()` first argument | bare fitted fold model | the whole `pipeline_result` |

The DGP math is identical, and the reallocation arithmetic is identical to floating-point tolerance. See [`SPEC.md`](SPEC.md) for the formal specification both packages target.

## License

MIT (see [LICENSE](LICENSE)).

## Citation

If you use TreeMMM in academic work, please cite the preprint:

```bibtex
@article{young2026treemmm,
  title   = {TreeMMM: Tree-Based Marketing Mix Modeling with SHAP Attribution and Automatic Interaction Discovery},
  author  = {Young, James},
  journal = {arXiv preprint arXiv:ARXIV_ID},
  year    = {2026},
  note    = {Submitted to the International Journal of Forecasting.
             Python: \url{https://github.com/jamesyoung93/treemmm};
             R port: \url{https://github.com/jamesyoung93/treemmm-r}.}
}
```
