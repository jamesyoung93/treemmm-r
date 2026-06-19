# treemmm-r

**R port of [TreeMMM](https://github.com/jamesyoung93/treemmm)**: tree-based Marketing Mix Modeling with SHAP attribution for customer-level panel data.

Status: v0.3.1. Docs: [jamesyoung93.github.io/treemmm-r](https://jamesyoung93.github.io/treemmm-r/).

This is the R companion to the Python TreeMMM package, at feature parity for R users who want to verify, extend, or run TreeMMM in an R analytics stack. The v0.3.x budget-simulation layer (`reallocate`, `reallocate_curve`) mirrors the Python API and, because it is RNG-free, reproduces the Python budget figures to floating-point tolerance. The original paper and Python implementation are at <https://github.com/jamesyoung93/treemmm>.

## Installation

Install from GitHub with dependencies:

```r
install.packages("devtools", repos = "https://cloud.r-project.org")
devtools::install_github("jamesyoung93/treemmm-r", dependencies = TRUE)
```

If you are working from a local clone, install the checked-out copy:

```r
install.packages("devtools", repos = "https://cloud.r-project.org")
devtools::install(".", dependencies = TRUE)
```

## Run the supporting demo

The package installs a pharma quickstart script that runs an end-to-end synthetic panel demo and prints the checks that matter for the manuscript story:

- recovery of the dominant planted promotional channels
- automatic discovery of planted channel interactions
- mROI ranking across channels
- a cap-bounded incremental budget reallocation plan
- support diagnostics for the rows being simulated

Run it from any R session after installation:

```r
demo_script <- system.file("examples", "quickstart_pharma.R", package = "treemmm")
source(demo_script)
```

Or run the same script from a cloned repository:

```sh
Rscript inst/examples/quickstart_pharma.R
```

The default demo uses 500 customers x 24 periods with seed 42 and takes roughly one to two minutes on a typical laptop. To make a faster smoke test, lower the demo size.

macOS/Linux:

```sh
TREEMMM_DEMO_CUSTOMERS=200 TREEMMM_DEMO_PERIODS=18 Rscript inst/examples/quickstart_pharma.R
```

PowerShell:

```powershell
$env:TREEMMM_DEMO_CUSTOMERS = "200"
$env:TREEMMM_DEMO_PERIODS = "18"
Rscript inst/examples/quickstart_pharma.R
```

Expected highlights from the default seed are:

- the model recovers the planted top three promo channels: `rep_visits`, `samples`, and `dtc_advertising`
- interaction discovery recovers two of the three planted interaction pairs
- mROI ranks `rep_visits`, `samples`, and `dtc_advertising` highest
- a +25 percent `rep_visits` reallocation produces a positive predicted lift with no blocked allocation in the default sweep
- the support diagnostic reports zero extrapolation for the training-row check

This quickstart is a capability and evidence tour. Use the full verification script below for headline attribution-accuracy claims.

## Full verification

Attribution-share MAPE at full scale uses 3,000 customers x 36 periods, Python's `_promo_only_shares` renormalization, and a `min_share = 0.005` filter:

| DGP | Python (N=5 seeds) | R port (N=3 seeds) |
|---|---:|---:|
| Pharma (NegBin) | 17.9% +/- 0.2% | 16.6% +/- 0.6% |
| CPG (Tweedie) | 22.5% +/- 0.3% | 25.6% +/- 0.3% |
| SaaS (ZI-Gamma) | 16.7% +/- 0.2% | 18.4% +/- 0.1% |
| Linear (Gaussian) | 0.4% +/- 0.1% | 6.9% +/- 0.6% |

Pharma reproduces within standard error. CPG and SaaS land 2 to 3 percentage points wide of Python. The Linear gap is the largest: trees redistribute about 5 percent of mass from the dominant channel to weaker ones on each seed, which the fixed-grid LightGBM search in v0.3.1 does not tune away. Closing it needs Optuna-equivalent hyperparameter search; `mlr3tuning` integration is deferred to a future release.

Run the full verification from a cloned repository:

```sh
Rscript inst/verify/benchmark_all_dgps.R
```

The script saves `inst/verify/benchmark_results.rds` by default. Override the output path with either form:

```sh
Rscript inst/verify/benchmark_all_dgps.R --output=output/benchmark_results.rds
TREEMMM_BENCHMARK_RESULTS=output/benchmark_results.rds Rscript inst/verify/benchmark_all_dgps.R
```

PowerShell:

```powershell
Rscript inst/verify/benchmark_all_dgps.R --output=output/benchmark_results.rds
$env:TREEMMM_BENCHMARK_RESULTS = "output/benchmark_results.rds"
Rscript inst/verify/benchmark_all_dgps.R
```

The full verification is compute-heavy. On the Windows/R 4.3.3 audit machine it took about 20 minutes; faster laptops may finish sooner.

## Capability tour

The quickstart script is the easiest reproducible tour. The same workflow can be run interactively with the public API:

```r
library(treemmm)

ds <- generate_pharma_dataset(n_customers = 500, n_periods = 24, random_state = 42)

config <- run_config(
  columns = column_spec(
    customer_id  = ds$columns$customer_id,
    time_col     = ds$columns$time_col,
    outcome_col  = ds$columns$outcome_col,
    promo_vars   = ds$columns$promo_vars,
    control_vars = ds$columns$control_vars
  ),
  objective = "auto"
)

result <- treemmm_run(ds$df, config)
sort(unlist(result$attribution_shares), decreasing = TRUE)
result$fold_metrics
```

Interaction discovery:

```r
hybrid <- fit_glmm_hybrid(ds$df, config, n_interactions = 3)
hybrid$discovered_interactions
```

Diagnostics:

```r
feat <- result$prepared_data$feature_cols
X <- as.data.frame(result$prepared_data$df[, feat, with = FALSE], check.names = FALSE)

diagnose_distribution(ds$df[[ds$columns$outcome_col]])$family
coverage_check(X_train = X, X_simulated = X)
variation_decomposition(ds$df, unit_col = ds$columns$customer_id,
                        feature_cols = ds$columns$promo_vars)
shap_sign_audit(result$shap_result)
```

mROI and reallocation:

```r
ch <- ds$columns$promo_vars

simulate_response(result, channel = ch[1])
mroi_ranking(result, channels = ch)
optimize_budget(result, channels = ch)
mroi_benchmark(result, ds)

plan <- reallocate(result, X, budget_delta_pct = 25,
                   channel = "rep_visits", cap_percentile = 95)
plan$predicted_incremental_outcome
plan$predicted_lift_pct
plan$diagnostics$unallocatable_fraction

curve <- reallocate_curve(result, X, budget_deltas = c(10, 25, 50, 100),
                          channel = "rep_visits", cap_percentile = 95)
curve$table
curve$max_allocatable_delta
```

Baselines:

```r
naive <- fit_glmm_naive(ds$df, config)
oracle <- fit_glmm_oracle(ds$df, config,
                          planted_interactions = ds$ground_truth$interactions)
fit_glmm_distributional(ds$df, config)
```

Bayesian hierarchical baselines require `brms` plus a Stan backend and are not run in the quickstart:

```r
# fit_bayesian_hier_naive(ds$df, config, n_chains = 2, n_iter = 1000)
# fit_bayesian_hier_oracle(ds$df, config, ds$ground_truth$interactions)
```

## How this differs from the Python package

| Component | Python | R |
|---|---|---|
| GBT engine | LightGBM Python bindings | `lightgbm` R package |
| SHAP | `shap.TreeExplainer` | `predict(model, X, type = "contrib")` |
| Hyperparameter search | Optuna (TPE) | fixed grid for v0.3.1; `mlr3tuning` deferred |
| Mixed-effects baseline | `statsmodels.MixedLM` | `lme4::lmer` |
| Bayesian baseline | PyMC + nutpie | `brms` (Stan) |
| Interaction discovery | `discover_interactions()` standalone | surfaced through `fit_glmm_hybrid()` |
| Panel manipulation | pandas | `data.table` |
| Figures | matplotlib | `ggplot2` |
| `reallocate()` first argument | bare fitted fold model | whole `pipeline_result` |

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
