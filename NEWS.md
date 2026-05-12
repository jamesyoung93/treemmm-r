# treemmm 0.2.1.9000 (development)

## Phase 1 — Scaffold (2026-05-11)

* Package skeleton created: `DESCRIPTION`, `NAMESPACE`, `R/` stubs, `tests/`, GitHub Actions CI.
* All R/ functions present as stubs that throw `Not yet implemented` with a reference to `ROADMAP.md`.
* Mirrors the Python TreeMMM v0.2.1 API surface using snake_case function names.
* No working functionality yet. See [`ROADMAP.md`](ROADMAP.md) for the seven-phase implementation plan.

## Planned future versions

* **0.2.1** — Phase 2 (DGP port). All four DGPs reproducing the Python panels at seed 42.
* **0.3.0** — Phase 3 (core pipeline). LightGBM + SHAP + decomposer + temporal CV.
* **0.4.0** — Phase 4 (baselines). GLMM-Naive/Oracle + PyMC-Hier-Naive/Oracle + distributional GLM.
* **0.5.0** — Phase 5 (mROI + diagnostics).
* **0.6.0** — Phase 6 (full documentation, vignettes).
* **0.7.0** — Phase 7 (cross-language verification test, release prep).
