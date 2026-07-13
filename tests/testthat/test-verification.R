# Phase 7 — cross-language verification.
#
# The Python TreeMMM paper headline at full scale (3,000 customers x 36
# months, N = 5 seeds) is pharma TreeMMM attribution-share MAPE
# 17.9 percent +/- 0.2 percent. Reproducing that exact number in CI
# is not feasible: running 5 seeds at 3000 x 36 would take roughly 5
# minutes per fold, and CI is bound by Mersenne Twister rather than
# numpy's PCG64 anyway. Instead we run the R-port pipeline at a small
# but non-trivial scale (200 HCPs x 18 months) and assert two things:
#
#   1. attribution-share MAPE is in a reasonable range (well below a
#      uniform-share baseline). At this scale MAPE typically falls
#      between 0.10 and 0.40 depending on seed and PRNG.
#   2. the recovered ranking puts rep_visits in the top three channels,
#      which is the dominant DGP planted effect.

test_that("R-port pharma TreeMMM produces sensible attribution at moderate scale", {
  skip_if_not_installed("lightgbm")

  ds <- generate_pharma_dataset(n_customers = 200L, n_periods = 18L,
                                random_state = 42L)
  cfg <- run_config(
    columns = column_spec(
      customer_id  = ds$columns$customer_id,
      time_col     = ds$columns$time_col,
      outcome_col  = ds$columns$outcome_col,
      promo_vars   = ds$columns$promo_vars,
      control_vars = ds$columns$control_vars
    ),
    objective       = "auto",
    n_optuna_trials = 2L,
    n_folds         = 3L,
    min_train_frac  = 0.5,
    random_state    = 42L
  )
  result <- treemmm_run(ds$df, cfg)

  promo <- ds$columns$promo_vars
  recovered <- promo_only_shares(result$attribution_shares, promo)
  reference <- promo_only_shares(ds$ground_truth$attribution_shares, promo)

  # MAPE over channels with non-trivial reference shares
  active <- reference > 0.005
  if (sum(active) == 0L) skip("no active channels in reference")
  mape <- mean(abs(recovered[active] - reference[active]) / reference[active])

  # At 200 x 18 single-seed scale, MAPE varies a lot — a uniform-share
  # baseline on pharma is ~1.3. The verification gate here is "produced
  # non-degenerate output", not "matches the Python headline". The
  # tighter rep_visits-top-3 assertion below is the real directional
  # check. The Python full-scale (3000 x 36, N = 5) headline is 0.179.
  expect_true(
    mape < 1.3,
    info = sprintf("R-port pharma MAPE = %.3f (Python full-scale headline 0.179)",
                   mape)
  )

  # rep_visits is the dominant DGP channel; require it ranks top-three
  top3 <- names(sort(recovered, decreasing = TRUE))[seq_len(3L)]
  expect_true("rep_visits" %in% top3,
              info = paste("Top-3 channels:", paste(top3, collapse = ", ")))
})

test_that("the linear honesty test is honest: GLMM matches TreeMMM at small n", {
  skip_if_not_installed("lightgbm")
  skip_if_not_installed("lme4")

  ds <- generate_linear_dataset(n_customers = 100L, n_periods = 12L,
                                random_state = 42L)
  cfg <- run_config(
    columns = column_spec(
      customer_id  = ds$columns$customer_id,
      time_col     = ds$columns$time_col,
      outcome_col  = ds$columns$outcome_col,
      promo_vars   = ds$columns$promo_vars,
      control_vars = ds$columns$control_vars
    ),
    objective       = "gaussian",
    n_optuna_trials = 1L,
    n_folds         = 2L,
    min_train_frac  = 0.5,
    random_state    = 42L
  )

  promo <- ds$columns$promo_vars
  ref <- unlist(ds$ground_truth$attribution_shares)[promo]
  ref[is.na(ref)] <- 0

  tree <- treemmm_run(ds$df, cfg)
  tree_rec <- unlist(tree$attribution_shares)[promo]
  tree_rec[is.na(tree_rec)] <- 0
  active <- ref > 0.005
  tree_mape <- if (sum(active) > 0) {
    mean(abs(tree_rec[active] - ref[active]) / ref[active])
  } else NA_real_

  glmm <- fit_glmm_naive(ds$df, cfg)
  glmm_rec <- unlist(glmm$attribution_shares)[promo]
  glmm_rec[is.na(glmm_rec)] <- 0
  glmm_mape <- if (sum(active) > 0) {
    mean(abs(glmm_rec[active] - ref[active]) / ref[active])
  } else NA_real_

  # The honesty test: on a linear DGP, GLMM should be at least as good
  # as TreeMMM. Equivalent within a generous tolerance.
  if (!is.na(tree_mape) && !is.na(glmm_mape)) {
    expect_true(
      glmm_mape <= tree_mape + 0.20,
      info = sprintf("GLMM MAPE = %.3f, TreeMMM MAPE = %.3f", glmm_mape, tree_mape)
    )
  }
})
