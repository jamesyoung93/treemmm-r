# treemmm 0.5.0.9000 (development)

## Phase 5 — mROI + diagnostics + hybrid (2026-05-12)

* New `R/mroi.R`:
  * `simulate_response(result, channel, sweep)` — sweeps allocation 0-150
    percent of current per channel and returns a model-predicted response curve.
  * `mroi_ranking(result)` — endpoint-slope mROI estimate per channel.
  * `optimize_budget(result, channels, step_frac, max_iter)` — simple
    coordinate-ascent budget reallocation under fixed total spend.
  * `mroi_benchmark(result, dataset)` — Spearman rank correlation + direction
    accuracy between model mROI and DGP ground-truth shares.
* New `R/diagnostics.R`:
  * `coverage_check(X_train, X_simulated, radius, min_neighbors)` — flags
    extrapolation when fewer than `min_neighbors` training rows fall within
    standardized radius of each simulated input.
  * `variation_decomposition(df, unit_col, feature_cols)` — within-unit vs
    between-unit variance share per feature.
  * `tree_ess_per_param(n_train, n_estimators, max_depth)` — Bayesian-style
    effective sample size analog for tree learners, with `adequate / weak /
    insufficient` diagnostic label.
  * `shap_sign_audit(shap_result)` — per-channel negative/positive SHAP
    fractions, signed and unsigned means, dominant sign, and sign-consistency
    score. Documents the expected mixed-sign behavior under monotone
    constraints with interaction effects.
* `R/baselines.R::fit_glmm_hybrid()` ships as a working tree-to-GLMM hybrid:
  fit LightGBM, rank feature pairs by mean |SHAP_i * SHAP_j|, refit a GLMM
  with the top `n_interactions` pairs as fixed-effect product terms.
* Tests in `tests/testthat/test-mroi-diagnostics.R` cover each new function.
* NAMESPACE adds nine new exports (six diagnostics/mroi + three sweep helpers).

# treemmm 0.4.0.9000 (development)

## Phase 4 — Baselines (2026-05-12)

* Six baseline fitters: `fit_glmm_naive`, `fit_glmm_oracle`,
  `fit_glmm_distributional`, `fit_glmm_distributional_oracle`,
  `fit_bayesian_hier_naive`, `fit_bayesian_hier_oracle`.

# treemmm 0.3.0.9000 (development)

## Phase 3 — Core pipeline (2026-05-12)

* End-to-end `treemmm_run()` with LightGBM, SHAP via predcontrib, link-aware
  decomposer, rolling-origin CV, distribution detection.

# treemmm 0.2.2.9000 (development)

## Phase 2 — DGP port (2026-05-12)

* All six DGPs implemented.

# treemmm 0.2.1.9000 (development)

## Phase 1 — Scaffold (2026-05-11)

* Package skeleton.

## Planned future versions

* **0.6.0** — Phase 6 (full documentation, vignettes).
* **0.7.0** — Phase 7 (cross-language verification test, release prep).
