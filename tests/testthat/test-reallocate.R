# Cap-bounded committed budget-increase simulation (reallocate + .waterfill).

# --------------------------------------------------------------------------- #
# .waterfill allocator (no model needed)
# --------------------------------------------------------------------------- #

test_that(".waterfill respects the cap and allocates the full budget", {
  current <- c(0, 1, 2, 5, 6, 8)
  cap <- 6
  total_headroom <- sum(pmax(cap - current, 0))  # 6+5+4+1+0+0 = 16
  budget_add <- 10                                # < headroom -> fully allocatable

  wf <- treemmm:::.waterfill(current, cap, budget_add)

  expect_equal(wf$unallocatable, 0)
  expect_equal(sum(wf$increment), budget_add)
  # below-cap cells are filled no higher than the cap
  below <- current < cap
  expect_true(all(wf$proposed[below] <= cap + 1e-9))
  # cells already at or above the cap keep their touches and get nothing
  expect_true(all(wf$increment[current >= cap] == 0))
  expect_true(all(wf$proposed[current >= cap] == current[current >= cap]))
  expect_equal(total_headroom, 16)
})

test_that(".waterfill reports unallocatable budget when headroom is exhausted", {
  current <- c(4, 5, 5, 6)
  cap <- 6
  total_headroom <- sum(pmax(cap - current, 0))  # 2+1+1+0 = 4
  budget_add <- 10                               # > headroom

  wf <- treemmm:::.waterfill(current, cap, budget_add)

  expect_true(all(wf$proposed == cap))
  expect_equal(wf$unallocatable, budget_add - total_headroom)
})

test_that(".waterfill with no headroom is a no-op", {
  current <- c(6, 7, 6)
  wf <- treemmm:::.waterfill(current, 6, 5)
  expect_true(all(wf$increment == 0))
  expect_true(all(wf$proposed == current))
  expect_equal(wf$unallocatable, 5)
})


# --------------------------------------------------------------------------- #
# reallocate() on a fitted pipeline
# --------------------------------------------------------------------------- #

test_that("reallocate plans a cap-bounded increase and predicts a lift", {
  skip_if_not_installed("lightgbm")
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
    objective = "gaussian", n_optuna_trials = 1L, n_folds = 3L,
    min_train_frac = 0.5, random_state = 42L
  )
  result <- treemmm_run(ds$df, cfg)
  ch <- ds$columns$promo_vars[1]

  plan <- reallocate(result, budget_delta_pct = 25, channel = ch,
                     cap_percentile = 95)

  expect_type(plan, "list")
  expect_equal(plan$channels, ch)
  expect_equal(plan$diagnostics$cap_percentile, 95)
  expect_true(ch %in% names(plan$diagnostics$caps))

  # the committed increment grows the channel and, under a monotone +1
  # constraint, cannot lower the predicted outcome
  expect_true(plan$proposed_aggregate[[ch]] >= plan$current_aggregate[[ch]])
  expect_true(plan$predicted_incremental_outcome >= -1e-6)

  # per-row landing plan
  expect_s3_class(plan$per_row, "data.table")
  expect_equal(nrow(plan$per_row), nrow(result$prepared_data$df))
  expect_true(all(c(ch, paste0(ch, "__current"), paste0(ch, "__increment"))
                  %in% names(plan$per_row)))

  # cap binding: capped cells get nothing and are never reduced; below-cap
  # cells are never pushed past the cap
  cap  <- plan$diagnostics$caps[[ch]]
  cur  <- plan$per_row[[paste0(ch, "__current")]]
  inc  <- plan$per_row[[paste0(ch, "__increment")]]
  prop <- plan$per_row[[ch]]
  expect_true(all(inc[cur >= cap] < 1e-9))
  expect_true(all(prop[cur >= cap] == cur[cur >= cap]))
  expect_true(all(prop[cur < cap] <= cap + 1e-9))

  # diagnostics are valid fractions
  for (f in c("at_cap_fraction", "top_decile_at_cap_fraction",
              "mid_tier_increment_fraction", "unchanged_fraction",
              "unallocatable_fraction")) {
    expect_true(plan$diagnostics[[f]] >= 0)
    expect_true(plan$diagnostics[[f]] <= 1)
  }
})

test_that("reallocate cap rises with the cap percentile", {
  skip_if_not_installed("lightgbm")
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
    objective = "gaussian", n_optuna_trials = 1L, n_folds = 3L,
    min_train_frac = 0.5, random_state = 42L
  )
  result <- treemmm_run(ds$df, cfg)
  ch <- ds$columns$promo_vars[1]

  caps <- vapply(c(90, 95, 98), function(p) {
    reallocate(result, 25, channel = ch, cap_percentile = p)$diagnostics$caps[[ch]]
  }, numeric(1L))
  expect_true(caps[1] <= caps[2])
  expect_true(caps[2] <= caps[3])
})

test_that("reallocate spreads an increment across multiple channels", {
  skip_if_not_installed("lightgbm")
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
    objective = "gaussian", n_optuna_trials = 1L, n_folds = 3L,
    min_train_frac = 0.5, random_state = 42L
  )
  result <- treemmm_run(ds$df, cfg)
  chs <- ds$columns$promo_vars[1:2]

  plan <- reallocate(result, budget_delta_pct = 25, channels = chs)
  expect_setequal(plan$channels, chs)
  for (ch in chs) {
    expect_true(ch %in% names(plan$diagnostics$caps))
    expect_true(plan$proposed_aggregate[[ch]] >= plan$current_aggregate[[ch]])
  }
  expect_true(plan$diagnostics$mid_tier_increment_fraction >= 0)
  expect_true(plan$diagnostics$mid_tier_increment_fraction <= 1)
})

test_that("reallocate errors on an unknown channel", {
  skip_if_not_installed("lightgbm")
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
    objective = "gaussian", n_optuna_trials = 1L, n_folds = 3L,
    min_train_frac = 0.5, random_state = 42L
  )
  result <- treemmm_run(ds$df, cfg)
  expect_error(reallocate(result, 25, channel = "does_not_exist"),
               "not found")
})
