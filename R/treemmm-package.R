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
#' Version 0.2.1.9000 is Phase 1 (scaffold). Functions are present as stubs
#' that throw `Not yet implemented`. See `ROADMAP.md` for the seven-phase plan.
#'
#' @keywords internal
"_PACKAGE"
