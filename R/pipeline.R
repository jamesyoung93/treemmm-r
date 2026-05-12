# Main pipeline orchestrator. Mirrors treemmm.pipeline.run() in the Python package.
# TODO Phase 3: implement the six pipeline stages
# (ingest -> diagnostics -> configure -> train -> attribute -> report).

#' Run the TreeMMM pipeline on a panel dataset
#'
#' Orchestrates data preparation, model training, SHAP attribution, and
#' optional reporting on a panel data.frame.
#'
#' @param df A `data.frame` or `data.table` with one row per (customer, period).
#' @param config A [run_config()] object.
#' @param output_dir Optional path. If provided, the pipeline writes per-fold
#'   metrics, per-customer attribution, and a summary CSV to this directory.
#' @return A `pipeline_result` list with fields:
#'   * `attribution_shares`: named numeric vector summing to 1.
#'   * `fold_metrics`: list of per-fold R-squared, WMAPE, MAE, n_test.
#'   * `shap_result`: SHAP value matrix.
#'   * `model_result`: fitted models per fold.
#'   * `prepared_data`: standardized panel object.
#' @export
treemmm_run <- function(df, config, output_dir = NULL) {
  stop("Not yet implemented (Phase 3). See ROADMAP.md.")
}
