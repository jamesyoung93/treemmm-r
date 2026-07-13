# Model wrappers. Each exposes a common interface:
#   result <- fit_<name>(X_train, y_train, ...)
#   result$model        the fitted model
#   result$best_params  the chosen hyperparameter set
# Mirrors treemmm.core.models.* in the Python package.

# LightGBM with monotone constraints + fixed-grid hyperparameter search.
# The Python implementation uses Optuna (TPE); the R port uses a small
# deterministic grid. {mlr3tuning} integration is deferred.
fit_lightgbm <- function(X_train, y_train,
                         X_val = NULL, y_val = NULL,
                         objective = "regression",
                         tweedie_variance_power = 1.5,
                         monotone_constraints = NULL,
                         n_trials = 4L,
                         random_state = 42L) {
  if (!requireNamespace("lightgbm", quietly = TRUE)) {
    stop("The {lightgbm} package is required to fit LightGBM models. ",
         "Install with install.packages('lightgbm').")
  }

  X_mat <- if (is.data.frame(X_train)) as.matrix(X_train) else X_train
  storage.mode(X_mat) <- "double"

  base_params <- list(
    objective       = objective,
    metric          = "rmse",
    verbosity       = -1L,
    num_threads     = 0L,
    seed            = random_state,
    feature_fraction_seed = random_state,
    bagging_seed    = random_state,
    deterministic   = TRUE
  )
  if (objective == "tweedie") {
    base_params$tweedie_variance_power <- tweedie_variance_power
  }
  if (!is.null(monotone_constraints)) {
    base_params$monotone_constraints <- monotone_constraints
  }

  # Conservative grid: shallow trees + strong regularization + bagging +
  # column subsampling produce stable SHAP values and accurate attribution
  # recovery. Mirrors the conservative end of Python's Optuna search space
  # (lightgbm_model._suggest_params): the L1/L2 regularization and bagging
  # fractions are essential for additive-DGP recovery — without them the
  # trees absorb noise into SHAP and attribution shares smear across
  # features.
  grid <- expand.grid(
    n_estimators      = c(150L, 250L),
    max_depth         = c(3L, 5L),
    learning_rate     = c(0.05),
    num_leaves        = c(15L),
    min_data_in_leaf  = c(80L),
    feature_fraction  = c(0.75),
    bagging_fraction  = c(0.75),
    bagging_freq      = c(5L),
    lambda_l1         = c(2.0),
    lambda_l2         = c(2.0)
  )
  grid <- grid[seq_len(min(n_trials, nrow(grid))), , drop = FALSE]

  best <- list(score = Inf, model = NULL, params = NULL)
  for (i in seq_len(nrow(grid))) {
    params <- utils::modifyList(base_params, list(
      learning_rate    = grid$learning_rate[i],
      max_depth        = grid$max_depth[i],
      num_leaves       = grid$num_leaves[i],
      min_data_in_leaf = grid$min_data_in_leaf[i],
      feature_fraction = grid$feature_fraction[i],
      bagging_fraction = grid$bagging_fraction[i],
      bagging_freq     = grid$bagging_freq[i],
      lambda_l1        = grid$lambda_l1[i],
      lambda_l2        = grid$lambda_l2[i]
    ))

    dtrain <- lightgbm::lgb.Dataset(X_mat, label = y_train)
    model <- suppressWarnings(suppressMessages(
      lightgbm::lgb.train(
        params  = params,
        data    = dtrain,
        nrounds = grid$n_estimators[i],
        verbose = -1L
      )
    ))

    score <- if (!is.null(X_val) && !is.null(y_val)) {
      X_val_mat <- if (is.data.frame(X_val)) as.matrix(X_val) else X_val
      storage.mode(X_val_mat) <- "double"
      preds <- stats::predict(model, X_val_mat)
      .deviance(y_val, preds, objective, tweedie_variance_power)
    } else {
      0  # no validation -> first fit wins (n_trials should be 1)
    }

    if (score < best$score) {
      best <- list(score = score, model = model, params = params)
    }
  }

  best
}

# Per-objective deviance for hyperparameter scoring.
.deviance <- function(y, y_hat, objective, tweedie_power) {
  eps <- 1e-10
  y_hat <- pmax(y_hat, eps)
  if (objective == "regression") {
    return(mean((y - y_hat) ^ 2))
  }
  if (objective == "poisson") {
    safe_y <- pmax(y, eps)
    return(2 * mean(y * log(safe_y / y_hat) - (y - y_hat)))
  }
  if (objective == "tweedie") {
    p <- tweedie_power
    if (abs(p - 1) < 1e-9) return(mean((y - y_hat) ^ 2))
    term1 <- ifelse(y > 0, y ^ (2 - p) / ((1 - p) * (2 - p)), 0)
    term2 <- y * y_hat ^ (1 - p) / (1 - p)
    term3 <- y_hat ^ (2 - p) / (2 - p)
    dev <- ifelse(y > 0, term1 - term2 + term3, term3)
    return(2 * mean(dev))
  }
  if (objective == "gamma") {
    safe_y <- pmax(y, eps)
    return(2 * mean(-log(safe_y / y_hat) + (y - y_hat) / y_hat))
  }
  mean((y - y_hat) ^ 2)
}

# Build the monotone-constraints vector: +1 for each promo channel, 0 for
# every other feature column. Column order must match `feature_cols`.
build_monotone_constraints <- function(feature_cols, promo_vars) {
  ifelse(feature_cols %in% promo_vars, 1L, 0L)
}

# Baseline fitters (GLMM-Naive/Oracle, GLMMDist, PyMC-Hier-Naive/Oracle, hybrid)
# live in R/baselines.R as of Phase 4.
