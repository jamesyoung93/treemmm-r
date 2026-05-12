# SHAP value computation. Uses LightGBM's built-in predcontrib = TRUE so we
# don't need a separate {treeshap} dependency for the headline pipeline.

# compute_shap returns a list with:
#   $shap_values  : matrix of n x p SHAP values (one column per feature)
#   $expected_value : scalar base value (model's average prediction in margin
#                      space, used as the SHAP "expected" / "base" column)
#   $link         : "identity" or "log" — relevant for the decomposer step
compute_shap <- function(model, X, link = c("identity", "log")) {
  link <- match.arg(link)
  if (is.data.frame(X)) {
    X_mat <- as.matrix(X[, , drop = FALSE])
  } else {
    X_mat <- X
  }
  storage.mode(X_mat) <- "double"

  # lightgbm 4.x uses `type = "contrib"`; lightgbm 3.x used
  # `predcontrib = TRUE`. Dispatch on the installed version so the
  # package works with both.
  lgbm_ver <- if (requireNamespace("lightgbm", quietly = TRUE)) {
    utils::packageVersion("lightgbm")
  } else {
    package_version("0.0.0")
  }
  contrib <- if (lgbm_ver >= package_version("4.0.0")) {
    stats::predict(model, X_mat, type = "contrib")
  } else {
    stats::predict(model, X_mat, predcontrib = TRUE)
  }
  if (!is.matrix(contrib)) contrib <- as.matrix(contrib)

  n_features <- ncol(X_mat)
  if (ncol(contrib) == n_features + 1L) {
    base <- mean(contrib[, n_features + 1L])
    shap_values <- contrib[, seq_len(n_features), drop = FALSE]
  } else {
    base <- 0
    shap_values <- contrib
  }
  colnames(shap_values) <- colnames(X_mat)

  list(
    shap_values    = shap_values,
    expected_value = base,
    link           = link
  )
}
