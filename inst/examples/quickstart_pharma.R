## TreeMMM R Quickstart — Pharma Brand Demo
##
## Mirrors examples/quickstart_pharma.py from the Python implementation.
## Demonstrates the full pipeline on a synthetic pharma panel.
##
## NOTE: As of v0.2.1.9000 (Phase 1 scaffold), this script will throw
## `Not yet implemented` from every step. See ROADMAP.md for the phasing.
## When Phase 3 lands, this becomes a working end-to-end example.

library(treemmm)

# ---------------------------------------------------------------------
# Step 1: Generate the synthetic pharma DGP
# ---------------------------------------------------------------------
cat("Generating pharma dataset (500 HCPs x 24 months)...\n")
ds <- generate_pharma_dataset(
  n_customers  = 500L,
  n_periods    = 24L,
  random_state = 42L
)

# ---------------------------------------------------------------------
# Step 2: Configure the pipeline
# ---------------------------------------------------------------------
config <- run_config(
  columns = column_spec(
    customer_id  = "hcp_id",
    time_col     = "month",
    outcome_col  = "new_patients",
    promo_vars   = c("rep_visits", "dtc_advertising", "samples",
                     "peer_programs", "digital_impressions", "conference"),
    control_vars = c("seasonality", "market_index")
  ),
  objective = "auto"
)

# ---------------------------------------------------------------------
# Step 3: Run the pipeline
# ---------------------------------------------------------------------
result <- treemmm_run(ds$df, config)

# ---------------------------------------------------------------------
# Step 4: Show results
# ---------------------------------------------------------------------
cat("\nAttribution shares (fraction of total outcome):\n")
print(sort(result$attribution_shares, decreasing = TRUE))

cat("\nFold performance:\n")
print(result$fold_metrics)
