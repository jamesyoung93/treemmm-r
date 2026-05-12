# treemmm-r

**R port of [TreeMMM](https://github.com/jamesyoung93/treemmm)** —
tree-based Marketing Mix Modeling with SHAP attribution for
customer-level panel data.

*Status: v0.2.1 — feature complete. Docs at
[jamesyoung93.github.io/treemmm-r](https://jamesyoung93.github.io/treemmm-r/).*

This is the R companion to the Python TreeMMM package. Feature parity
for R users who want to verify, extend, or run TreeMMM in their existing
R analytics stack. The original paper and Python implementation:
<https://github.com/jamesyoung93/treemmm>

## Installation

``` r

# install.packages("devtools")  # if not already installed
devtools::install_github("jamesyoung93/treemmm-r")
```

## Quickstart

The DGP generators return a list with `$df`, `$columns`, and
`$ground_truth`. Use `ds$columns` directly when configuring the pipeline
so the column names always match the generated panel — the synthetic
DGPs use `customer_id` / `period` / `outcome` rather than
domain-specific names.

``` r

library(treemmm)

# Generate the pharma synthetic DGP
ds <- generate_pharma_dataset(
  n_customers  = 500,
  n_periods    = 24,
  random_state = 42
)

# Inspect what was generated
head(ds$df)
ds$columns        # column-role mapping
ds$ground_truth$attribution_shares   # the planted reference shares

# Configure the pipeline using ds$columns
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

# Run the pipeline (rolling-origin CV, LightGBM + SHAP, link-aware attribution)
result <- treemmm_run(ds$df, config)

# Per-channel attribution shares (sums to 1)
sort(unlist(result$attribution_shares), decreasing = TRUE)
```

**Running on your own data:** replace `ds$df` with your panel and set
the
[`column_spec()`](https://jamesyoung93.github.io/treemmm-r/reference/column_spec.md)
fields to your actual column names. The package only requires a
long-format `data.frame` with one row per (customer, period).

See
[`vignette("quickstart")`](https://jamesyoung93.github.io/treemmm-r/articles/quickstart.md),
[`vignette("benchmark")`](https://jamesyoung93.github.io/treemmm-r/articles/benchmark.md),
and
[`vignette("dgp_play")`](https://jamesyoung93.github.io/treemmm-r/articles/dgp_play.md)
for longer walk-throughs.

## Verification

Attribution-share MAPE at full scale (n=3000 customers × 36 periods,
Python’s `_promo_only_shares` renormalization, `min_share = 0.005`
filter):

| DGP               | Python (N=5 seeds) | R port (N=3 seeds) |
|-------------------|--------------------|--------------------|
| Pharma (NegBin)   | 17.9% ± 0.2%       | 16.6% ± 0.6%       |
| CPG (Tweedie)     | 22.5% ± 0.3%       | 25.6% ± 0.3%       |
| SaaS (ZI-Gamma)   | 16.7% ± 0.2%       | 18.4% ± 0.1%       |
| Linear (Gaussian) | 0.4% ± 0.1%        | 6.9% ± 0.6%        |

Pharma reproduces within standard error. CPG and SaaS land 2–3pp wide of
Python. The Linear gap is the largest: trees redistribute ~5% of mass
from the dominant channel to weaker ones on each seed, which the
fixed-grid LightGBM search in v0.2.1 doesn’t tune away. Closing it
requires Optuna-equivalent hyperparameter search; `mlr3tuning`
integration is deferred to a future release.

Re-run the verification yourself with
`Rscript inst/verify/benchmark_all_dgps.R` (~6 min on a laptop).

## How this differs from the Python package

| Component | Python | R |
|----|----|----|
| GBT engine | LightGBM (Python bindings) | `lightgbm` R package |
| SHAP | `shap.TreeExplainer` | `predict(model, X, type = "contrib")` (LightGBM built-in) |
| Hyperparameter search | Optuna (TPE) | fixed grid for v0.2.1; `mlr3tuning` deferred |
| Mixed-effects baseline | `statsmodels.MixedLM` | [`lme4::lmer`](https://rdrr.io/pkg/lme4/man/lmer.html) |
| Bayesian baseline | PyMC + nutpie | `brms` (Stan) |
| Panel manipulation | pandas | `data.table` |
| Figures | matplotlib | `ggplot2` |

The DGP math is identical — see
[`SPEC.md`](https://jamesyoung93.github.io/treemmm-r/SPEC.md) for the
formal specification both packages target.

## License

MIT (see [LICENSE](https://jamesyoung93.github.io/treemmm-r/LICENSE)).

## Citation

If you use TreeMMM in academic work, please cite the preprint:

``` bibtex
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
