# treemmm 0.2.2.9000 (development)

## Phase 2 — DGP port (2026-05-12)

* All four headline DGPs and the two specialty DGPs are now implemented:
  * `generate_pharma_dataset()` — NegBin with rheum/derm HCS, targeting bias, channel correlation, three planted interactions
  * `generate_cpg_dataset()` — Tweedie with small/medium/large store HCS, one planted interaction
  * `generate_saas_dataset()` — ZI-Gamma with enterprise/SMB HCS, two planted interactions
  * `generate_linear_dataset()` — Gaussian, no HCS, no interactions (honesty test)
  * `generate_pharma_adstock_dataset()` — pharma + geometric adstock variant
  * `generate_geo_panel_dataset()` — 200 regions x 52 weeks Tweedie with planted adstock
* New `R/generator.R` contains the core DGP engine ported from `treemmm.demo.generator` in the Python implementation.
* Tests in `tests/testthat/test-datasets.R` verify panel shape, attribution-share normalization, HCS segment coverage, adstock variant, and seed reproducibility.
* No external R-package dependencies added beyond `data.table` (already required).

## Reproducibility caveat

R's Mersenne Twister and Python's PCG64 produce different samples at the same seed, so the generated panels are NOT identical to the Python ones at seed 42. The DGP coefficients and structural form match exactly; reference attribution shares converge to the Python ones within Monte Carlo error (< 0.5 pp at headline scale).

# treemmm 0.2.1.9000 (development)

## Phase 1 — Scaffold (2026-05-11)

* Package skeleton: `DESCRIPTION`, `NAMESPACE`, `R/` stubs, `tests/`, GitHub Actions CI.
* All R/ functions present as stubs throwing `Not yet implemented` with a reference to `ROADMAP.md`.
* Mirrors the Python TreeMMM v0.2.1 API surface using snake_case function names.

## Planned future versions

* **0.3.0** — Phase 3 (core pipeline). LightGBM + SHAP + decomposer + temporal CV.
* **0.4.0** — Phase 4 (baselines). GLMM-Naive/Oracle + PyMC-Hier-Naive/Oracle + distributional GLM.
* **0.5.0** — Phase 5 (mROI + diagnostics).
* **0.6.0** — Phase 6 (full documentation, vignettes).
* **0.7.0** — Phase 7 (cross-language verification test, release prep).
