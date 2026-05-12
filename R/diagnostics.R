# Diagnostic checks. Mirrors treemmm.core.diagnostics in the Python package.
# TODO Phase 5: implement coverage_check + variation_decomposition + shap_sign_audit.

# coverage_check counts training observations within a neighborhood of each
# proposed counterfactual input. Below ~30 nearest neighbors signals
# extrapolation regardless of method.
# TODO Phase 5.
coverage_check <- function(X_train, X_simulated, radius = 0.5, min_neighbors = 30L) {
  stop("Not yet implemented (Phase 5). See ROADMAP.md.")
}

# variation_decomposition reports the share of total predictor variance that
# lives within-unit (temporal) versus between-unit (cross-sectional).
# TODO Phase 5.
variation_decomposition <- function(df, unit_col, feature_cols) {
  stop("Not yet implemented (Phase 5). See ROADMAP.md.")
}

# tree_ess_per_param estimates an effective-sample-size analog for a
# tree-based learner: training rows divided by terminal-leaf count.
# TODO Phase 5.
tree_ess_per_param <- function(n_train, n_estimators, max_depth) {
  stop("Not yet implemented (Phase 5). See ROADMAP.md.")
}

# shap_sign_audit summarizes per-channel SHAP-sign consistency. Useful for
# verifying that monotone constraints are doing what they claim.
# TODO Phase 5.
shap_sign_audit <- function(shap_result, X) {
  stop("Not yet implemented (Phase 5). See ROADMAP.md.")
}
