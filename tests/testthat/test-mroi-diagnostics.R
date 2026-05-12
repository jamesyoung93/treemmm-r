# Phase 5 — mROI + diagnostics + hybrid tests.

test_that("simulate_response produces a monotonic-ish curve on the linear DGP", {
  skip_if_not_installed("lightgbm")
  ds <- generate_linear_dataset(n_customers = 40L, n_periods = 10L,
                                random_state = 42L)
  cfg <- run_config(
    columns = column_spec(
      customer_id  = ds$columns$customer_id,
      time_col     = ds$columns$time_col,
      outcome_col  = ds$columns$outcome_col,
      promo_vars   = ds$columns$promo_vars,
      control_vars = ds$columns$control_vars
    ),
    objective = "gaussian", n_optuna_trials = 1L, n_folds = 3L,
    min_train_frac = 0.5, random_state = 42L
  )
  result <- treemmm_run(ds$df, cfg)
  curve <- simulate_response(result, "channel_a",
                             sweep = seq(0, 1.5, by = 0.5))
  expect_s3_class(curve, "data.table")
  expect_equal(nrow(curve), 4L)
  # Monotone-constrained channel: outcome at 1.5 >= outcome at 0
  expect_true(tail(curve$mean_outcome, 1) >= head(curve$mean_outcome, 1))
})

test_that("variation_decomposition splits into within and between shares", {
  ds <- generate_pharma_dataset(n_customers = 30L, n_periods = 10L,
                                random_state = 42L)
  vd <- variation_decomposition(
    ds$df,
    unit_col     = "customer_id",
    feature_cols = ds$columns$promo_vars
  )
  expect_s3_class(vd, "data.table")
  expect_setequal(vd$feature, ds$columns$promo_vars)
  # within + between should sum to 1 (when total variance > 0)
  for (k in seq_len(nrow(vd))) {
    if (vd$within_share[k] + vd$between_share[k] > 0) {
      expect_equal(vd$within_share[k] + vd$between_share[k], 1,
                   tolerance = 1e-6)
    }
  }
})

test_that("tree_ess_per_param diagnostic labels match thresholds", {
  expect_equal(tree_ess_per_param(100000, 100L, 4L)$diagnostic, "adequate")
  expect_equal(tree_ess_per_param(160L,   100L, 4L)$diagnostic, "weak")
  expect_equal(tree_ess_per_param(10L,    100L, 4L)$diagnostic, "insufficient")
})

test_that("coverage_check reports an extrapolation_fraction in [0, 1]", {
  Xt <- matrix(stats::rnorm(200), ncol = 4L)
  Xs <- matrix(stats::rnorm(20),  ncol = 4L)
  cc <- coverage_check(Xt, Xs, radius = 1.5, min_neighbors = 5L)
  expect_true(cc$extrapolation_fraction >= 0)
  expect_true(cc$extrapolation_fraction <= 1)
  expect_equal(length(cc$counts), 5L)
})

test_that("shap_sign_audit reports one row per channel", {
  # Synthetic SHAP-like matrix.
  shap_result <- list(
    shap_values = matrix(stats::rnorm(60), ncol = 3L,
                         dimnames = list(NULL, c("a", "b", "c"))),
    expected_value = 0,
    link = "identity"
  )
  audit <- shap_sign_audit(shap_result)
  expect_equal(nrow(audit), 3L)
  expect_setequal(audit$channel, c("a", "b", "c"))
  expect_true(all(audit$dominant_sign %in% c("positive", "negative", "mixed")))
})

test_that("fit_glmm_hybrid discovers interactions and refits a GLMM", {
  skip_if_not_installed("lightgbm")
  skip_if_not_installed("lme4")
  ds <- generate_pharma_dataset(n_customers = 30L, n_periods = 10L,
                                random_state = 42L)
  cfg <- run_config(
    columns = column_spec(
      customer_id  = ds$columns$customer_id,
      time_col     = ds$columns$time_col,
      outcome_col  = ds$columns$outcome_col,
      promo_vars   = ds$columns$promo_vars,
      control_vars = ds$columns$control_vars
    ),
    objective    = "auto",
    random_state = 42L
  )
  result <- fit_glmm_hybrid(ds$df, cfg, n_interactions = 2L)
  expect_equal(length(result$discovered_interactions), 2L)
  expect_true(!is.null(result$model))
})
