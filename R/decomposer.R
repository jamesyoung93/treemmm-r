# Link-function-aware attribution decomposer.
# Mirrors treemmm.core.attribution.decomposer in the Python package.

# decompose() turns margin-scale SHAP values into outcome-scale per-feature
# attributions whose row-sums equal each row's prediction.
#
# For identity link (Gaussian): SHAP values + expected_value already sum to
# prediction by SHAP construction; we just return them.
#
# For log link (Poisson / Tweedie / Gamma): naive exponentiation breaks
# additivity. We allocate the predicted outcome proportionally to absolute
# margin-space contribution, including the SHAP expected/base value:
#   attribution_i = (|SHAP_i| / (|base| + sum_j |SHAP_j|)) * prediction
#
# Per-row attributions therefore always sum to the prediction. The
# "_base" share is the proportion attributable to the expected-value column.
decompose <- function(shap_result, predictions, link = c("identity", "log")) {
  link <- match.arg(link)
  sv <- shap_result$shap_values
  base <- shap_result$expected_value
  n <- nrow(sv)
  p <- ncol(sv)
  feat_names <- colnames(sv)

  if (link == "identity") {
    # SHAP values are directly additive on the response scale. We add the
    # expected_value as a "_base" column so attribution matrix sums to
    # prediction per row.
    full <- cbind("_base" = rep(base, n), sv)
    return(structure(
      list(per_obs = full, predictions = predictions, link = "identity"),
      class = "attribution"
    ))
  }

  # Log link: proportional allocation across the base value and feature SHAP
  # values, matching Python TreeMMM. Each row's attributions sum exactly to
  # the prediction. If every margin-space contribution is effectively zero,
  # the full prediction is assigned to the base term.
  abs_sv <- abs(sv)
  abs_base <- abs(as.numeric(base)[1L])
  row_total <- rowSums(abs_sv) + abs_base
  nonzero <- row_total >= 1e-15

  feature_obs <- matrix(0, nrow = n, ncol = p,
                        dimnames = list(NULL, feat_names))
  base_obs <- numeric(n)
  if (any(nonzero)) {
    scale <- predictions[nonzero] / row_total[nonzero]
    feature_obs[nonzero, ] <- abs_sv[nonzero, , drop = FALSE] * scale
    base_obs[nonzero] <- abs_base * scale
  }
  if (any(!nonzero)) {
    base_obs[!nonzero] <- predictions[!nonzero]
  }
  per_obs <- cbind("_base" = base_obs, feature_obs)
  structure(
    list(per_obs = per_obs, predictions = predictions, link = "log"),
    class = "attribution"
  )
}

# global_attribution turns the per-observation attribution matrix into
# per-feature shares. Shares use absolute magnitudes so they are always
# non-negative even when individual SHAP values cancel across rows.
global_attribution <- function(attribution) {
  per_obs <- attribution$per_obs
  feature_totals <- colSums(abs(per_obs))
  total <- sum(feature_totals)
  if (total == 0) {
    shares <- rep(0, length(feature_totals))
  } else {
    shares <- feature_totals / total
  }
  stats::setNames(as.list(shares), colnames(per_obs))
}


#' Renormalize attribution shares over promotional variables
#'
#' Filters a full attribution-share vector to the requested promotional
#' variables, takes absolute magnitudes, and renormalizes them to sum to one.
#' This is the comparison convention used by the TreeMMM paper benchmarks: it
#' removes differences in base/intercept and control-variable definitions
#' before calculating promotional attribution error.
#'
#' @param shares Named numeric vector or named list of attribution shares.
#' @param promo_vars Character vector naming the promotional variables to keep.
#' @return A named numeric vector in `promo_vars` order. It sums to one unless
#'   every selected share is zero, in which case it contains zeros.
#' @export
promo_only_shares <- function(shares, promo_vars) {
  values <- unlist(shares, use.names = TRUE)
  if (is.null(names(values))) {
    stop("`shares` must be named.")
  }
  if (!is.character(promo_vars) || length(promo_vars) == 0L ||
      anyNA(promo_vars) || any(!nzchar(promo_vars))) {
    stop("`promo_vars` must be a non-empty character vector of names.")
  }

  selected <- vapply(
    promo_vars,
    function(var) if (var %in% names(values)) values[[var]] else 0,
    numeric(1L)
  )
  selected <- abs(selected)
  total <- sum(selected)
  if (total < 1e-15) {
    return(selected)
  }
  selected / total
}

# Internal: verify row-sums match predictions within tolerance.
verify_attribution_sums <- function(attribution, predictions, tol = 1e-4) {
  per_obs <- attribution$per_obs
  row_totals <- rowSums(per_obs)
  if (attribution$link == "identity") {
    # SHAP plus expected_value = prediction by SHAP construction
    diff <- abs(row_totals - predictions)
    if (max(diff) > tol) {
      stop("Attribution row sums do not match predictions; max diff ",
           max(diff))
    }
  } else {
    # Log-link proportional allocation: row sums equal prediction by
    # construction (numerical jitter only).
    diff <- abs(row_totals - predictions)
    if (max(diff) > tol * max(abs(predictions))) {
      stop("Log-link attribution row sums do not match predictions; max diff ",
           max(diff))
    }
  }
  invisible(TRUE)
}
