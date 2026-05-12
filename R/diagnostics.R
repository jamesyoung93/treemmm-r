# Diagnostic checks. Mirrors treemmm.core.diagnostics in the Python package.
# Five diagnostics determine whether either modeling paradigm is in defensible
# territory on a given panel.

#' Coverage check: count training neighbors within a radius
#'
#' For each row of `X_simulated`, counts how many rows of `X_train` lie within
#' Euclidean distance `radius` (after standardizing each column to unit variance).
#' Returns a vector of neighbor counts. Below `min_neighbors` typically signals
#' extrapolation regardless of method.
#'
#' @param X_train Numeric matrix or data.frame.
#' @param X_simulated Numeric matrix or data.frame with the same columns.
#' @param radius Distance threshold in standardized space.
#' @param min_neighbors Threshold below which extrapolation is flagged.
#' @return A list with `$counts` (per-simulated-row neighbor count) and
#'   `$extrapolation_fraction` (fraction below `min_neighbors`).
#' @export
coverage_check <- function(X_train,
                           X_simulated,
                           radius = 0.5,
                           min_neighbors = 30L) {
  Xt <- as.matrix(X_train)
  Xs <- as.matrix(X_simulated)
  storage.mode(Xt) <- "double"
  storage.mode(Xs) <- "double"

  # Standardize columns using train mean / sd
  mu <- colMeans(Xt)
  sd <- apply(Xt, 2L, stats::sd)
  sd[sd == 0] <- 1
  Zt <- sweep(sweep(Xt, 2L, mu, "-"), 2L, sd, "/")
  Zs <- sweep(sweep(Xs, 2L, mu, "-"), 2L, sd, "/")

  counts <- integer(nrow(Zs))
  for (i in seq_len(nrow(Zs))) {
    diffs <- sweep(Zt, 2L, Zs[i, ], "-")
    dists <- sqrt(rowSums(diffs * diffs))
    counts[i] <- sum(dists <= radius)
  }
  list(counts = counts,
       extrapolation_fraction = mean(counts < min_neighbors))
}


#' Decompose total predictor variance into within- and between-unit shares
#'
#' For each feature column, returns the fraction of total variance that lives
#' within-unit (temporal variation, holding customer fixed) versus between-unit
#' (cross-sectional, holding period fixed).
#'
#' @param df A panel data.frame.
#' @param unit_col The column identifying the panel unit (e.g. customer_id).
#' @param feature_cols Numeric feature columns to decompose.
#' @return A data.table with columns `feature`, `within_share`, `between_share`.
#' @export
variation_decomposition <- function(df, unit_col, feature_cols) {
  df <- data.table::as.data.table(df)
  out <- data.table::data.table(
    feature       = character(0),
    within_share  = numeric(0),
    between_share = numeric(0)
  )
  for (fc in feature_cols) {
    x <- as.numeric(df[[fc]])
    g <- df[[unit_col]]
    unit_means <- tapply(x, g, mean)
    grand_mean <- mean(x)
    between_var <- mean((unit_means[g] - grand_mean) ^ 2)
    within_var  <- mean((x - unit_means[g]) ^ 2)
    total <- between_var + within_var
    if (total == 0) {
      out <- rbind(out, list(fc, 0, 0))
    } else {
      out <- rbind(out, list(fc, within_var / total, between_var / total))
    }
  }
  out
}


#' Effective-sample-size analog for a tree learner
#'
#' Crude analog to `arviz.ess / n_parameters` for Bayesian models: training
#' rows divided by the number of leaves at max depth, summed across estimators.
#' Below ~20 obs per parameter both paradigms are weakly identified.
#'
#' @param n_train Number of training rows.
#' @param n_estimators Number of boosting rounds.
#' @param max_depth Maximum tree depth.
#' @return A list with `$ess_per_param`, `$n_params`, `$diagnostic`
#'   (`"adequate"`, `"weak"`, `"insufficient"`).
#' @export
tree_ess_per_param <- function(n_train, n_estimators, max_depth) {
  n_params <- n_estimators * (2 ^ max_depth)
  ess <- if (n_params > 0) n_train / n_params else Inf
  diagnostic <- if (ess >= 20) "adequate"
                else if (ess >= 10) "weak"
                else "insufficient"
  list(ess_per_param = ess, n_params = n_params, diagnostic = diagnostic)
}


#' Audit the per-channel sign distribution of SHAP values
#'
#' For each feature column in a SHAP result, returns the fraction of
#' observations with negative / positive SHAP, the signed and unsigned means,
#' and the dominant sign. Useful for verifying monotone constraints are
#' producing the expected directional behavior (note: a monotone-positive
#' constraint guarantees a non-decreasing GLOBAL response, but local SHAP
#' values can still be negative under interaction effects — that is
#' mathematically expected, not a violation).
#'
#' @param shap_result Output of [compute_shap()].
#' @return A data.table with one row per channel.
#' @export
shap_sign_audit <- function(shap_result) {
  sv <- shap_result$shap_values
  out <- data.table::data.table(
    channel         = character(0),
    frac_negative   = numeric(0),
    frac_positive   = numeric(0),
    mean_signed     = numeric(0),
    mean_unsigned   = numeric(0),
    sign_consistency = numeric(0),
    dominant_sign   = character(0)
  )
  for (j in seq_len(ncol(sv))) {
    col <- sv[, j]
    fn <- mean(col < 0)
    fp <- mean(col > 0)
    sign_consistency <- abs(fp - fn)
    dom <- if (sign_consistency < 0.1) "mixed"
           else if (fp > fn) "positive" else "negative"
    out <- rbind(out, list(
      colnames(sv)[j], fn, fp,
      mean(col), mean(abs(col)),
      sign_consistency, dom
    ))
  }
  out
}
