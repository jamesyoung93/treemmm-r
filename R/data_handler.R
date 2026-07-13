# Panel diagnostics + outcome-distribution detection.
# Mirrors treemmm.core.data_handler in the Python package.

#' Diagnose the appropriate outcome distribution from data
#'
#' Heuristic rules in decreasing priority:
#' * Strictly non-negative integers with variance > 1.5 * mean -> "poisson"
#'   (LightGBM's poisson objective handles overdispersion through tuning;
#'   a true Negative Binomial objective is not available in stock LightGBM).
#' * Non-negative continuous with at least 5 percent zeros -> "tweedie".
#' * Strictly positive continuous -> "gamma".
#' * Otherwise -> "gaussian".
#'
#' @param y Numeric vector of outcomes.
#' @return A list with `family` (the detected objective string) and
#'   `reasoning` (a short human-readable description of the rule that fired).
#' @export
diagnose_distribution <- function(y) {
  y_clean <- y[is.finite(y)]
  if (length(y_clean) == 0L) {
    return(list(family = "gaussian", reasoning = "no usable data"))
  }

  is_integer_like <- all(abs(y_clean - round(y_clean)) < 1e-9)
  is_nonneg <- all(y_clean >= 0)
  zero_frac <- mean(y_clean == 0)
  mean_y <- mean(y_clean)
  var_y <- stats::var(y_clean)

  if (is_integer_like && is_nonneg) {
    if (is.finite(mean_y) && mean_y > 0 && var_y > 1.5 * mean_y) {
      return(list(family = "poisson",
                  reasoning = sprintf(
                    "integer counts, overdispersed (var/mean = %.2f)",
                    var_y / mean_y)))
    }
    return(list(family = "poisson", reasoning = "integer counts"))
  }
  if (is_nonneg && zero_frac >= 0.05) {
    return(list(family = "tweedie",
                reasoning = sprintf(
                  "non-negative continuous with %.1f%% zero-inflation",
                  100 * zero_frac)))
  }
  if (is_nonneg && all(y_clean > 0)) {
    return(list(family = "gamma",
                reasoning = "strictly positive continuous"))
  }
  list(family = "gaussian", reasoning = "default (signed continuous)")
}

# Internal: validate and standardize the panel before training.
# Returns a list with $df (sorted by customer x time), $feature_cols (a
# character vector of promo + control + categorical features used by the
# tree), $objective (resolved if "auto"), $link (identity or log).
prepare_data <- function(df, config) {
  if (!inherits(config, "run_config")) {
    stop("`config` must be a run_config() result.")
  }
  cs <- config$columns
  needed <- c(cs$customer_id, cs$time_col, cs$outcome_col,
              cs$promo_vars, cs$control_vars, cs$categorical_vars)
  missing <- setdiff(unique(needed), names(df))
  if (length(missing) > 0L) {
    stop("Missing columns: ", paste(missing, collapse = ", "))
  }

  df <- data.table::as.data.table(df)
  data.table::setorderv(df, c(cs$customer_id, cs$time_col))

  # Resolve "auto" objective via distribution detection.
  resolved_objective <- config$objective
  reasoning <- ""
  if (resolved_objective == "auto") {
    dd <- diagnose_distribution(df[[cs$outcome_col]])
    resolved_objective <- dd$family
    reasoning <- dd$reasoning
  }

  # Model features are exactly the roles declared in the column specification;
  # no additional synthetic columns are added or removed implicitly.
  feature_cols <- c(cs$promo_vars, cs$control_vars, cs$categorical_vars)
  feature_cols <- intersect(feature_cols, names(df))

  list(
    df              = df,
    feature_cols    = feature_cols,
    objective       = resolved_objective,
    link            = .objective_link(resolved_objective),
    distribution_reasoning = reasoning
  )
}
