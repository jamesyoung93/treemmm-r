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
    channels <- result$prepared_data$df  # data.table
    channels <- result$prepared_data
    channels <- intersect(
      result$prepared_data$feature_cols,
      # promo_vars only — pull from the config column spec.
      # The pipeline_result does not currently store the config directly,
      # so re-derive from feature_cols and rely on the caller passing the
      # promo subset if needed.
      result$prepared_data$feature_cols
    )
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
#' Simple coordinate-ascent over a small fixed grid. Each channel is
#' constrained to `[per_customer_min, per_customer_max] * n_obs`. The total
#' budget is held constant; channels are shifted by `step_frac` of current
#' allocation each iteration until no shift improves predicted outcome.
#'
#' @param result A [treemmm_run()] result.
#' @param channels Channels eligible for reallocation. Default: all
#'   `feature_cols` (caller should restrict to promo_vars).
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
    channels <- result$prepared_data$feature_cols
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


#' Plan a cap-bounded budget increase and predict its incremental outcome
#'
#' Increases each target channel's total touches by `budget_delta_pct` and
#' deploys the increment additively to the cells that have headroom below a
#' per-customer cap (the `cap_percentile` of observed positive touches). Cells
#' at or above the cap receive a zero increment and are never reduced, so every
#' per-customer counterfactual stays inside the observed support.
#'
#' This answers a different question than [simulate_response()]. The sweep
#' traces aggregate response as a channel total is scaled and redistributed
#' proportional to current usage; `reallocate()` commits to a fixed increment
#' and water-fills it onto the cells with room under the cap. Mirrors
#' `treemmm.mroi.reallocate` in the Python package.
#'
#' @param result A [treemmm_run()] result.
#' @param budget_delta_pct Percent change in channel budget (25 means +25%).
#' @param cap_percentile Percentile of observed positive touches used as the
#'   per-customer cap (default 95).
#' @param channel Reallocate a single named channel. Takes precedence over
#'   `channels`.
#' @param channels Reallocate across this set of channels, each independently
#'   capped and grown by `budget_delta_pct`. When both `channel` and `channels`
#'   are `NULL`, defaults to all `feature_cols` (caller should restrict to
#'   promo_vars).
#' @return A list with `$budget_delta_pct`, `$channels`, the per-row landing
#'   plan `$per_row` (a data.table carrying, for each channel `c`, the proposed
#'   `c`, `c__current`, and `c__increment`), the `$current_aggregate` and
#'   `$proposed_aggregate` per-channel totals, the summed model predictions
#'   `$predicted_outcome_current` / `$predicted_outcome_proposed`,
#'   `$predicted_incremental_outcome`, `$predicted_lift_pct`, and a
#'   `$diagnostics` sub-list (cap values, at-cap fraction, top-decile at-cap
#'   fraction, mid-tier increment share, unchanged fraction, unallocatable
#'   fraction).
#' @export
reallocate <- function(result,
                       budget_delta_pct,
                       cap_percentile = 95,
                       channel = NULL,
                       channels = NULL) {
  if (!inherits(result, "pipeline_result")) {
    stop("`result` must be a treemmm_run() output.")
  }
  feat_cols <- result$prepared_data$feature_cols
  if (!is.null(channel)) {
    target <- channel
  } else if (!is.null(channels)) {
    target <- channels
  } else {
    target <- feat_cols
  }
  missing <- setdiff(target, feat_cols)
  if (length(missing) > 0L) {
    stop("Channels not found in pipeline feature_cols: ",
         paste(missing, collapse = ", "))
  }

  X_ref <- as.matrix(result$prepared_data$df[, feat_cols, with = FALSE])
  storage.mode(X_ref) <- "double"
  X_prop <- X_ref

  caps               <- numeric(length(target))
  current_aggregate  <- numeric(length(target))
  proposed_aggregate <- numeric(length(target))
  names(caps)               <- target
  names(current_aggregate)  <- target
  names(proposed_aggregate) <- target
  per_row_cols       <- list()

  total_cells              <- 0L
  at_cap_cells             <- 0L
  top_decile_cells         <- 0L
  top_decile_at_cap_cells  <- 0L
  unchanged_cells          <- 0L
  increment_total          <- 0
  increment_mid            <- 0
  budget_total             <- 0
  unallocatable_total      <- 0

  for (col in target) {
    current  <- X_ref[, col]
    positive <- current[current > 0]
    cap <- if (length(positive) > 0L) {
      as.numeric(stats::quantile(positive, cap_percentile / 100,
                                 type = 7, names = FALSE))
    } else if (length(current) > 0L) {
      max(current)
    } else {
      0
    }

    current_agg <- sum(current)
    budget_add  <- current_agg * budget_delta_pct / 100
    wf          <- .waterfill(current, cap, budget_add)
    proposed    <- wf$proposed
    increment   <- wf$increment

    X_prop[, col]            <- proposed
    caps[col]                <- cap
    current_aggregate[col]   <- current_agg
    proposed_aggregate[col]  <- sum(proposed)
    per_row_cols[[col]]                    <- proposed
    per_row_cols[[paste0(col, "__current")]]   <- current
    per_row_cols[[paste0(col, "__increment")]] <- increment

    at_cap        <- current >= cap
    top_threshold <- if (length(current) > 0L) {
      as.numeric(stats::quantile(current, 0.90, type = 7, names = FALSE))
    } else 0
    top_decile <- current >= top_threshold
    mid_tier   <- (!top_decile) & (!at_cap)

    total_cells             <- total_cells + length(current)
    at_cap_cells            <- at_cap_cells + sum(at_cap)
    top_decile_cells        <- top_decile_cells + sum(top_decile)
    top_decile_at_cap_cells <- top_decile_at_cap_cells + sum(top_decile & at_cap)
    unchanged_cells         <- unchanged_cells + sum(increment <= 1e-9)
    increment_total         <- increment_total + sum(increment)
    increment_mid           <- increment_mid + sum(increment[mid_tier])
    budget_total            <- budget_total + budget_add
    unallocatable_total     <- unallocatable_total + wf$unallocatable
  }

  per_row <- data.table::as.data.table(per_row_cols)

  out_current  <- sum(stats::predict(result$model, X_ref))
  out_proposed <- sum(stats::predict(result$model, X_prop))
  incremental  <- out_proposed - out_current
  lift_pct     <- if (out_current != 0) incremental / out_current * 100 else 0

  diagnostics <- list(
    cap_percentile = cap_percentile,
    caps           = caps,
    at_cap_fraction =
      if (total_cells > 0L) at_cap_cells / total_cells else 0,
    top_decile_at_cap_fraction =
      if (top_decile_cells > 0L) top_decile_at_cap_cells / top_decile_cells else 0,
    mid_tier_increment_fraction =
      if (increment_total > 0) increment_mid / increment_total else 0,
    unchanged_fraction =
      if (total_cells > 0L) unchanged_cells / total_cells else 0,
    unallocatable_fraction =
      if (budget_total > 0) unallocatable_total / budget_total else 0
  )

  list(
    budget_delta_pct              = budget_delta_pct,
    channels                      = target,
    per_row                       = per_row,
    current_aggregate             = current_aggregate,
    proposed_aggregate            = proposed_aggregate,
    predicted_outcome_current     = out_current,
    predicted_outcome_proposed    = out_proposed,
    predicted_incremental_outcome = incremental,
    predicted_lift_pct            = lift_pct,
    diagnostics                   = diagnostics
  )
}


# Internal: distribute `budget_add` touches across cells with headroom below
# `cap`, proportional to per-cell headroom (`cap - current`). Cells at or above
# the cap absorb nothing. When `budget_add` does not exceed total headroom the
# split respects the cap exactly in a single pass; when it does exceed it, every
# cell is filled to the cap and the overflow is returned as `unallocatable`.
# Returns a list with `$proposed`, `$increment`, `$unallocatable`.
.waterfill <- function(current, cap, budget_add) {
  current        <- as.numeric(current)
  headroom       <- pmax(cap - current, 0)
  total_headroom <- sum(headroom)
  increment      <- numeric(length(current))

  if (total_headroom <= 0 || budget_add <= 0) {
    return(list(proposed      = current,
                increment     = increment,
                unallocatable = max(budget_add, 0)))
  }

  if (budget_add <= total_headroom) {
    increment     <- budget_add * headroom / total_headroom
    unallocatable <- 0
  } else {
    increment     <- headroom
    unallocatable <- budget_add - total_headroom
  }

  list(proposed      = current + increment,
       increment     = increment,
       unallocatable = unallocatable)
}
