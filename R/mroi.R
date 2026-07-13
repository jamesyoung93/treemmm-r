# Marginal-ROI (mROI) module: response-curve simulation, constrained budget
# reallocation, and mROI-vs-DGP benchmarking. Mirrors treemmm.mroi.simulator
# in the Python package.

#' Sweep allocation 0-150 percent of observed level and return the response curve
#'
#' For each multiplier in `sweep`, replace the channel's values in a reference
#' feature matrix with `multiplier * original_value`, predict the outcome via
#' the fitted model, and average across observations. Returns a data.table
#' with one row per multiplier (`pct_of_current`, `mean_outcome`).
#'
#' @param result A [treemmm_run()] result.
#' @param channel Name of the promotional channel to sweep.
#' @param sweep Numeric vector of allocation multipliers (default 0.0..1.5).
#' @param X_ref Optional reference matrix to evaluate at. Defaults to the
#'   last-fold test set's feature matrix from the pipeline result.
#' @return A data.table with columns `pct_of_current`, `mean_outcome`.
#' @export
simulate_response <- function(result,
                              channel,
                              sweep = seq(0, 1.5, by = 0.1),
                              X_ref = NULL) {
  if (!inherits(result, "pipeline_result")) {
    stop("`result` must be a treemmm_run() output.")
  }
  feat_cols <- result$prepared_data$feature_cols
  if (!channel %in% feat_cols) {
    stop("`channel` not found in pipeline feature_cols: ", channel)
  }

  if (is.null(X_ref)) {
    cs <- result$prepared_data$df
    X_ref <- as.matrix(cs[, feat_cols, with = FALSE])
    storage.mode(X_ref) <- "double"
  }

  orig_col <- X_ref[, channel]
  curve <- data.table::data.table(
    pct_of_current = sweep,
    mean_outcome   = NA_real_
  )

  for (k in seq_along(sweep)) {
    X_mod <- X_ref
    X_mod[, channel] <- orig_col * sweep[k]
    preds <- stats::predict(result$model, X_mod)
    curve$mean_outcome[k] <- mean(preds)
  }
  curve
}


#' Estimate marginal ROI (mROI) per channel
#'
#' Computes the endpoint-slope mROI for each channel: the change in mean
#' outcome between 100 percent and 150 percent of current allocation,
#' divided by the change in input. Returns a named numeric vector ordered
#' largest-first.
#'
#' @param result A [treemmm_run()] result.
#' @param channels Optional subset of channels. Defaults to all promo_vars
#'   in the pipeline's column spec.
#' @return A named numeric vector of mROI per channel.
#' @export
mroi_ranking <- function(result, channels = NULL) {
  if (is.null(channels)) {
    channels <- result$config$columns$promo_vars
  }
  rois <- numeric(length(channels))
  names(rois) <- channels
  X_ref <- as.matrix(result$prepared_data$df[, result$prepared_data$feature_cols,
                                             with = FALSE])
  storage.mode(X_ref) <- "double"
  for (ch in channels) {
    orig_col <- X_ref[, ch]
    # outcome at 100% and 150% allocation
    X100 <- X_ref
    X150 <- X_ref
    X150[, ch] <- orig_col * 1.5
    delta_outcome <- mean(stats::predict(result$model, X150) -
                          stats::predict(result$model, X100))
    delta_input <- mean(orig_col * 0.5)
    rois[ch] <- if (delta_input > 0) delta_outcome / delta_input else 0
  }
  sort(rois, decreasing = TRUE)
}


#' Reallocate a fixed budget across channels to maximize predicted outcome
#'
#' Simple coordinate ascent over aggregate channel totals. At each step, the
#' full source and destination columns are rescaled to move `step_frac` of the
#' source's current aggregate allocation. The total aggregate budget is held
#' constant, and iterations stop when no candidate shift improves the mean
#' predicted outcome.
#'
#' This function does not impose per-row or per-customer caps. Use
#' [reallocate()] when a cap-bounded additive landing plan is required.
#'
#' @param result A [treemmm_run()] result.
#' @param channels Channels eligible for reallocation. Defaults to `promo_vars`
#'   in the pipeline's column specification.
#' @param step_frac Fraction of current allocation moved per iteration.
#' @param max_iter Hard cap on coordinate-ascent iterations.
#' @return A list with `$allocation` (new per-channel total) and
#'   `$predicted_lift` (relative improvement vs current allocation).
#' @export
optimize_budget <- function(result,
                            channels = NULL,
                            step_frac = 0.1,
                            max_iter = 20L) {
  if (is.null(channels)) {
    channels <- result$config$columns$promo_vars
  }
  X_ref <- as.matrix(result$prepared_data$df[, result$prepared_data$feature_cols,
                                             with = FALSE])
  storage.mode(X_ref) <- "double"
  alloc <- vapply(channels, function(ch) sum(X_ref[, ch]), numeric(1L))
  baseline_pred <- mean(stats::predict(result$model, X_ref))

  for (iter in seq_len(max_iter)) {
    improved <- FALSE
    for (i in seq_along(channels)) {
      for (j in seq_along(channels)) {
        if (i == j) next
        # Move `step_frac` * alloc[i] from channel i to channel j.
        amount <- step_frac * alloc[i]
        if (amount <= 0) next
        scale_i <- (alloc[i] - amount) / alloc[i]
        scale_j <- if (alloc[j] > 0) (alloc[j] + amount) / alloc[j] else 1
        X_test <- X_ref
        X_test[, channels[i]] <- X_test[, channels[i]] * scale_i
        X_test[, channels[j]] <- X_test[, channels[j]] * scale_j
        new_pred <- mean(stats::predict(result$model, X_test))
        if (new_pred > baseline_pred * (1 + 1e-4)) {
          baseline_pred <- new_pred
          alloc[i] <- alloc[i] - amount
          alloc[j] <- alloc[j] + amount
          X_ref[, channels[i]] <- X_ref[, channels[i]] * scale_i
          X_ref[, channels[j]] <- X_ref[, channels[j]] * scale_j
          improved <- TRUE
          break
        }
      }
      if (improved) break
    }
    if (!improved) break
  }

  list(
    allocation     = alloc,
    predicted_lift = (baseline_pred / mean(stats::predict(result$model,
                       as.matrix(result$prepared_data$df[,
                         result$prepared_data$feature_cols, with = FALSE])))) - 1
  )
}


#' Benchmark model mROI against DGP ground-truth mROI
#'
#' Compares the model-derived mROI ranking (from [mroi_ranking()]) against
#' the DGP-derived mROI ranking (from the synthetic dataset's ground-truth
#' attribution shares). Returns Spearman rank correlation and direction
#' accuracy (fraction of channels where the model and DGP agree on the sign
#' of the marginal effect).
#'
#' @param result A [treemmm_run()] result.
#' @param dataset A `generated_dataset` (from any `generate_*_dataset()`).
#' @return A list with `$rank_correlation`, `$direction_accuracy`, and the
#'   underlying per-channel comparison table.
#' @export
mroi_benchmark <- function(result, dataset) {
  if (!inherits(dataset, "generated_dataset")) {
    stop("`dataset` must be a generated_dataset (from generate_*).")
  }
  promo <- dataset$columns$promo_vars
  model_mroi <- mroi_ranking(result, channels = promo)
  # DGP "true mROI" approximated by attribution shares scaled by mean weights
  cfg_shares <- dataset$ground_truth$attribution_shares
  true_shares <- vapply(promo,
    function(ch) if (is.null(cfg_shares[[ch]])) 0 else cfg_shares[[ch]],
    numeric(1L))
  names(true_shares) <- promo

  model_order <- names(sort(model_mroi, decreasing = TRUE))
  true_order  <- names(sort(true_shares, decreasing = TRUE))

  rho <- if (length(promo) >= 2L) {
    stats::cor(rank(model_mroi[promo]), rank(true_shares[promo]),
               method = "spearman")
  } else NA_real_

  direction <- mean(sign(model_mroi[promo]) == sign(true_shares[promo]))

  table <- data.table::data.table(
    channel        = promo,
    model_mroi     = as.numeric(model_mroi[promo]),
    true_share     = as.numeric(true_shares[promo])
  )
  list(rank_correlation   = rho,
       direction_accuracy = direction,
       table              = table,
       model_ranking      = model_order,
       true_ranking       = true_order)
}
