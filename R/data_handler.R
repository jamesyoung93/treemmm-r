# Panel diagnostics + outcome-distribution detection.
# Mirrors treemmm.core.data_handler in the Python package.
# TODO Phase 3: implement distribution detection rules and panel validation.

#' Diagnose the appropriate outcome distribution from data
#'
#' Heuristic rules:
#' * Integer-valued, non-negative, variance approximately mean -> Poisson.
#' * Integer-valued, non-negative, variance >> mean -> Negative Binomial.
#' * Continuous, non-negative, zero-inflated -> Tweedie.
#' * Continuous, strictly positive -> Gamma.
#' * Otherwise -> Gaussian.
#'
#' @param y Numeric vector of outcomes.
#' @return A list with `family`, `reasoning`, and summary statistics.
#' @export
diagnose_distribution <- function(y) {
  stop("Not yet implemented (Phase 3). See ROADMAP.md.")
}

# prepare_data validates the panel, applies any preprocessing (adstock,
# log1p, etc.), and returns a standardized panel object.
# TODO Phase 3: implement.
prepare_data <- function(df, config) {
  stop("Not yet implemented (Phase 3). See ROADMAP.md.")
}
