## TreeMMM R quickstart: synthetic pharma panel
##
## This script is the README demo. It is intentionally evidence-oriented:
## it checks whether TreeMMM recovers the dominant planted channels, finds
## planted interactions, and produces usable mROI / reallocation outputs.

suppressPackageStartupMessages(library(treemmm))

section <- function(title) {
  cat("\n", strrep("=", nchar(title)), "\n", title, "\n",
      strrep("=", nchar(title)), "\n", sep = "")
}

promo_mape <- function(recovered_shares, truth_shares, promo, min_share = 0.005) {
  recovered <- recovered_shares[promo]
  recovered[is.na(recovered)] <- 0
  truth <- truth_shares[promo]
  truth[is.na(truth)] <- 0

  recovered <- abs(recovered) / sum(abs(recovered))
  truth <- abs(truth) / sum(abs(truth))
  active <- truth > min_share
  100 * mean(abs(recovered[active] - truth[active]) / truth[active])
}

pair_key <- function(x) paste(sort(c(x$var1, x$var2)), collapse = " x ")

n_customers <- as.integer(Sys.getenv("TREEMMM_DEMO_CUSTOMERS", "500"))
n_periods <- as.integer(Sys.getenv("TREEMMM_DEMO_PERIODS", "24"))
seed <- as.integer(Sys.getenv("TREEMMM_DEMO_SEED", "42"))

section("Generate data")
cat(sprintf("Synthetic pharma panel: %d customers x %d periods, seed %d\n",
            n_customers, n_periods, seed))
ds <- generate_pharma_dataset(
  n_customers = n_customers,
  n_periods = n_periods,
  random_state = seed
)

config <- run_config(
  columns = column_spec(
    customer_id  = ds$columns$customer_id,
    time_col     = ds$columns$time_col,
    outcome_col  = ds$columns$outcome_col,
    promo_vars   = ds$columns$promo_vars,
    control_vars = ds$columns$control_vars
  ),
  objective = "auto"
)

section("Fit TreeMMM")
started <- Sys.time()
result <- treemmm_run(ds$df, config)
elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
cat(sprintf("Resolved objective: %s\n", result$objective))
cat(sprintf("Fit elapsed: %.1f seconds\n", elapsed))

promo <- ds$columns$promo_vars
truth <- unlist(ds$ground_truth$attribution_shares)
recovered <- unlist(result$attribution_shares)

share_table <- data.frame(
  channel = promo,
  truth_share = as.numeric(truth[promo]),
  model_share = as.numeric(recovered[promo]),
  row.names = NULL
)
share_table$model_share[is.na(share_table$model_share)] <- 0
share_table <- share_table[order(-share_table$model_share), ]
print(share_table, row.names = FALSE, digits = 3)

top_truth <- names(sort(truth[promo], decreasing = TRUE))[seq_len(3L)]
top_model <- share_table$channel[seq_len(3L)]
cat(sprintf("Promo-only attribution MAPE: %.1f%%\n",
            promo_mape(recovered, truth, promo)))
cat("Truth top 3: ", paste(top_truth, collapse = ", "), "\n", sep = "")
cat("Model top 3: ", paste(top_model, collapse = ", "), "\n", sep = "")
cat("Top-3 overlap: ", length(intersect(top_truth, top_model)), "/3\n", sep = "")

fold_metrics <- do.call(rbind, lapply(result$fold_metrics, as.data.frame))
cat(sprintf("Mean held-out R2: %.3f\n", mean(fold_metrics$r2, na.rm = TRUE)))
cat(sprintf("Mean held-out WMAPE: %.3f\n", mean(fold_metrics$wmape, na.rm = TRUE)))

section("Discover interactions")
hybrid <- fit_glmm_hybrid(ds$df, config, n_interactions = 3L)
discovered_pairs <- vapply(hybrid$discovered_interactions, pair_key, character(1L))
planted_pairs <- vapply(ds$ground_truth$interactions, pair_key, character(1L))
cat("Planted:    ", paste(planted_pairs, collapse = "; "), "\n", sep = "")
cat("Discovered: ", paste(discovered_pairs, collapse = "; "), "\n", sep = "")
cat("Hits:       ", length(intersect(planted_pairs, discovered_pairs)), "/",
    length(planted_pairs), "\n", sep = "")

section("Check support and mROI")
feat <- result$prepared_data$feature_cols
X <- as.data.frame(result$prepared_data$df[, feat, with = FALSE], check.names = FALSE)
check_idx <- seq_len(min(1000L, nrow(X)))
coverage <- coverage_check(X_train = X, X_simulated = X[check_idx, , drop = FALSE])
cat(sprintf("Training-row extrapolation fraction: %.3f\n",
            coverage$extrapolation_fraction))
cat(sprintf("Training-row exact-match fraction: %.3f\n",
            coverage$exact_match_fraction))
cat(sprintf("Training-row sparse-neighborhood fraction: %.3f\n",
            coverage$low_support_fraction))

mroi <- mroi_ranking(result, channels = promo)
cat("mROI ranking: ", paste(names(mroi), collapse = " > "), "\n", sep = "")
print(round(mroi, 3))

bench <- mroi_benchmark(result, ds)
cat(sprintf("mROI rank correlation vs attribution-share proxy: %.3f\n",
            bench$rank_correlation))
cat(sprintf("mROI direction accuracy: %.3f\n", bench$direction_accuracy))

section("Budget reallocation")
plan <- reallocate(result, X, budget_delta_pct = 25,
                   channel = "rep_visits", cap_percentile = 95)
cat(sprintf("+25%% rep_visits predicted incremental outcome: %.0f\n",
            plan$predicted_incremental_outcome))
cat(sprintf("+25%% rep_visits predicted lift: %.2f%%\n",
            plan$predicted_lift_pct))
cat(sprintf("Unallocatable fraction: %.3f\n",
            plan$diagnostics$unallocatable_fraction))

curve <- reallocate_curve(result, X, budget_deltas = c(10, 25, 50),
                          channel = "rep_visits", cap_percentile = 95)
print(curve$table, digits = 3)
cat(sprintf("Largest fully allocatable delta in this sweep: %.0f%%\n",
            curve$max_allocatable_delta))

section("Interpretation")
cat("* This quick demo is a capability/evidence tour, not the full benchmark.\n")
cat("* The key checks are top-channel recovery, interaction recovery, positive mROI,\n")
cat("  and a feasible budget reallocation plan inside observed support.\n")
cat("* For headline attribution accuracy, run inst/verify/benchmark_all_dgps.R.\n")
