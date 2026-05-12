# Main pipeline orchestrator. Mirrors treemmm.pipeline.run() in the Python
# package. Six stages: ingest -> diagnostics -> configure -> train ->
# attribute -> report.

#' Run the TreeMMM pipeline on a panel dataset
#'
#' Orchestrates data preparation, distribution detection, rolling-origin
#' CV, LightGBM training with monotone constraints, SHAP attribution via
#' the link-function-aware decomposer, and aggregation into per-channel
#' attribution shares.
#'
#' Attribution is computed from the *last* CV fold's model. Performance
#' metrics in `$fold_metrics` are computed per fold on each fold's
#' held-out test set.
#'
#' @param df A `data.frame` or `data.table` panel: one row per
#'   (customer, period).
#' @param config A [run_config()] object.
#' @param output_dir Optional path. Reserved for writing CSV results
#'   (Phase 5 will populate; currently unused).
#' @return A `pipeline_result` list with fields:
#'   * `attribution_shares` — named list of per-feature shares summing to 1
#'   * `fold_metrics` — list of per-fold R-squared / WMAPE / MAE / n_test
#'   * `prepared_data` — output of `prepare_data()`
#'   * `model` — the last fold's fitted LightGBM model
#'   * `shap_result` — SHAP values + expected_value + link on the test set
#'   * `attribution` — the link-aware attribution matrix
#'   * `objective` — the resolved objective string
#' @export
treemmm_run <- function(df, config, output_dir = NULL) {
  if (!inherits(config, "run_config")) {
    stop("`config` must be a run_config() result.")
  }

  prepared <- prepare_data(df, config)
  df_p <- prepared$df
  cs <- config$columns

  splits <- get_splits(df_p,
                       time_col = cs$time_col,
                       n_folds = config$n_folds,
                       min_train_frac = config$min_train_frac)

  feature_cols <- prepared$feature_cols
  promo_vars <- cs$promo_vars
  outcome_col <- cs$outcome_col

  # Convert categorical features to integer codes so LightGBM accepts them.
  for (cv in cs$categorical_vars) {
    if (!is.numeric(df_p[[cv]])) {
      df_p[[cv]] <- as.integer(as.factor(df_p[[cv]])) - 1L
    }
  }

  monotone <- build_monotone_constraints(feature_cols, promo_vars)
  lgbm_objective <- .objective_to_lgbm(prepared$objective)

  fold_metrics <- vector("list", length(splits))
  last_fit <- NULL
  last_test_idx <- NULL

  for (k in seq_along(splits)) {
    sp <- splits[[k]]
    train_df <- df_p[sp$train_idx, ]
    test_df  <- df_p[sp$test_idx,  ]
    if (nrow(train_df) == 0L || nrow(test_df) == 0L) {
      fold_metrics[[k]] <- list(fold = k, r2 = NA, wmape = NA,
                                mae = NA, n_test = nrow(test_df))
      next
    }

    X_train <- as.matrix(train_df[, feature_cols, with = FALSE])
    X_test  <- as.matrix(test_df[,  feature_cols, with = FALSE])
    storage.mode(X_train) <- "double"
    storage.mode(X_test)  <- "double"
    y_train <- as.numeric(train_df[[outcome_col]])
    y_test  <- as.numeric(test_df[[outcome_col]])

    fit <- fit_lightgbm(
      X_train = X_train, y_train = y_train,
      X_val   = X_test,  y_val   = y_test,
      objective = lgbm_objective,
      tweedie_variance_power = config$tweedie_variance_power,
      monotone_constraints = monotone,
      n_trials = config$n_optuna_trials,
      random_state = config$random_state
    )

    preds <- stats::predict(fit$model, X_test)
    fold_metrics[[k]] <- .compute_fold_metrics(k, y_test, preds, nrow(test_df))

    last_fit <- fit
    last_test_idx <- sp$test_idx
  }

  if (is.null(last_fit)) {
    stop("No CV folds produced trainable splits. Check `min_train_frac` ",
         "or your panel's time coverage.")
  }

  # Attribution on the last fold's test set
  last_test_df <- df_p[last_test_idx, ]
  X_last <- as.matrix(last_test_df[, feature_cols, with = FALSE])
  storage.mode(X_last) <- "double"
  preds_last <- stats::predict(last_fit$model, X_last)
  shap_result <- compute_shap(last_fit$model, X_last, link = prepared$link)
  attribution <- decompose(shap_result, preds_last, link = prepared$link)
  shares <- global_attribution(attribution)

  structure(
    list(
      attribution_shares = shares,
      fold_metrics       = fold_metrics,
      prepared_data      = prepared,
      model              = last_fit$model,
      shap_result        = shap_result,
      attribution        = attribution,
      objective          = prepared$objective,
      output_dir         = output_dir
    ),
    class = "pipeline_result"
  )
}

# Internal: R-squared, WMAPE, MAE for one fold.
.compute_fold_metrics <- function(fold, y_true, y_pred, n_test) {
  y_true <- as.numeric(y_true)
  y_pred <- as.numeric(y_pred)
  ss_res <- sum((y_true - y_pred) ^ 2)
  ss_tot <- sum((y_true - mean(y_true)) ^ 2)
  r2 <- if (ss_tot > 0) 1 - ss_res / ss_tot else 0
  total_actual <- sum(abs(y_true))
  wmape <- if (total_actual > 0) sum(abs(y_true - y_pred)) / total_actual else 0
  mae <- mean(abs(y_true - y_pred))
  list(fold = fold, r2 = r2, wmape = wmape, mae = mae, n_test = n_test)
}
