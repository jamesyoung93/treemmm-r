# Pipeline configuration. Mirrors treemmm.core.config in the Python package.

#' Declare which columns play which role in a panel
#'
#' @param customer_id Column name identifying the panel unit (HCP, store, account).
#' @param time_col Column name for the period index (month, week, quarter, ...).
#' @param outcome_col Column name for the response variable.
#' @param promo_vars Character vector of promotional channel column names.
#' @param control_vars Character vector of control column names. Default empty.
#' @param categorical_vars Character vector of categorical-variable column names
#'   (e.g. an HCS segment column). Default empty.
#' @return A `column_spec` list with class `column_spec`.
#' @export
column_spec <- function(customer_id,
                        time_col,
                        outcome_col,
                        promo_vars,
                        control_vars = character(0L),
                        categorical_vars = character(0L)) {
  stopifnot(is.character(customer_id) && length(customer_id) == 1L)
  stopifnot(is.character(time_col) && length(time_col) == 1L)
  stopifnot(is.character(outcome_col) && length(outcome_col) == 1L)
  stopifnot(is.character(promo_vars) && length(promo_vars) >= 1L)
  structure(
    list(
      customer_id      = customer_id,
      time_col         = time_col,
      outcome_col      = outcome_col,
      promo_vars       = promo_vars,
      control_vars     = control_vars,
      categorical_vars = categorical_vars
    ),
    class = "column_spec"
  )
}

#' Build a TreeMMM pipeline configuration
#'
#' @param columns A [column_spec()] result.
#' @param objective One of `"auto"`, `"gaussian"`, `"poisson"`, `"tweedie"`,
#'   `"gamma"`. `"auto"` triggers distribution detection in
#'   [diagnose_distribution()] at run time.
#' @param tweedie_variance_power Only used when objective is `"tweedie"`.
#' @param n_optuna_trials Hyperparameter grid size for the LightGBM tuner.
#'   The R port uses a fixed grid (the Python implementation uses Optuna);
#'   this controls the number of grid points actually evaluated.
#' @param n_folds Number of rolling-origin temporal CV folds.
#' @param min_train_frac Fraction of the time horizon used for the first
#'   training window in rolling-origin CV.
#' @param random_state Integer seed for reproducibility.
#' @return A `run_config` list with class `run_config`.
#' @export
run_config <- function(columns,
                       objective = "auto",
                       tweedie_variance_power = 1.5,
                       n_optuna_trials = 4L,
                       n_folds = 5L,
                       min_train_frac = 0.75,
                       random_state = 42L) {
  if (!inherits(columns, "column_spec")) {
    stop("`columns` must be a column_spec() result.")
  }
  if (!objective %in% c("auto", "gaussian", "poisson", "tweedie", "gamma")) {
    stop("`objective` must be one of 'auto', 'gaussian', 'poisson', 'tweedie', 'gamma'.")
  }
  structure(
    list(
      columns                = columns,
      objective              = objective,
      tweedie_variance_power = tweedie_variance_power,
      n_optuna_trials        = as.integer(n_optuna_trials),
      n_folds                = as.integer(n_folds),
      min_train_frac         = min_train_frac,
      random_state           = as.integer(random_state)
    ),
    class = "run_config"
  )
}

# Internal helper: get the LightGBM objective string for a given family.
.objective_to_lgbm <- function(obj) {
  switch(obj,
         gaussian = "regression",
         poisson  = "poisson",
         tweedie  = "tweedie",
         gamma    = "gamma",
         stop("Unknown objective: ", obj))
}

# Internal helper: return the link function used by an objective.
.objective_link <- function(obj) {
  if (obj == "gaussian") "identity" else "log"
}
