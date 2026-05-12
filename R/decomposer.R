# Link-function-aware attribution decomposer.
# Mirrors treemmm.core.attribution.decomposer in the Python package.

# decompose() turns margin-scale SHAP values into outcome-scale per-feature
# attributions whose row-sums equal each row's prediction.
#
# For identity link (Gaussian): SHAP values + expected_value already sum to
# prediction by SHAP construction; we just return them.
#
# For log link (Poisson / Tweedie / Gamma): naive exponentiation breaks
# additivity. We allocate the predicted outcome proportionally to |SHAP|:
#   attribution_i = (|SHAP_i| / sum_j |SHAP_j|) * prediction
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

  # Log link: proportional allocation including a "_base" component
  # (the expected value contributes proportionally to |base|).
  abs_sv <- abs(sv)
  abs_base <- rep(abs(base), n)
  total <- rowSums(abs_sv) + abs_base
  total[total == 0] <- 1  # avoid divide-by-zero
  per_obs <- abs_sv * (predictions / total)
  base_col <- abs_base * (predictions / total)
  full <- cbind("_base" = base_col, per_obs)
  structure(
    list(per_obs = full, predictions = predictions, link = "log"),
    class = "attribution"
  )
}

# global_attribution turns the per-observation attribution matrix into
# per-feature shares (each share is the L1 sum of that feature's
# attribution divided by the total across features).
global_attribution <- function(attribution) {
  per_obs <- attribution$per_obs
  feature_totals <- colSums(per_obs)
  total <- sum(feature_totals)
  if (total == 0) {
    shares <- rep(0, length(feature_totals))
  } else {
    shares <- feature_totals / total
  }
  setNames(as.list(shares), colnames(per_obs))
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
