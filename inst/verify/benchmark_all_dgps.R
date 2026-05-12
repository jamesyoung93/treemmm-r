#!/usr/bin/env Rscript
# Multi-seed verification: run all four DGPs at headline scale, compute
# attribution-share MAPE using the Python definition, report mean +/- SE.
#
# Python paper headline (paper/results/benchmark_summary.csv, N=5 seeds):
#   Pharma (NegBin)   17.9% +/- 0.2%
#   CPG (Tweedie)     22.5% +/- 0.3%
#   SaaS (ZI-Gamma)   16.7% +/- 0.2%
#   Linear (Gaussian)  0.4% +/- 0.1%

suppressPackageStartupMessages({ library(treemmm) })

cat("=== treemmm-r multi-seed verification ===\n")
cat("treemmm:", as.character(packageVersion("treemmm")), "\n")
cat("lightgbm:", as.character(packageVersion("lightgbm")), "\n\n")

# Python's attribution-share MAPE: promo-only renormalization, min_share filter
mape_python <- function(recovered_shares, truth_shares, promo, min_share = 0.005) {
  recv <- recovered_shares[promo]; recv[is.na(recv)] <- 0
  recv_n  <- abs(recv) / sum(abs(recv))
  tru_n   <- abs(truth_shares[promo]) / sum(abs(truth_shares[promo]))
  mask    <- tru_n > min_share
  100 * mean(abs(recv_n[mask] - tru_n[mask]) / tru_n[mask])
}

run_one <- function(gen_fn, scale, seed) {
  args <- c(scale, list(random_state = seed))
  ds <- do.call(gen_fn, args)
  cfg <- run_config(
    columns = column_spec(
      customer_id  = ds$columns$customer_id,
      time_col     = ds$columns$time_col,
      outcome_col  = ds$columns$outcome_col,
      promo_vars   = ds$columns$promo_vars,
      control_vars = ds$columns$control_vars
    ),
    objective = "auto"
  )
  t0 <- Sys.time()
  res <- treemmm_run(ds$df, cfg)
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  list(
    mape    = mape_python(unlist(res$attribution_shares),
                          unlist(ds$ground_truth$attribution_shares),
                          ds$columns$promo_vars),
    elapsed = elapsed
  )
}

dgps <- list(
  pharma = list(fn = generate_pharma_dataset,
                scale = list(n_customers = 3000, n_periods = 36),
                target = "17.9% +/- 0.2%"),
  cpg    = list(fn = generate_cpg_dataset,
                scale = list(n_customers = 3000, n_periods = 36),
                target = "22.5% +/- 0.3%"),
  saas   = list(fn = generate_saas_dataset,
                scale = list(n_customers = 3000, n_periods = 36),
                target = "16.7% +/- 0.2%"),
  linear = list(fn = generate_linear_dataset,
                scale = list(n_customers = 3000, n_periods = 36),
                target = " 0.4% +/- 0.1%")
)

seeds <- c(42L, 43L, 44L)
results <- list()

for (nm in names(dgps)) {
  cat(sprintf("--- %s (target: %s) ---\n", nm, dgps[[nm]]$target))
  mapes <- numeric(length(seeds))
  times <- numeric(length(seeds))
  for (i in seq_along(seeds)) {
    out <- tryCatch(
      run_one(dgps[[nm]]$fn, dgps[[nm]]$scale, seeds[i]),
      error = function(e) list(mape = NA_real_, elapsed = NA_real_, err = conditionMessage(e))
    )
    mapes[i] <- out$mape
    times[i] <- out$elapsed
    cat(sprintf("  seed=%d: MAPE = %5.1f%%   (%.1fs)\n",
                seeds[i], out$mape, out$elapsed))
    if (!is.null(out$err)) cat("    ERROR:", out$err, "\n")
  }
  m  <- mean(mapes, na.rm = TRUE)
  se <- sd(mapes, na.rm = TRUE) / sqrt(sum(!is.na(mapes)))
  cat(sprintf("  ==> %s: %.1f%% +/- %.1f%% (N=%d, mean %.0fs/run)\n\n",
              nm, m, se, sum(!is.na(mapes)), mean(times, na.rm = TRUE)))
  results[[nm]] <- list(mapes = mapes, mean = m, se = se,
                       times = times, target = dgps[[nm]]$target)
}

cat("=== SUMMARY ===\n")
cat(sprintf("%-8s | %-12s | %-12s\n", "DGP", "Python", "R (N=3)"))
cat(strrep("-", 38), "\n", sep = "")
for (nm in names(results)) {
  r <- results[[nm]]
  cat(sprintf("%-8s | %-12s | %4.1f%% +/- %.1f%%\n",
              nm, r$target, r$mean, r$se))
}

saveRDS(results, "C:/Users/Admin/research-stage/treemmm-r/inst/verify/benchmark_results.rds")
cat("\nResults saved.\n")
