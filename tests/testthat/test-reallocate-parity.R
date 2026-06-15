# Cross-implementation parity: the R reallocate port must reproduce the Python
# treemmm.mroi outputs to float tolerance on identical inputs.
#
# The fixtures in tests/testthat/fixtures/ are produced by the Python package
# (data-raw/generate_parity_fixtures.py): a shared toy panel plus the outputs of
# reallocate() / reallocate_curve() on a deterministic linear-stub model. This
# test reads the same panel, re-runs the R implementation, and checks the
# numbers match. The algorithm is RNG-free and np.percentile == quantile(type=7),
# so agreement is exact to ~1e-12; we assert at 1e-8.

TOL <- 1e-8

# Shared input panel, read so R consumes byte-identical inputs to Python.
parity_df <- function() {
  inp <- data.table::fread(test_path("fixtures", "parity_input.csv"))
  df <- as.data.frame(inp[, c("rep_visits", "samples", "control")],
                      check.names = FALSE)
  rownames(df) <- inp$row_id
  df
}

parity_scalars <- function() {
  as.data.frame(data.table::fread(test_path("fixtures", "parity_scalars.csv")))
}

# Pull a single fixture scalar.
fx <- function(sc, scenario, key) {
  v <- sc$value[sc$scenario == scenario & sc$key == key]
  if (length(v) != 1L) stop("fixture lookup failed: ", scenario, "/", key)
  as.numeric(v)
}

# Extract the matching scalar from an R reallocation_plan by fixture key.
plan_value <- function(plan, key) {
  d <- plan$diagnostics
  if (startsWith(key, "cap__")) {
    return(d$caps[[sub("^cap__", "", key)]])
  }
  if (startsWith(key, "current_aggregate__")) {
    return(plan$current_aggregate[[sub("^current_aggregate__", "", key)]])
  }
  if (startsWith(key, "proposed_aggregate__")) {
    return(plan$proposed_aggregate[[sub("^proposed_aggregate__", "", key)]])
  }
  switch(key,
    predicted_outcome_current     = plan$predicted_outcome_current,
    predicted_outcome_proposed    = plan$predicted_outcome_proposed,
    predicted_incremental_outcome = plan$predicted_incremental_outcome,
    predicted_lift_pct            = plan$predicted_lift_pct,
    at_cap_fraction               = d$at_cap_fraction,
    top_decile_at_cap_fraction    = d$top_decile_at_cap_fraction,
    mid_tier_increment_fraction   = d$mid_tier_increment_fraction,
    unchanged_fraction            = d$unchanged_fraction,
    unallocatable_fraction        = d$unallocatable_fraction,
    stop("unknown key ", key)
  )
}

# Compare every scalar the fixture records for a scenario against the R plan.
expect_plan_matches_fixture <- function(plan, sc, scenario) {
  keys <- sc$key[sc$scenario == scenario]
  for (k in keys) {
    expect_equal(plan_value(plan, k), fx(sc, scenario, k),
                 tolerance = TOL, info = paste(scenario, k))
  }
}

test_that("parity: single-channel reallocate matches Python (scalars + per-row)", {
  df <- parity_df()
  sc <- parity_scalars()
  m <- linear_stub(list(rep_visits = 2.0, samples = 1.0), colnames(df))
  plan <- reallocate(m, df, budget_delta_pct = 25, channel = "rep_visits",
                     cap_percentile = 95)

  expect_plan_matches_fixture(plan, sc, "S1_single")

  pr <- as.data.frame(data.table::fread(test_path("fixtures", "parity_perrow.csv")))
  expect_equal(plan$per_row$row_id, pr$row_id)
  expect_equal(plan$per_row$rep_visits, pr$rep_visits, tolerance = TOL)
  expect_equal(plan$per_row$rep_visits__current, pr$rep_visits__current,
               tolerance = TOL)
  expect_equal(plan$per_row$rep_visits__increment, pr$rep_visits__increment,
               tolerance = TOL)
})

test_that("parity: multichannel reallocate matches Python", {
  df <- parity_df()
  sc <- parity_scalars()
  m <- linear_stub(list(rep_visits = 2.0, samples = 1.0), colnames(df))
  plan <- reallocate(m, df, budget_delta_pct = 25,
                     channels = c("rep_visits", "samples"), cap_percentile = 95)
  expect_plan_matches_fixture(plan, sc, "S2_multi")
})

test_that("parity: cap-percentile sensitivity matches Python", {
  df <- parity_df()
  sc <- parity_scalars()
  m <- linear_stub(list(rep_visits = 2.0, samples = 1.0), colnames(df))
  for (pct in c(90, 95, 98)) {
    plan <- reallocate(m, df, budget_delta_pct = 25, channel = "rep_visits",
                       cap_percentile = pct)
    expect_plan_matches_fixture(plan, sc, paste0("S3_cap", pct))
  }
})

# Compare an R curve table against the parity_curve.csv rows for a scenario.
expect_curve_matches_fixture <- function(curve, scenario) {
  fxc <- as.data.frame(data.table::fread(test_path("fixtures", "parity_curve.csv")))
  fxc <- fxc[fxc$scenario == scenario, ]
  tab <- curve$table
  expect_equal(nrow(tab), nrow(fxc))
  expect_equal(tab$budget_delta_pct, fxc$budget_delta_pct, tolerance = TOL)
  num_cols <- c("added_touches", "predicted_incremental_outcome",
                "predicted_lift_pct", "marginal_return_per_touch",
                "step_marginal_return", "mid_tier_increment_fraction",
                "at_cap_fraction", "unallocatable_fraction")
  for (col in num_cols) {
    expect_equal(tab[[col]], fxc[[col]], tolerance = TOL, info = paste(scenario, col))
  }
}

test_that("parity: curve with no cap binding matches Python", {
  df <- parity_df()
  sc <- parity_scalars()
  m <- linear_stub(list(rep_visits = 2.5), colnames(df))
  curve <- reallocate_curve(m, df, budget_deltas = c(5, 10, 20),
                            channel = "rep_visits")
  expect_curve_matches_fixture(curve, "S4_curve_nobind")
  expect_equal(curve$max_allocatable_delta,
               fx(sc, "S4_curve_nobind", "max_allocatable_delta"), tolerance = TOL)
})

test_that("parity: curve with cap binding matches Python", {
  df <- parity_df()
  sc <- parity_scalars()
  m <- linear_stub(list(rep_visits = 2.0), colnames(df))
  curve <- reallocate_curve(m, df, budget_deltas = c(10, 25, 50, 1000),
                            channel = "rep_visits")
  expect_curve_matches_fixture(curve, "S5_curve_bind")
  expect_equal(curve$max_allocatable_delta,
               fx(sc, "S5_curve_bind", "max_allocatable_delta"), tolerance = TOL)
})
