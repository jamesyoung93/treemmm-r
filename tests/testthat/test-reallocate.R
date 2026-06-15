# Cap-bounded budget reallocation (reallocate / reallocate_curve).
#
# Behavioural / property tests mirroring the Python suite in
# tests/test_budget_reallocation.py. Exact cross-implementation numbers are
# checked separately in test-reallocate-parity.R against shared fixtures.

# --------------------------------------------------------------------------- #
# water-fill allocator
# --------------------------------------------------------------------------- #

test_that("waterfill respects the cap and allocates the full budget", {
  current <- c(0, 1, 2, 5, 6, 8)
  cap <- 6
  total_headroom <- sum(pmax(cap - current, 0)) # 6+5+4+1+0+0 = 16
  budget_add <- 10 # < headroom -> fully allocatable

  wf <- treemmm:::.mroi_waterfill(current, cap, budget_add)

  expect_equal(total_headroom, 16)
  expect_equal(wf$unallocatable, 0)
  expect_equal(sum(wf$increment), budget_add)
  below <- current < cap
  expect_true(all(wf$proposed[below] <= cap + 1e-9))
  # cells already at or above the cap keep their touches and get nothing
  expect_true(all(wf$increment[current >= cap] == 0))
  expect_true(all(wf$proposed[current >= cap] == current[current >= cap]))
})

test_that("waterfill reports the overflow when headroom is exhausted", {
  current <- c(4, 5, 5, 6)
  cap <- 6
  total_headroom <- sum(pmax(cap - current, 0)) # 2+1+1+0 = 4
  budget_add <- 10 # > headroom

  wf <- treemmm:::.mroi_waterfill(current, cap, budget_add)

  expect_true(all(abs(wf$proposed - cap) < 1e-9))
  expect_equal(wf$unallocatable, budget_add - total_headroom)
})

test_that("waterfill is a no-op when there is no headroom", {
  current <- c(6, 7, 6)
  wf <- treemmm:::.mroi_waterfill(current, 6, 5)
  expect_true(all(wf$increment == 0))
  expect_true(all(wf$proposed == current))
  expect_equal(wf$unallocatable, 5)
})

# --------------------------------------------------------------------------- #
# reallocate(): single channel
# --------------------------------------------------------------------------- #

test_that("reallocate returns a plan and preserves the row index", {
  df <- toy_frame()
  m <- linear_stub(list(rep_visits = 2.0, samples = 1.0), colnames(df))
  plan <- reallocate(m, df, budget_delta_pct = 25, channel = "rep_visits")

  expect_s3_class(plan, "reallocation_plan")
  expect_equal(plan$channels, "rep_visits")
  expect_equal(plan$per_row$row_id, rownames(df))
  expect_true("rep_visits__increment" %in% names(plan$per_row))
})

test_that("capped cells receive zero increment and stay inside support", {
  df <- toy_frame()
  m <- linear_stub(list(rep_visits = 2.0, samples = 1.0), colnames(df))
  plan <- reallocate(m, df, budget_delta_pct = 25, channel = "rep_visits",
                     cap_percentile = 95)

  cap <- plan$diagnostics$caps$rep_visits
  inc <- plan$per_row$rep_visits__increment
  cur <- plan$per_row$rep_visits__current
  proposed <- plan$per_row$rep_visits
  expect_true(all(inc[cur >= cap] == 0))
  below <- cur < cap
  expect_true(all(proposed[below] <= cap + 1e-9))
  expect_true(all(proposed[cur >= cap] == cur[cur >= cap]))
})

test_that("aggregate and predicted outcome increase monotonically", {
  df <- toy_frame()
  m <- linear_stub(list(rep_visits = 2.0, samples = 1.0), colnames(df))

  lifts <- numeric(0)
  for (delta in c(10, 25, 50)) {
    plan <- reallocate(m, df, budget_delta_pct = delta, channel = "rep_visits")
    expect_true(plan$proposed_aggregate$rep_visits >= plan$current_aggregate$rep_visits)
    expect_true(plan$predicted_incremental_outcome > 0)
    lifts <- c(lifts, plan$predicted_lift_pct)
  }
  expect_true(lifts[1] < lifts[2] && lifts[2] < lifts[3])
})

test_that("higher cap percentile lifts the cap and frees frozen cells", {
  df <- toy_frame()
  m <- linear_stub(list(rep_visits = 2.0, samples = 1.0), colnames(df))

  caps <- list()
  at_cap <- list()
  for (pct in c(90, 95, 98)) {
    plan <- reallocate(m, df, budget_delta_pct = 25, channel = "rep_visits",
                       cap_percentile = pct)
    caps[[as.character(pct)]] <- plan$diagnostics$caps$rep_visits
    at_cap[[as.character(pct)]] <- plan$diagnostics$at_cap_fraction
  }
  expect_true(caps[["90"]] <= caps[["95"]] && caps[["95"]] <= caps[["98"]])
  expect_true(at_cap[["90"]] >= at_cap[["95"]] && at_cap[["95"]] >= at_cap[["98"]])
})

# --------------------------------------------------------------------------- #
# reallocate(): channel selection
# --------------------------------------------------------------------------- #

test_that("reallocate infers channels from monotone constraints", {
  df <- toy_frame()
  m <- linear_stub(list(rep_visits = 2.0, samples = 1.0), colnames(df))
  plan <- reallocate(m, df, budget_delta_pct = 25) # no channel hint
  expect_setequal(plan$channels, c("rep_visits", "samples"))
})

test_that("reallocate errors when channels cannot be inferred", {
  df <- toy_frame()
  expect_error(
    reallocate(bare_stub("rep_visits"), df, budget_delta_pct = 25),
    "infer promo channels"
  )
})

test_that("reallocate errors on an unknown channel", {
  df <- toy_frame()
  m <- linear_stub(list(rep_visits = 2.0), colnames(df))
  expect_error(
    reallocate(m, df, budget_delta_pct = 25, channel = "does_not_exist"),
    "not found in X"
  )
})

test_that("multichannel reallocation pools diagnostics across channels", {
  df <- toy_frame()
  m <- linear_stub(list(rep_visits = 2.0, samples = 1.0), colnames(df))
  plan <- reallocate(m, df, budget_delta_pct = 25,
                     channels = c("rep_visits", "samples"))

  expect_setequal(plan$channels, c("rep_visits", "samples"))
  for (ch in c("rep_visits", "samples")) {
    expect_true(plan$proposed_aggregate[[ch]] >= plan$current_aggregate[[ch]])
    expect_true(paste0(ch, "__increment") %in% names(plan$per_row))
  }
  expect_true(plan$diagnostics$mid_tier_increment_fraction >= 0 &&
                plan$diagnostics$mid_tier_increment_fraction <= 1)
  expect_true(plan$predicted_incremental_outcome > 0)
})

# --------------------------------------------------------------------------- #
# reallocate_curve(): decision curve across budget levels
# --------------------------------------------------------------------------- #

test_that("curve table has one row per sorted unique level", {
  df <- toy_frame()
  m <- linear_stub(list(rep_visits = 2.0), colnames(df))
  curve <- reallocate_curve(m, df, budget_deltas = c(25, 10, 25, 50),
                            channel = "rep_visits")

  expect_s3_class(curve, "reallocation_curve")
  expect_equal(curve$budget_deltas, c(10, 25, 50))
  expect_equal(curve$table$budget_delta_pct, c(10, 25, 50))
  expect_equal(nrow(curve$table), 3L)
  expect_setequal(names(curve$plans), c("10", "25", "50"))
})

test_that("curve touches and outcome are monotone non-decreasing", {
  df <- toy_frame()
  m <- linear_stub(list(rep_visits = 2.0, samples = 1.0), colnames(df))
  curve <- reallocate_curve(m, df, budget_deltas = c(10, 25, 50, 100),
                            channel = "rep_visits")

  expect_true(all(diff(curve$table$added_touches) >= -1e-9))
  expect_true(all(diff(curve$table$predicted_incremental_outcome) >= -1e-9))
  expect_true(all(curve$table$predicted_lift_pct >= -1e-9))
})

test_that("curve marginal return equals the linear weight with no cap binding", {
  df <- toy_frame()
  weight <- 2.5
  m <- linear_stub(list(rep_visits = weight), colnames(df))
  curve <- reallocate_curve(m, df, budget_deltas = c(5, 10, 20),
                            channel = "rep_visits")

  expect_true(all(curve$table$unallocatable_fraction < 1e-9))
  expect_true(all(diff(curve$table$added_touches) > 0))
  expect_equal(curve$table$marginal_return_per_touch, rep(weight, 3))
  expect_equal(curve$table$step_marginal_return, rep(weight, 3))
})

test_that("curve unallocatable fraction is monotone non-decreasing", {
  df <- toy_frame()
  m <- linear_stub(list(rep_visits = 2.0), colnames(df))
  curve <- reallocate_curve(m, df, budget_deltas = c(10, 50, 200, 1000),
                            channel = "rep_visits")
  frac <- curve$table$unallocatable_fraction
  expect_true(all(diff(frac) >= -1e-9))
  expect_true(frac[length(frac)] > 0) # the huge level overflows the cap
})

test_that("curve max_allocatable_delta matches the diagnostics", {
  df <- toy_frame()
  m <- linear_stub(list(rep_visits = 2.0), colnames(df))
  curve <- reallocate_curve(m, df, budget_deltas = c(10, 25, 50, 1000),
                            channel = "rep_visits")

  allocatable <- curve$budget_deltas[vapply(
    curve$budget_deltas,
    function(d) {
      key <- treemmm:::.mroi_delta_key(d)
      curve$plans[[key]]$diagnostics$unallocatable_fraction <= 1e-6
    },
    logical(1)
  )]
  expected <- if (length(allocatable) > 0) max(allocatable) else NA_real_
  expect_equal(curve$max_allocatable_delta, expected)
  expect_false(is.na(curve$max_allocatable_delta))
  expect_true(curve$max_allocatable_delta < 1000)
})

test_that("curve frontier is NA when there is no headroom", {
  df <- data.frame(rep_visits = rep(5.0, 50), control = rep(0.0, 50))
  rownames(df) <- sprintf("row%02d", seq_len(50) - 1L)
  m <- linear_stub(list(rep_visits = 1.0), colnames(df))
  curve <- reallocate_curve(m, df, budget_deltas = c(10, 50),
                            channel = "rep_visits")

  expect_true(is.na(curve$max_allocatable_delta))
  expect_true(all(curve$table$unallocatable_fraction > 0))
  expect_true(all(abs(curve$table$added_touches) < 1e-9))
})

test_that("curve retains the per-level per-customer plans", {
  df <- toy_frame()
  m <- linear_stub(list(rep_visits = 2.0, samples = 1.0), colnames(df))
  curve <- reallocate_curve(m, df, budget_deltas = c(10, 50),
                            channels = c("rep_visits", "samples"))

  for (delta in c(10, 50)) {
    plan <- curve$plans[[as.character(delta)]]
    expect_s3_class(plan, "reallocation_plan")
    expect_equal(plan$budget_delta_pct, delta)
    expect_equal(plan$per_row$row_id, rownames(df))
    expect_true("rep_visits__increment" %in% names(plan$per_row))
  }
  expect_equal(curve$channels, curve$plans[["10"]]$channels)
})

test_that("curve raises on empty deltas", {
  df <- toy_frame()
  m <- linear_stub(list(rep_visits = 2.0), colnames(df))
  expect_error(
    reallocate_curve(m, df, budget_deltas = numeric(0), channel = "rep_visits"),
    "at least one level"
  )
})

test_that("curve with a single level is valid", {
  df <- toy_frame()
  m <- linear_stub(list(rep_visits = 2.0), colnames(df))
  curve <- reallocate_curve(m, df, budget_deltas = 25, channel = "rep_visits")

  expect_equal(curve$budget_deltas, 25)
  expect_equal(nrow(curve$table), 1L)
  # first row has no level below it: step return is the level's own marginal
  expect_equal(curve$table$step_marginal_return[1],
               curve$table$marginal_return_per_touch[1])
})

# --------------------------------------------------------------------------- #
# integration: constrained LightGBM on a pharma panel
# --------------------------------------------------------------------------- #

test_that("reallocate works end-to-end on a fitted pipeline_result", {
  skip_on_cran()
  skip_if_not_installed("lightgbm")

  ds <- generate_pharma_dataset(n_customers = 120L, n_periods = 12L,
                                random_state = 42L)
  cfg <- run_config(
    columns = column_spec(
      customer_id  = ds$columns$customer_id,
      time_col     = ds$columns$time_col,
      outcome_col  = ds$columns$outcome_col,
      promo_vars   = ds$columns$promo_vars,
      control_vars = ds$columns$control_vars
    ),
    objective = "auto", random_state = 42L
  )
  result <- treemmm_run(ds$df, cfg)

  feat <- result$prepared_data$feature_cols
  X <- as.data.frame(result$prepared_data$df[, feat, with = FALSE],
                     check.names = FALSE)
  plan <- reallocate(result, X, budget_delta_pct = 25, channel = "rep_visits",
                     cap_percentile = 95)

  # monotone-constrained channel: more touches cannot lower predicted outcome
  expect_true(plan$predicted_incremental_outcome >= 0)
  diag <- plan$diagnostics
  expect_equal(diag$unallocatable_fraction, 0, tolerance = 1e-6)
  expect_true(diag$at_cap_fraction >= 0 && diag$at_cap_fraction <= 0.5)
  expect_true(diag$mid_tier_increment_fraction > 0)
  expect_equal(diag$unchanged_fraction, diag$at_cap_fraction, tolerance = 1e-6)
})
