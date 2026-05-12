# Phase 3 — pipeline end-to-end tests. Requires {lightgbm}.

test_that("treemmm_run produces a valid pipeline_result on the linear DGP", {
  skip_if_not_installed("lightgbm")
  ds <- generate_linear_dataset(n_customers = 40L, n_periods = 12L,
                                random_state = 42L)
  cfg <- run_config(
    columns = column_spec(
      customer_id = ds$columns$customer_id,
      time_col    = ds$columns$time_col,
      outcome_col = ds$columns$outcome_col,
      promo_vars  = ds$columns$promo_vars,
      control_vars = ds$columns$control_vars
    ),
    objective       = "gaussian",
    n_optuna_trials = 1L,
    n_folds         = 3L,
    min_train_frac  = 0.5,
    random_state    = 42L
  )

  result <- treemmm_run(ds$df, cfg)
  expect_s3_class(result, "pipeline_result")

  # Attribution shares sum to ~1 and are non-negative
  shares <- unlist(result$attribution_shares)
  expect_equal(sum(shares), 1.0, tolerance = 1e-6)
  expect_true(all(shares >= 0))

  # Promo channels are represented
  for (ch in ds$columns$promo_vars) {
    expect_true(ch %in% names(result$attribution_shares),
                info = paste("Missing channel:", ch))
  }

  # Fold metrics are computed
  expect_equal(length(result$fold_metrics), 3L)
  for (fm in result$fold_metrics) {
    expect_true("r2" %in% names(fm))
    expect_true("wmape" %in% names(fm))
  }
})

test_that("treemmm_run with auto objective detects poisson on pharma counts", {
  skip_if_not_installed("lightgbm")
  ds <- generate_pharma_dataset(n_customers = 40L, n_periods = 12L,
                                random_state = 42L)
  cfg <- run_config(
    columns = column_spec(
      customer_id = ds$columns$customer_id,
      time_col    = ds$columns$time_col,
      outcome_col = ds$columns$outcome_col,
      promo_vars  = ds$columns$promo_vars,
      control_vars = ds$columns$control_vars
    ),
    objective       = "auto",
    n_optuna_trials = 1L,
    n_folds         = 3L,
    min_train_frac  = 0.5,
    random_state    = 42L
  )
  result <- treemmm_run(ds$df, cfg)
  # Pharma outcome is NegBin counts — auto should pick poisson (closest
  # supported family in stock LightGBM).
  expect_equal(result$objective, "poisson")
})

test_that("diagnose_distribution covers the major cases", {
  expect_equal(diagnose_distribution(rpois(200, 3))$family, "poisson")
  expect_equal(diagnose_distribution(c(rep(0, 30), rgamma(170, 2, 0.5)))$family,
               "tweedie")
  expect_equal(diagnose_distribution(rnorm(100, 5, 2))$family, "gaussian")
})

test_that("get_splits returns the requested number of rolling-origin folds", {
  df <- data.frame(t = rep(1:24, 5),
                   y = stats::rnorm(120))
  splits <- get_splits(df, time_col = "t", n_folds = 4L,
                       min_train_frac = 0.5)
  expect_equal(length(splits), 4L)
  for (s in splits) {
    expect_true(length(s$train_idx) > 0L)
    expect_true(length(s$test_idx) > 0L)
    expect_true(all(s$train_times < min(s$test_times)))
  }
})
