# Marginal-ROI module. Mirrors treemmm.mroi in the Python package.
# TODO Phase 5: implement response curves + constrained reallocation optimizer.

# simulate_response sweeps allocation from 0% to 150% of observed levels per
# channel and returns model-predicted outcomes at each step.
# TODO Phase 5.
simulate_response <- function(result, channel, sweep_grid = seq(0, 1.5, by = 0.05)) {
  stop("Not yet implemented (Phase 5). See ROADMAP.md.")
}

# optimize_budget reallocates total spend across channels under per-customer
# min/max constraints to maximize predicted outcome.
# TODO Phase 5.
optimize_budget <- function(result,
                            total_budget,
                            per_customer_min = 0,
                            per_customer_max = NULL) {
  stop("Not yet implemented (Phase 5). See ROADMAP.md.")
}

# mroi_benchmark compares model-derived mROI rankings against DGP ground-truth
# mROI for synthetic benchmarks.
# TODO Phase 5.
mroi_benchmark <- function(result, dataset) {
  stop("Not yet implemented (Phase 5). See ROADMAP.md.")
}
