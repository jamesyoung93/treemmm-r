# treemmm 0.6.0.9000 (development)

## Phase 6 — Documentation (2026-05-12)

* Three vignettes in `vignettes/`:
  * **quickstart.Rmd** — five-minute end-to-end TreeMMM run on the pharma DGP.
  * **benchmark.Rmd** — head-to-head TreeMMM vs GLMM-Naive / GLMM-Oracle /
    GLMMDist-Naive, with attribution-share MAPE and mROI ranking comparison.
  * **dgp_play.Rmd** — inspecting and tuning the synthetic DGPs (sample size,
    seed, HCS segment means, adstock variant, reproducibility caveat across
    R and Python).
* `_pkgdown.yml` configures the reference grouping (Pipeline / Synthetic DGPs
  / Marginal ROI / Diagnostics) and links back to the Python repo and `SPEC.md`.
* GitHub Actions workflow now runs `roxygen2::roxygenize()` before
  `R CMD check`, so `man/*.Rd` is auto-generated on CI even though it is
  not committed. Users installing locally should run `devtools::document()`
  once after cloning to populate `man/`.
* `VignetteBuilder: knitr` restored in `DESCRIPTION`; `knitr` and `rmarkdown`
  are available in Suggests via the existing CI dependency block.

# treemmm 0.5.0.9000 (development)

## Phase 5 — mROI + diagnostics + hybrid (2026-05-12)

* mROI module, diagnostics suite, working tree-to-GLMM hybrid.

# treemmm 0.4.0.9000 (development)

## Phase 4 — Baselines (2026-05-12)

* GLMM-Naive / Oracle / Dist / Bayesian (brms) baselines.

# treemmm 0.3.0.9000 (development)

## Phase 3 — Core pipeline (2026-05-12)

* End-to-end `treemmm_run()`.

# treemmm 0.2.2.9000 (development)

## Phase 2 — DGP port (2026-05-12)

* All six DGPs.

# treemmm 0.2.1.9000 (development)

## Phase 1 — Scaffold (2026-05-11)

* Package skeleton.

## Planned future versions

* **0.7.0** — Phase 7 (cross-language verification test, release prep).
