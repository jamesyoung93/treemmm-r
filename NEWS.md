# treemmm 0.3.0.9000 (development)

## Phase 3 — Core pipeline (2026-05-12)

* End-to-end `treemmm_run()` works. Six pipeline stages: ingest -> distribution
  detection -> rolling-origin CV -> LightGBM training with monotone constraints
  -> SHAP attribution -> per-channel share aggregation.
* New / updated modules:
  * `R/config.R` — `column_spec()` and `run_config()` now constructed, validated.
  * `R/data_handler.R` — `diagnose_distribution()` heuristic (Poisson / Tweedie /
    Gamma / Gaussian) plus `prepare_data()` panel validation and sorting.
  * `R/temporal.R` — `get_splits()` rolling-origin CV with `min_train_frac` and
    `n_folds` controls.
  * `R/models.R` — `fit_lightgbm()` with monotone constraints, fixed-grid
    hyperparameter search (Python's Optuna deferred to a later phase), and
    per-objective deviance scoring.
  * `R/shap.R` — `compute_shap()` uses LightGBM's `predict(..., predcontrib = TRUE)`
    so no separate {treeshap} dependency is required for the headline pipeline.
  * `R/decomposer.R` — link-function-aware attribution. Identity link returns
    SHAP values plus a `_base` column; log link uses proportional allocation so
    per-row attributions sum to predicted outcome.
  * `R/pipeline.R` — `treemmm_run()` orchestrator. Attribution is computed from
    the last CV fold's model; performance metrics pooled per fold.
* `lightgbm` moved from Suggests to Imports.
* New tests in `tests/testthat/test-pipeline.R`: end-to-end run on the linear
  DGP, auto distribution detection on pharma, `diagnose_distribution()` rule
  coverage, `get_splits()` shape.

## Known limitations of v0.3.0

* Hyperparameter search is a 2-point fixed grid by default (`n_optuna_trials`
  argument controls the grid size). Optuna-equivalent Bayesian optimization
  via {mlr3tuning} is deferred to a later phase.
* CatBoost / XGBoost wrappers not yet implemented.
* Adstock preprocessing, mROI, and diagnostics modules remain stubs.

# treemmm 0.2.2.9000 (development)

## Phase 2 — DGP port (2026-05-12)

* All four headline DGPs (pharma, cpg, saas, linear) and the two specialty
  DGPs (pharma_adstock, geo_panel) implemented.
* New `R/generator.R` ports `treemmm.demo.generator` from the Python package.
* Tests in `tests/testthat/test-datasets.R` verify panel shape, attribution
  normalization, HCS segment coverage, adstock variant ordering, and seed
  reproducibility.

# treemmm 0.2.1.9000 (development)

## Phase 1 — Scaffold (2026-05-11)

* Package skeleton: `DESCRIPTION`, `NAMESPACE`, `R/` stubs, `tests/`,
  GitHub Actions CI.
* All R/ functions present as stubs throwing `Not yet implemented` with a
  reference to `ROADMAP.md`.
* Mirrors the Python TreeMMM v0.2.1 API surface using snake_case function names.

## Planned future versions

* **0.4.0** — Phase 4 (baselines). GLMM-Naive/Oracle + PyMC-Hier-Naive/Oracle
  + distributional GLM.
* **0.5.0** — Phase 5 (mROI + diagnostics).
* **0.6.0** — Phase 6 (full documentation, vignettes).
* **0.7.0** — Phase 7 (cross-language verification test, release prep).
