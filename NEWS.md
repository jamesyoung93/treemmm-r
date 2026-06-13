# treemmm 0.3.0 (2026-06-13)

## New features

* **`reallocate()`** plans a cap-bounded committed budget increase.
  Given a fitted pipeline and a percent budget change, it grows each
  target channel's total touches by that percent and water-fills the
  increment across panel cells with headroom below a per-customer cap
  (the `cap_percentile` of observed positive touches, default 95). Cells
  at or above the cap receive a zero increment and are never reduced, so
  every per-customer counterfactual stays inside the observed support.
  Returns the per-row landing plan, the aggregate roll-up, the predicted
  incremental outcome and lift, and cap-binding diagnostics. Mirrors
  `treemmm.mroi.reallocate` in the Python package.

# treemmm 0.2.1 (2026-05-12)

First feature-complete release of the R port. Mirrors the Python
TreeMMM 0.2.1 release at https://github.com/jamesyoung93/treemmm.

## Highlights

* **End-to-end pipeline** (`treemmm_run`): LightGBM with monotone
  constraints, fixed-grid hyperparameter search, SHAP attribution via
  `predict(..., type = "contrib")`, link-function-aware decomposer,
  rolling-origin temporal CV, outcome-distribution detection.
* **Six synthetic DGPs**: pharma (NegBin), CPG (Tweedie), SaaS
  (ZI-Gamma), linear (Gaussian honesty test), pharma+adstock, geo-panel.
  All parameterizable; `generate_*_dataset()` returns a panel, role
  mapping, and ground-truth attribution shares.
* **Six baselines**: GLMM-Naive/Oracle (`lme4`), GLMMDist-Naive/Oracle
  (base `glm`), Bayesian PyMC-Hier-Naive/Oracle (`brms`, optional).
* **mROI module**: `simulate_response`, `mroi_ranking`,
  `mroi_benchmark`, `optimize_budget`.
* **Diagnostics**: `coverage_check`, `variation_decomposition`,
  `tree_ess_per_param`, `shap_sign_audit`, `diagnose_distribution`.
* **Tree-to-GLMM hybrid** (`fit_glmm_hybrid`): tree-discovered
  interactions refit into a GLMM.
* **Three vignettes**: quickstart, benchmark, dgp_play.
* **pkgdown** configured; CI builds and deploys the site to gh-pages.
* **Cross-language verification** test (`test-verification.R`)
  asserts R-port pharma TreeMMM produces sensible attribution at a
  moderate scale and that the linear honesty test holds.

## Reproducibility caveat across R and Python

R's Mersenne Twister and Python's PCG64 produce different samples at
the same numeric seed. The DGP coefficients and structural form match
exactly between implementations; planted reference attribution shares
converge to the Python ones within Monte Carlo error (< 0.5 pp at
headline scale).

See `SPEC.md` in the repository for the formal specification both
implementations target.

## Library mapping (Python → R)

| Python | R |
|---|---|
| LightGBM | `lightgbm` |
| `shap.TreeExplainer` | `predict(..., type = "contrib")` |
| Optuna | fixed grid (Bayesian opt deferred) |
| `statsmodels.MixedLM` | `lme4::lmer` |
| PyMC | `brms` (optional, Stan backend) |
| pandas | `data.table` |
| matplotlib | `ggplot2` |

## Installation

```r
devtools::install_github("jamesyoung93/treemmm-r")
library(treemmm)
```

## Phase log (development history)

* **Phase 1** (scaffold) — package skeleton and CI (2026-05-11).
* **Phase 2** (DGP port) — all six DGPs implemented (2026-05-12).
* **Phase 3** (core pipeline) — `treemmm_run()` end-to-end (2026-05-12).
* **Phase 4** (baselines) — GLMM / GLMMDist / Bayesian (2026-05-12).
* **Phase 5** (mROI + diagnostics + hybrid) (2026-05-12).
* **Phase 6** (vignettes + pkgdown + roxygen CI) (2026-05-12).
* **Phase 7** (release prep, this release) (2026-05-12).
