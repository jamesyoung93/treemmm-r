# treemmm 0.4.0.9000 (development)

## Phase 4 — Baselines (2026-05-12)

* New module `R/baselines.R` with six baseline fitters:
  * `fit_glmm_naive()`   — `lme4::lmer` with `log1p(outcome)` (non-Gaussian)
                            or raw outcome (Gaussian), random customer intercept
  * `fit_glmm_oracle()`  — naive + planted interactions as fixed-effect terms
  * `fit_glmm_distributional()` — base `stats::glm` with Poisson / Gamma(log) /
                            Gaussian family per resolved objective (Tweedie
                            approximated with Gamma(log); pass `family_override`
                            for `statmod::tweedie`)
  * `fit_glmm_distributional_oracle()` — distributional GLM + planted
                            interactions
  * `fit_bayesian_hier_naive()`  — `brms::brm` customer-level random intercept;
                            optional, requires Stan backend (skips gracefully)
  * `fit_bayesian_hier_oracle()` — Bayesian hierarchical + planted interactions
* All baselines return `$model`, `$attribution_shares`, `$formula` so a
  benchmark loop can compare apples-to-apples against `treemmm_run()`.
* Shares use the same "centered contribution magnitude" rule as the synthetic
  DGP ground truth, matching the Python implementation's GLMM attribution.
* `lme4` moved from Suggests to Imports.
* `brms` remains Suggests (heavy Stan dependency; not installed in default CI).
  Tests use `skip_if_not_installed("brms")` so CI stays green without it.
* `fit_glmm_hybrid()` (tree-to-GLMM) deferred to Phase 5.

## Verification gate

* Tests in `tests/testthat/test-baselines.R` verify each baseline:
  fits without error, returns shares in `[0, 1]`, sums to 1, picks the right
  family for the resolved objective, and accepts planted interactions for the
  Oracle variants.

# treemmm 0.3.0.9000 (development)

## Phase 3 — Core pipeline (2026-05-12)

* End-to-end `treemmm_run()` works (six pipeline stages).
* LightGBM with monotone constraints, fixed-grid hyperparameter search,
  per-objective deviance.
* SHAP via LightGBM's `predict(..., predcontrib = TRUE)` (no separate
  `treeshap` dependency required).
* Link-function-aware attribution decomposer.
* Rolling-origin temporal CV.
* `lightgbm` moved from Suggests to Imports.

# treemmm 0.2.2.9000 (development)

## Phase 2 — DGP port (2026-05-12)

* All four headline DGPs (pharma, cpg, saas, linear) and the two specialty
  DGPs (pharma_adstock, geo_panel) implemented.

# treemmm 0.2.1.9000 (development)

## Phase 1 — Scaffold (2026-05-11)

* Package skeleton, CI, stubs.

## Planned future versions

* **0.5.0** — Phase 5 (mROI + diagnostics; Tree-to-GLMM hybrid).
* **0.6.0** — Phase 6 (full documentation, vignettes).
* **0.7.0** — Phase 7 (cross-language verification test, release prep).
