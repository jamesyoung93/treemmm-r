# Model wrappers. Each exposes the same interface:
#   model <- fit_<name>(X_train, y_train, config)
#   y_hat <- predict(model, X_test)
# Mirrors treemmm.core.models.* in the Python package.
# TODO Phase 3-4: implement each fitter.

# LightGBM (via {lightgbm} R package) with monotone constraints + a fixed
# grid hyperparameter search. The Python version uses Optuna; the R version
# uses a documented grid for v0.2.1 and defers {mlr3tuning} integration.
# TODO Phase 3.
fit_lightgbm <- function(X_train, y_train, config, monotone_constraints = NULL) {
  stop("Not yet implemented (Phase 3). See ROADMAP.md.")
}

# XGBoost (via {xgboost} R package). Optional alternative to LightGBM.
# TODO Phase 3.
fit_xgboost <- function(X_train, y_train, config, monotone_constraints = NULL) {
  stop("Not yet implemented (Phase 3). See ROADMAP.md.")
}

# Naive GLMM via {lme4}: main effects only, per-customer random intercept,
# log1p outcome transform for count-valued DGPs.
# TODO Phase 4.
fit_glmm_naive <- function(X_train, y_train, config) {
  stop("Not yet implemented (Phase 4). See ROADMAP.md.")
}

# Oracle GLMM via {lme4}: identical to glmm_naive but with planted
# interactions added as fixed effects. For benchmark-only use.
# TODO Phase 4.
fit_glmm_oracle <- function(X_train, y_train, config, planted_interactions) {
  stop("Not yet implemented (Phase 4). See ROADMAP.md.")
}

# Distributional GLM via base {stats}::glm with the correct exponential-family
# likelihood per DGP (Poisson / Tweedie / Gamma / Gaussian).
# TODO Phase 4.
fit_glmm_distributional <- function(X_train, y_train, config, family) {
  stop("Not yet implemented (Phase 4). See ROADMAP.md.")
}

# Naive customer-level hierarchical Bayesian baseline via {brms}.
# Compiles via Stan; default sampler cmdstanr.
# TODO Phase 4.
fit_bayesian_hier_naive <- function(X_train, y_train, config) {
  stop("Not yet implemented (Phase 4). See ROADMAP.md.")
}

# Oracle customer-level hierarchical Bayesian baseline. Same as the naive
# variant with planted interaction terms.
# TODO Phase 4.
fit_bayesian_hier_oracle <- function(X_train, y_train, config, planted_interactions) {
  stop("Not yet implemented (Phase 4). See ROADMAP.md.")
}

# Tree-to-GLMM hybrid: fits a tree, extracts learned interactions, then
# refits a GLMM with those interactions as fixed effects.
# TODO Phase 4.
fit_glmm_hybrid <- function(X_train, y_train, config) {
  stop("Not yet implemented (Phase 4). See ROADMAP.md.")
}
