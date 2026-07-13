#' treemmm: Tree-Based Marketing Mix Modeling with SHAP Attribution
#'
#' Tree-based MMM using gradient-boosted trees (LightGBM, XGBoost) paired
#' with SHAP attribution. R port of the Python TreeMMM package
#' (<https://github.com/jamesyoung93/treemmm>).
#'
#' @section Main entry points:
#' * [run_config()] and [column_spec()] to describe a panel and pipeline.
#' * [treemmm_run()] to execute the pipeline end-to-end.
#' * [generate_pharma_dataset()] and siblings to produce the synthetic DGPs.
#'
#' @section Status:
#' Version 0.3.1 includes the end-to-end LightGBM/SHAP pipeline, synthetic
#' panels, regression and optional Bayesian baselines, diagnostics, mROI,
#' cap-bounded reallocation, and deterministic cross-language parity fixtures.
#' See `ROADMAP.md` for the implementation history and remaining limitations.
#'
#' @keywords internal
"_PACKAGE"
