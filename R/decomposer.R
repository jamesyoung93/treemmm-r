# Link-function-aware attribution decomposer.
# Mirrors treemmm.core.attribution.decomposer in the Python package.
# TODO Phase 3: implement decompose() and verify_attribution_sums().

# decompose converts margin-scale SHAP values into outcome-scale per-channel
# attributions. For identity-link models the SHAP values are directly
# additive. For log-link models, proportional allocation is used so that
# attributions per row always sum exactly to the model's prediction.
# TODO Phase 3.
decompose <- function(shap_result, predictions, link = c("identity", "log")) {
  link <- match.arg(link)
  stop("Not yet implemented (Phase 3). See ROADMAP.md.")
}

# verify_attribution_sums asserts that per-row attributions sum to predicted
# outcomes within numerical tolerance. Raises an error otherwise.
# TODO Phase 3.
verify_attribution_sums <- function(attribution, predictions, tol = 1e-6) {
  stop("Not yet implemented (Phase 3). See ROADMAP.md.")
}
