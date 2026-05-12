# SHAP TreeExplainer wrapper. Uses the {treeshap} R package.
# Mirrors treemmm.core.interpret.shap_engine in the Python package.
# TODO Phase 3: implement compute_shap() and interaction discovery.

# compute_shap runs TreeSHAP on a fitted tree-based model and returns the
# per-observation SHAP matrix on the margin (link) scale, with metadata
# about the link function.
# TODO Phase 3.
compute_shap <- function(model, X, link = c("identity", "log")) {
  link <- match.arg(link)
  stop("Not yet implemented (Phase 3). See ROADMAP.md.")
}

# discover_interactions inspects SHAP interaction values and flags variable
# pairs whose interaction effect exceeds the SHAP-importance threshold.
# TODO Phase 3.
discover_interactions <- function(shap_result,
                                  importance_threshold = 0.03,
                                  rank_correlation_threshold = 0.10) {
  stop("Not yet implemented (Phase 3). See ROADMAP.md.")
}
