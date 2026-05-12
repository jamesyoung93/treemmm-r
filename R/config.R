# Pipeline configuration. Mirrors the Python treemmm.core.config module.
# TODO Phase 3: implement validation and default-resolution logic.

#' Declare which columns play which role in a panel
#'
#' @param customer_id Column name identifying the panel unit (HCP, store, account).
#' @param time_col Column name for the period index (month, week, quarter, ...).
#' @param outcome_col Column name for the response variable.
#' @param promo_vars Character vector of promotional channel column names.
#' @param control_vars Character vector of control column names (seasonality, market index, ...).
#' @return A `column_spec` object (a named list with class `column_spec`).
#' @export
column_spec <- function(customer_id,
                        time_col,
                        outcome_col,
                        promo_vars,
                        control_vars = character(0)) {
  stop("Not yet implemented (Phase 3). See ROADMAP.md.")
}

#' Build a TreeMMM pipeline configuration
#'
#' @param columns A [column_spec()] result.
#' @param objective One of `"auto"`, `"gaussian"`, `"poisson"`, `"tweedie"`,
#'   `"gamma"`. `"auto"` triggers distribution detection in [diagnose_distribution()].
#' @param n_optuna_trials Number of hyperparameter trials (Python default 20).
#'   For v0.2.1, this is the size of a fixed grid; `mlr3tuning` is deferred.
#' @return A `run_config` object (a named list with class `run_config`).
#' @export
run_config <- function(columns,
                       objective = "auto",
                       n_optuna_trials = 20L) {
  stop("Not yet implemented (Phase 3). See ROADMAP.md.")
}
