# Phase 4 — baseline model tests.

test_that("fit_glmm_naive runs on the linear DGP and returns valid shares", {
  skip_if_not_installed("lme4")
  ds <- generate_linear_dataset(n_customers = 30L, n_periods = 10L,
                                random_state = 42L)
  cfg <- run_config(
    columns = column_spec(
      customer_id = ds$columns$customer_id,
      time_col    = ds$columns$time_col,
      outcome_col = ds$columns$outcome_col,
      promo_vars  = ds$columns$promo_vars,
      control_vars = ds$columns$control_vars
    ),
    objective    = "gaussian",
    random_state = 42L
  )
  result <- fit_glmm_naive(ds$df, cfg)

  expect_true(!is.null(result$model))
  shares <- unlist(result$attribution_shares)
  expect_true(all(shares >= -1e-9))
  # promo + control + base shares should be in [0, 1]
  expect_true(max(shares) <= 1 + 1e-6)
  # Sum should be approximately 1 (modulo base = 0 here)
  expect_equal(sum(shares), 1.0, tolerance = 1e-6)
})

test_that("fit_glmm_oracle accepts planted interactions", {
  skip_if_not_installed("lme4")
  ds <- generate_pharma_dataset(n_customers = 30L, n_periods = 10L,
                                random_state = 42L)
  cfg <- run_config(
    columns = column_spec(
      customer_id = ds$columns$customer_id,
      time_col    = ds$columns$time_col,
      outcome_col = ds$columns$outcome_col,
      promo_vars  = ds$columns$promo_vars,
      control_vars = ds$columns$control_vars
    ),
    objective    = "auto",
    random_state = 42L
  )
  result <- fit_glmm_oracle(ds$df, cfg, ds$ground_truth$interactions)
  expect_true(!is.null(result$model))
  expect_equal(length(result$planted_interactions),
               length(ds$ground_truth$interactions))
})

test_that("fit_glmm_distributional picks the right family per objective", {
  ds_lin <- generate_linear_dataset(n_customers = 30L, n_periods = 10L,
                                    random_state = 42L)
  cfg_lin <- run_config(
    columns = column_spec(
      customer_id  = ds_lin$columns$customer_id,
      time_col     = ds_lin$columns$time_col,
      outcome_col  = ds_lin$columns$outcome_col,
      promo_vars   = ds_lin$columns$promo_vars,
      control_vars = ds_lin$columns$control_vars
    ),
    objective    = "gaussian",
    random_state = 42L
  )
  r_lin <- fit_glmm_distributional(ds_lin$df, cfg_lin)
  expect_equal(r_lin$family$family, "gaussian")

  ds_ph <- generate_pharma_dataset(n_customers = 30L, n_periods = 10L,
                                   random_state = 42L)
  cfg_ph <- run_config(
    columns = column_spec(
      customer_id  = ds_ph$columns$customer_id,
      time_col     = ds_ph$columns$time_col,
      outcome_col  = ds_ph$columns$outcome_col,
      promo_vars   = ds_ph$columns$promo_vars,
      control_vars = ds_ph$columns$control_vars
    ),
    objective    = "auto",
    random_state = 42L
  )
  r_ph <- fit_glmm_distributional(ds_ph$df, cfg_ph)
  expect_equal(r_ph$family$family, "poisson")
})

test_that("Bayesian baselines fail gracefully when brms is missing", {
  if (requireNamespace("brms", quietly = TRUE)) {
    skip("brms is installed — graceful-failure test does not apply.")
  }
  ds <- generate_linear_dataset(n_customers = 10L, n_periods = 4L,
                                random_state = 42L)
  cfg <- run_config(
    columns = column_spec(
      customer_id  = ds$columns$customer_id,
      time_col     = ds$columns$time_col,
      outcome_col  = ds$columns$outcome_col,
      promo_vars   = ds$columns$promo_vars,
      control_vars = ds$columns$control_vars
    ),
    objective    = "gaussian",
    random_state = 42L
  )
  expect_error(fit_bayesian_hier_naive(ds$df, cfg), "Requires 'brms'")
})

test_that("hybrid GLMM stub points at Phase 5", {
  expect_error(fit_glmm_hybrid(data.frame(), list()),
               "Not yet implemented \\(Phase 5\\)")
})
