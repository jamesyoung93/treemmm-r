# Regression / Bayesian baselines for benchmark comparison.
# Mirrors treemmm.core.models.glmm_* + bayesian_baseline in the Python package.

# Internal: extract attribution shares from a fitted regression model.
# Uses the same "centered contribution magnitude" rule as the synthetic DGP
# ground truth so the GLMM and DGP shares live on the same scale.
.extract_regression_shares <- function(model,
                                       df,
                                       feature_cols,
                                       link = c("identity", "log"),
                                       base_share = 0) {
  link <- match.arg(link)

  coefs <- if (inherits(model, c("lmerMod", "glmerMod"))) {
    lme4::fixef(model)
  } else {
    stats::coef(model)
  }

  contributions <- numeric(length(feature_cols))
  names(contributions) <- feature_cols
  for (fc in feature_cols) {
    if (fc %in% names(coefs)) {
      beta <- as.numeric(coefs[fc])
      x_vals <- as.numeric(df[[fc]])
      contrib <- beta * x_vals
      contributions[fc] <- sum(abs(contrib - mean(contrib)))
    } else {
      # Could be an expanded factor or unrecognized term; ignore.
      contributions[fc] <- 0
    }
  }

  total_promo_control <- sum(contributions)
  if (total_promo_control == 0) {
    shares <- c("_base" = base_share,
                setNames(rep(0, length(contributions)), feature_cols))
    return(as.list(shares))
  }
  # Allocate (1 - base_share) across features proportional to magnitudes
  promo_fraction <- 1 - base_share
  feature_shares <- (contributions / total_promo_control) * promo_fraction
  shares <- c("_base" = base_share, feature_shares)
  as.list(shares)
}

# Internal: build a fixed-effect formula string from promo + control + extras.
.formula_rhs <- function(promo_vars, control_vars, extras = character(0)) {
  paste(c(promo_vars, control_vars, extras), collapse = " + ")
}

# Internal: build interaction terms in formula syntax from a list of
# interaction_spec objects.
.interaction_terms <- function(interactions) {
  if (length(interactions) == 0L) return(character(0))
  vapply(interactions, function(it) {
    sprintf("%s:%s", it$var1, it$var2)
  }, character(1L))
}


# ---------------------------------------------------------------------------
# GLMM-Naive: lme4 with log1p outcome for count families, random customer
# intercept, main effects only.
# ---------------------------------------------------------------------------

#' Fit the GLMM-Naive baseline (main effects + random customer intercept)
#'
#' Uses `lme4::lmer` on `log1p(outcome)` for non-Gaussian families and on raw
#' outcome for Gaussian. Returns attribution shares derived from the absolute
#' standardized fixed-effect contributions. Matches the Python implementation's
#' GLMM-Naive baseline.
#'
#' @param df A `data.frame` or `data.table` panel.
#' @param config A [run_config()] object.
#' @return A list with `$model`, `$attribution_shares`, `$formula`, `$objective`.
#' @export
fit_glmm_naive <- function(df, config) {
  if (!requireNamespace("lme4", quietly = TRUE)) {
    stop("Requires 'lme4'. Install via install.packages('lme4').")
  }
  prepared <- prepare_data(df, config)
  cs <- config$columns
  d <- prepared$df
  use_log1p <- prepared$objective != "gaussian"

  lhs <- if (use_log1p) sprintf("log1p(%s)", cs$outcome_col) else cs$outcome_col
  rhs <- .formula_rhs(cs$promo_vars, cs$control_vars)
  fml <- stats::as.formula(sprintf("%s ~ %s + (1 | %s)",
                                   lhs, rhs, cs$customer_id))

  model <- suppressMessages(suppressWarnings(
    lme4::lmer(fml, data = d, REML = TRUE)
  ))

  shares <- .extract_regression_shares(
    model, d, c(cs$promo_vars, cs$control_vars),
    link = prepared$link, base_share = 0
  )
  list(model = model, attribution_shares = shares,
       formula = fml, objective = prepared$objective)
}


# ---------------------------------------------------------------------------
# GLMM-Oracle: GLMM-Naive plus planted interactions as fixed effects.
# ---------------------------------------------------------------------------

#' Fit the GLMM-Oracle baseline (main effects + planted interactions)
#'
#' Identical to [fit_glmm_naive()] except the planted DGP interactions are
#' added as fixed-effect product terms. Represents the upper bound for a
#' regression baseline assuming the analyst knows which channels co-modulate.
#'
#' @param df A `data.frame` or `data.table` panel.
#' @param config A [run_config()] object.
#' @param planted_interactions List of [interaction_spec()] objects (typically
#'   `ground_truth$interactions`).
#' @return Same structure as [fit_glmm_naive()].
#' @export
fit_glmm_oracle <- function(df, config, planted_interactions) {
  if (!requireNamespace("lme4", quietly = TRUE)) {
    stop("Requires 'lme4'. Install via install.packages('lme4').")
  }
  prepared <- prepare_data(df, config)
  cs <- config$columns
  d <- prepared$df
  use_log1p <- prepared$objective != "gaussian"

  lhs <- if (use_log1p) sprintf("log1p(%s)", cs$outcome_col) else cs$outcome_col
  inter_terms <- .interaction_terms(planted_interactions)
  rhs <- .formula_rhs(cs$promo_vars, cs$control_vars, extras = inter_terms)
  fml <- stats::as.formula(sprintf("%s ~ %s + (1 | %s)",
                                   lhs, rhs, cs$customer_id))

  model <- suppressMessages(suppressWarnings(
    lme4::lmer(fml, data = d, REML = TRUE)
  ))

  shares <- .extract_regression_shares(
    model, d, c(cs$promo_vars, cs$control_vars),
    link = prepared$link, base_share = 0
  )
  list(model = model, attribution_shares = shares,
       formula = fml, objective = prepared$objective,
       planted_interactions = planted_interactions)
}


# ---------------------------------------------------------------------------
# GLMMDist: base stats::glm with the correct exponential-family likelihood.
# No random effects (matches Python's statsmodels.GLM limitation).
# ---------------------------------------------------------------------------

#' Fit the distributional-GLM baseline (correct family, no random effects)
#'
#' Mirrors the Python GLMMDist-Naive baseline: `stats::glm` with Poisson,
#' `Gamma(link = "log")`, or Gaussian per the resolved objective. Tweedie is
#' approximated with Gamma(log) because base R doesn't ship a Tweedie family;
#' the `statmod::tweedie` family can be substituted by passing `family_override`.
#'
#' @param df A panel.
#' @param config A [run_config()] object.
#' @param family_override Optional `family` object to use directly.
#' @return A list with `$model`, `$attribution_shares`, `$formula`, `$family`.
#' @export
fit_glmm_distributional <- function(df, config, family_override = NULL) {
  prepared <- prepare_data(df, config)
  cs <- config$columns
  d <- prepared$df

  family <- if (!is.null(family_override)) {
    family_override
  } else {
    switch(prepared$objective,
      gaussian = stats::gaussian(link = "identity"),
      poisson  = stats::poisson(link = "log"),
      gamma    = stats::Gamma(link = "log"),
      tweedie  = stats::Gamma(link = "log"),  # see docstring caveat
      stop("Unsupported objective for GLMMDist: ", prepared$objective))
  }

  rhs <- .formula_rhs(cs$promo_vars, cs$control_vars)
  fml <- stats::as.formula(sprintf("%s ~ %s", cs$outcome_col, rhs))

  # Gamma family requires strictly positive outcomes; nudge zeros up.
  if (inherits(family, "family") && family$family %in% c("Gamma", "gamma")) {
    d[[cs$outcome_col]] <- pmax(d[[cs$outcome_col]], .Machine$double.eps)
  }

  model <- suppressWarnings(stats::glm(fml, data = d, family = family))

  shares <- .extract_regression_shares(
    model, d, c(cs$promo_vars, cs$control_vars),
    link = prepared$link, base_share = 0
  )
  list(model = model, attribution_shares = shares,
       formula = fml, family = family, objective = prepared$objective)
}


# ---------------------------------------------------------------------------
# GLMMDist-Oracle: distributional GLM + planted interactions.
# ---------------------------------------------------------------------------

#' Fit the GLMMDist-Oracle baseline (distributional GLM + planted interactions)
#' @export
fit_glmm_distributional_oracle <- function(df, config, planted_interactions,
                                           family_override = NULL) {
  prepared <- prepare_data(df, config)
  cs <- config$columns
  d <- prepared$df

  family <- if (!is.null(family_override)) {
    family_override
  } else {
    switch(prepared$objective,
      gaussian = stats::gaussian(link = "identity"),
      poisson  = stats::poisson(link = "log"),
      gamma    = stats::Gamma(link = "log"),
      tweedie  = stats::Gamma(link = "log"),
      stop("Unsupported objective for GLMMDist: ", prepared$objective))
  }

  inter_terms <- .interaction_terms(planted_interactions)
  rhs <- .formula_rhs(cs$promo_vars, cs$control_vars, extras = inter_terms)
  fml <- stats::as.formula(sprintf("%s ~ %s", cs$outcome_col, rhs))

  if (inherits(family, "family") && family$family %in% c("Gamma", "gamma")) {
    d[[cs$outcome_col]] <- pmax(d[[cs$outcome_col]], .Machine$double.eps)
  }

  model <- suppressWarnings(stats::glm(fml, data = d, family = family))
  shares <- .extract_regression_shares(
    model, d, c(cs$promo_vars, cs$control_vars),
    link = prepared$link, base_share = 0
  )
  list(model = model, attribution_shares = shares,
       formula = fml, family = family, objective = prepared$objective,
       planted_interactions = planted_interactions)
}


# ---------------------------------------------------------------------------
# PyMC-Hier (Bayesian) baselines via {brms}. Optional — brms requires Stan
# (cmdstanr or rstan backend) installed on the user's machine. Tests skip
# gracefully if brms is unavailable.
# ---------------------------------------------------------------------------

#' Fit the PyMC-Hier-Naive baseline via brms
#'
#' Customer-level hierarchical Bayesian baseline: main effects with a
#' per-customer random intercept, fit via `brms::brm`. The objective resolves
#' to a `brms` family (Gaussian / Poisson / Gamma). Use cmdstanr backend if
#' available for faster sampling.
#'
#' @param df A panel.
#' @param config A [run_config()] object.
#' @param n_chains Number of MCMC chains. Default 2.
#' @param n_iter Number of MCMC iterations per chain (including warmup). Default 1000.
#' @return A list with `$model` (a brmsfit), `$attribution_shares`,
#'   `$formula`, `$objective`.
#' @export
fit_bayesian_hier_naive <- function(df, config,
                                    n_chains = 2L, n_iter = 1000L) {
  if (!requireNamespace("brms", quietly = TRUE)) {
    stop("Requires 'brms' (and a Stan backend). ",
         "Install via install.packages('brms') and ",
         "install.packages('cmdstanr', repos = c('https://stan-dev.r-universe.dev')).")
  }
  prepared <- prepare_data(df, config)
  cs <- config$columns
  d <- prepared$df

  family <- switch(prepared$objective,
    gaussian = brms::gaussian(),
    poisson  = brms::poisson(),
    gamma    = brms::Gamma(link = "log"),
    tweedie  = brms::Gamma(link = "log"),  # brms tweedie not stock
    brms::gaussian())

  rhs <- .formula_rhs(cs$promo_vars, cs$control_vars)
  fml <- brms::bf(stats::as.formula(sprintf("%s ~ %s + (1 | %s)",
                                            cs$outcome_col, rhs,
                                            cs$customer_id)))

  model <- suppressMessages(suppressWarnings(
    brms::brm(formula = fml, data = d, family = family,
              chains = n_chains, iter = n_iter, refresh = 0,
              seed = config$random_state)
  ))

  shares <- .extract_brms_shares(model, d, c(cs$promo_vars, cs$control_vars))
  list(model = model, attribution_shares = shares,
       formula = fml, objective = prepared$objective)
}

#' Fit the PyMC-Hier-Oracle baseline via brms (+ planted interactions)
#' @export
fit_bayesian_hier_oracle <- function(df, config, planted_interactions,
                                     n_chains = 2L, n_iter = 1000L) {
  if (!requireNamespace("brms", quietly = TRUE)) {
    stop("Requires 'brms'. See fit_bayesian_hier_naive() docstring.")
  }
  prepared <- prepare_data(df, config)
  cs <- config$columns
  d <- prepared$df

  family <- switch(prepared$objective,
    gaussian = brms::gaussian(),
    poisson  = brms::poisson(),
    gamma    = brms::Gamma(link = "log"),
    tweedie  = brms::Gamma(link = "log"),
    brms::gaussian())

  inter_terms <- .interaction_terms(planted_interactions)
  rhs <- .formula_rhs(cs$promo_vars, cs$control_vars, extras = inter_terms)
  fml <- brms::bf(stats::as.formula(sprintf("%s ~ %s + (1 | %s)",
                                            cs$outcome_col, rhs,
                                            cs$customer_id)))

  model <- suppressMessages(suppressWarnings(
    brms::brm(formula = fml, data = d, family = family,
              chains = n_chains, iter = n_iter, refresh = 0,
              seed = config$random_state)
  ))

  shares <- .extract_brms_shares(model, d, c(cs$promo_vars, cs$control_vars))
  list(model = model, attribution_shares = shares,
       formula = fml, objective = prepared$objective,
       planted_interactions = planted_interactions)
}

# Internal: extract attribution shares from a brmsfit using posterior-mean
# fixed effects in the same "centered contribution magnitude" formulation
# as the frequentist baselines.
.extract_brms_shares <- function(model, df, feature_cols) {
  if (!requireNamespace("brms", quietly = TRUE)) return(list())
  fixed_eff <- brms::fixef(model)
  beta <- fixed_eff[, "Estimate"]
  # Strip the "b_" prefix that brms uses internally
  names(beta) <- sub("^b_", "", names(beta))

  contributions <- numeric(length(feature_cols))
  names(contributions) <- feature_cols
  for (fc in feature_cols) {
    if (fc %in% names(beta)) {
      contrib <- as.numeric(beta[fc]) * as.numeric(df[[fc]])
      contributions[fc] <- sum(abs(contrib - mean(contrib)))
    }
  }
  total <- sum(contributions)
  if (total == 0) {
    return(as.list(c("_base" = 0,
                     setNames(rep(0, length(contributions)), feature_cols))))
  }
  feature_shares <- contributions / total
  as.list(c("_base" = 0, feature_shares))
}


# ---------------------------------------------------------------------------
# Tree-to-GLMM hybrid: fit a tree, extract top interaction pairs by SHAP-
# pair importance, then refit a GLMM with those interactions as fixed effects.
# Mirrors treemmm.core.models.glmm_hybrid in the Python package.
# ---------------------------------------------------------------------------

#' Fit the tree-to-GLMM hybrid baseline
#'
#' Two-stage procedure:
#'   1. Fit a LightGBM model and compute SHAP values.
#'   2. Rank feature pairs by mean product of |SHAP_i * SHAP_j| across rows;
#'      pick the top `n_interactions`.
#'   3. Refit a GLMM (`lme4::lmer`) with main effects plus those discovered
#'      interactions as fixed-effect product terms.
#'
#' @param df A panel.
#' @param config A [run_config()] object.
#' @param n_interactions Number of top SHAP-derived interaction pairs to keep.
#' @return Same structure as [fit_glmm_naive()] plus `$discovered_interactions`.
#' @export
fit_glmm_hybrid <- function(df, config, n_interactions = 3L) {
  if (!requireNamespace("lme4", quietly = TRUE)) {
    stop("Requires 'lme4'. Install via install.packages('lme4').")
  }
  if (!requireNamespace("lightgbm", quietly = TRUE)) {
    stop("Requires 'lightgbm'. Install via install.packages('lightgbm').")
  }

  prepared <- prepare_data(df, config)
  cs <- config$columns
  d <- prepared$df

  # Stage 1: train a quick LightGBM model to discover interactions.
  X <- as.matrix(d[, c(cs$promo_vars, cs$control_vars), with = FALSE])
  storage.mode(X) <- "double"
  y <- as.numeric(d[[cs$outcome_col]])
  lgbm_obj <- .objective_to_lgbm(prepared$objective)
  monotone <- build_monotone_constraints(
    c(cs$promo_vars, cs$control_vars), cs$promo_vars)
  fit <- fit_lightgbm(X, y,
                      objective = lgbm_obj,
                      tweedie_variance_power = config$tweedie_variance_power,
                      monotone_constraints = monotone,
                      n_trials = 1L,
                      random_state = config$random_state)
  shap_result <- compute_shap(fit$model, X, link = prepared$link)
  sv <- shap_result$shap_values

  # Stage 2: rank feature pairs by mean |product of SHAP|
  promo <- cs$promo_vars
  pair_scores <- list()
  for (i in seq_along(promo)) {
    for (j in seq_along(promo)) {
      if (j <= i) next
      score <- mean(abs(sv[, promo[i]] * sv[, promo[j]]))
      pair_scores[[length(pair_scores) + 1L]] <- list(
        var1 = promo[i], var2 = promo[j], score = score
      )
    }
  }
  pair_scores <- pair_scores[order(
    -vapply(pair_scores, `[[`, numeric(1L), "score"))]
  top <- head(pair_scores, n_interactions)
  discovered <- lapply(top, function(p) interaction_spec(p$var1, p$var2))

  # Stage 3: refit a GLMM with discovered interactions.
  use_log1p <- prepared$objective != "gaussian"
  lhs <- if (use_log1p) sprintf("log1p(%s)", cs$outcome_col) else cs$outcome_col
  rhs <- .formula_rhs(cs$promo_vars, cs$control_vars,
                      extras = .interaction_terms(discovered))
  fml <- stats::as.formula(sprintf("%s ~ %s + (1 | %s)",
                                   lhs, rhs, cs$customer_id))
  model <- suppressMessages(suppressWarnings(
    lme4::lmer(fml, data = d, REML = TRUE)
  ))

  shares <- .extract_regression_shares(
    model, d, c(cs$promo_vars, cs$control_vars),
    link = prepared$link, base_share = 0
  )
  list(model = model, attribution_shares = shares,
       formula = fml, objective = prepared$objective,
       discovered_interactions = discovered)
}
