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

  # Log link: proportional allocation across feature SHAP values only.
  # The SHAP expected_value (in margin/log space) is O(log(mean_outcome))
  # which is much larger than per-feature |SHAP| values on the same scale,
  # so including it in the denominator would let it swallow most of the
  # share. Python TreeMMM's decomposer also allocates only across features
  # for log-link models. Each row's attributions sum exactly to the
  # prediction.
  abs_sv <- abs(sv)
  row_total <- rowSums(abs_sv)
  row_total[row_total == 0] <- 1
  per_obs <- abs_sv * (predictions / row_total)
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
