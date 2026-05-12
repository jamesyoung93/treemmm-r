# Roadmap

Seven-phase implementation plan for the R port of TreeMMM. The Python package (https://github.com/jamesyoung93/treemmm) is the source of truth for behavior; the R port aims for feature parity with idiomatic R conventions.

## Phases

| Phase | Scope | Status |
|---|---|---|
| 1. Scaffold | `DESCRIPTION`, `NAMESPACE`, `R/` stubs, `tests/`, CI, `README`, `ROADMAP`, `SPEC`. Empty package passes `R CMD check`. | **done** (v0.2.1.9000) |
| 2. DGP port | Port all four DGPs (pharma, cpg, saas, linear) plus the two specialty DGPs (pharma_adstock, geo_panel) to R. With seed = 42 they produce panels structurally equivalent to the Python ones (R uses Mersenne Twister, so values differ; reference attribution shares converge within Monte Carlo error). | **done** (v0.2.2.9000) |
| 3. Core pipeline | `pipeline.R`, `models.R` (LightGBM with monotone constraints + fixed grid), `decomposer.R` (link-aware), `shap.R` (LightGBM `predcontrib`), `temporal.R` (rolling-origin CV), `data_handler.R` (distribution detection). End-to-end `treemmm_run()` on a panel. | **done** (v0.3.0.9000) |
| 4. Baselines | GLMM-Naive/Oracle (`lme4`), PyMC-Hier-Naive/Oracle (`brms`), GLMMDist (base `glm`). | pending |
| 5. mROI + diagnostics | `mroi.R` (response curves, constrained reallocation), `diagnostics.R` (regime check, SHAP sign audit). | pending |
| 6. Documentation | roxygen2 docs on every exported function, three vignettes (`quickstart`, `benchmark`, `dgp_play`), pkgdown site. | pending |
| 7. Release prep | Cross-language verification test, `NEWS.md` polishing, optional CRAN preparation. | pending |

## Cross-language verification (Phase 7)

A `tests/testthat/test-verification.R` will:

1. Pull `paper/results/benchmark_multiseed_raw.csv` from the Python repo via the GitHub Actions checkout.
2. Run the R-side pharma benchmark on seeds 0–4.
3. Assert the R-side mean MAPE is within the Python multi-seed SE band (Python: 17.9% ± 0.2% on pharma).

When that test passes, the headline result is reproducible across languages.

## Library mapping (Python → R)

| Python | R |
|---|---|
| LightGBM | `lightgbm` |
| XGBoost | `xgboost` |
| SHAP TreeExplainer | `treeshap` |
| Optuna | fixed grid for v0.2.1; `mlr3tuning` deferred |
| `statsmodels.MixedLM` | `lme4::lmer` |
| PyMC | `brms` (Stan via `cmdstanr` backend) |
| pandas | `data.table` |
| matplotlib | `ggplot2` |
| pytest | `testthat` |

## Naming conventions

- Function names: `snake_case`, matching the Python TreeMMM API. Avoids `R.dot.case` to prevent S3 method-dispatch collisions.
- Exported functions documented via roxygen2 (`@export`).
- All public functions take a `df` (data.frame or data.table) and a `config` (list / S3 object).

## Build and test

```bash
R CMD build .
R CMD check treemmm_*.tar.gz
```

Or via `devtools` in R:

```r
devtools::document()
devtools::check()
devtools::test()
```
