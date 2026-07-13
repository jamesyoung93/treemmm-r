# Cap-bounded budget reallocation: "where the next touch lands".
#
# Mirrors the v0.3.0 / v0.3.1 budget-reallocation layer of the Python package
# (treemmm.mroi.simulator.reallocate / reallocate_curve). Given a fitted model
# and a committed budget increase, plan where the extra touches land at the
# customer-period grain under a per-customer cap, predict the incremental
# outcome, then sweep that plan across budget levels into a decision curve.
#
# The algorithm is deterministic (water-fill arithmetic + model predictions),
# so on identical inputs it reproduces the Python outputs to float tolerance.
# numpy's default np.percentile (linear interpolation) equals R quantile type 7,
# so the per-customer cap matches the Python implementation exactly.

# ---- internal helpers -------------------------------------------------------

# numpy-compatible linear-interpolation percentile (np.percentile default ==
# R quantile type 7). `pct` is on a 0-100 scale.
.mroi_percentile <- function(x, pct) {
  as.numeric(stats::quantile(x, pct / 100, type = 7, names = FALSE))
}

# Predict from a model that may be (a) a bare function taking the feature frame,
# (b) a list carrying a `$predict` closure (the duck-typed / linear-stub model),
# or (c) a treemmm `pipeline_result`.
.mroi_predict <- function(model, X) {
  if (is.function(model)) {
    return(as.numeric(model(X)))
  }
  if (is.list(model) && !is.null(model$predict) && is.function(model$predict)) {
    return(as.numeric(model$predict(X)))
  }
  if (inherits(model, "pipeline_result")) {
    fc <- model$prepared_data$feature_cols
    Xm <- as.matrix(as.data.frame(X)[, fc, drop = FALSE])
    storage.mode(Xm) <- "double"
    return(as.numeric(stats::predict(model$model, Xm)))
  }
  as.numeric(stats::predict(model, X))
}

# Prefer configured promo variables for a pipeline result; otherwise infer
# spendable channels from monotone constraints (+1 == spendable). Returns NULL
# when neither source is available, matching the Python `_infer_channels`
# contract.
.mroi_infer_channels <- function(model, X) {
  if (inherits(model, "pipeline_result")) {
    promo <- model$config$columns$promo_vars
    selected <- promo[promo %in% colnames(X)]
    return(if (length(selected) == 0L) NULL else selected)
  }

  mono <- model$monotone_constraints
  feats <- model$feature_names
  if (is.null(mono) || is.null(feats) || length(mono) != length(feats)) {
    return(NULL)
  }
  sel <- feats[as.integer(mono) == 1L & feats %in% colnames(X)]
  if (length(sel) == 0L) NULL else sel
}

# Distribute `budget_add` touches across cells with headroom below `cap`,
# split proportional to per-cell headroom (cap - current). Cells at the cap
# absorb nothing. When `budget_add` exceeds total headroom every cell fills to
# the cap and the overflow is reported as unallocatable. Mirrors `_waterfill`.
.mroi_waterfill <- function(current, cap, budget_add) {
  current <- as.numeric(current)
  headroom <- pmax(cap - current, 0)
  total_headroom <- sum(headroom)
  increment <- numeric(length(current))
  if (total_headroom <= 0 || budget_add <= 0) {
    return(list(proposed = current,
                increment = increment,
                unallocatable = max(budget_add, 0)))
  }
  if (budget_add <= total_headroom) {
    increment <- budget_add * headroom / total_headroom
    unallocatable <- 0
  } else {
    increment <- headroom
    unallocatable <- budget_add - total_headroom
  }
  list(proposed = current + increment,
       increment = increment,
       unallocatable = unallocatable)
}

# Stable string key for a numeric budget level (named list lookup).
.mroi_delta_key <- function(d) format(d, trim = TRUE, scientific = FALSE)

# ---- reallocate() -----------------------------------------------------------

#' Plan a cap-bounded budget reallocation and predict its incremental outcome
#'
#' Increases each target channel's total touches by `budget_delta_pct` and
#' deploys the increment additively to cells with headroom below the
#' per-customer cap (the `cap_percentile` of observed positive touches). Cells
#' at or above the cap are left unchanged, so every per-customer value stays
#' inside the observed support. R mirror of the Python
#' `treemmm.mroi.reallocate`; on identical inputs the two agree to float
#' tolerance.
#'
#' @param model A fitted model. Either a function mapping the feature frame to a
#'   numeric prediction vector, a list carrying a `$predict` closure (and,
#'   optionally, `$monotone_constraints` + `$feature_names` for channel
#'   inference), or a [treemmm_run()] `pipeline_result`.
#' @param X Feature frame (data.frame / data.table) at the customer-period grain.
#'   Promo channel columns are modified; all other columns pass through to the
#'   model unchanged.
#' @param budget_delta_pct Percent change in channel budget (25 means +25%).
#' @param cap_percentile Percentile of observed positive touches used as the
#'   per-customer cap (default 95).
#' @param channel Reallocate a single named channel. Takes precedence over
#'   `channels`.
#' @param channels Reallocate across this set of channels, each independently
#'   capped and grown by `budget_delta_pct`. When both `channel` and `channels`
#'   are `NULL` the channel set is read from a `pipeline_result`'s configured
#'   `promo_vars`, or inferred from another model's monotone constraints.
#' @return A `reallocation_plan`: a list with the per-row landing plan
#'   (`per_row`), per-channel `current_aggregate` / `proposed_aggregate`, the
#'   summed `predicted_outcome_current` / `predicted_outcome_proposed`,
#'   `predicted_incremental_outcome`, `predicted_lift_pct`, and a
#'   `diagnostics` record.
#' @export
reallocate <- function(model, X, budget_delta_pct, cap_percentile = 95,
                       channel = NULL, channels = NULL) {
  X <- as.data.frame(X, stringsAsFactors = FALSE, check.names = FALSE)
  row_id <- rownames(X)

  if (!is.null(channel)) {
    target <- as.character(channel)
  } else if (!is.null(channels)) {
    target <- as.character(channels)
  } else {
    target <- .mroi_infer_channels(model, X)
    if (is.null(target) || length(target) == 0L) {
      stop("Could not infer promo channels from the model. Pass `channel=` ",
           "for a single channel or `channels=` for the set to reallocate.",
           call. = FALSE)
    }
  }

  missing_cols <- setdiff(target, colnames(X))
  if (length(missing_cols) > 0L) {
    stop("Channels not found in X: ", paste(missing_cols, collapse = ", "),
         call. = FALSE)
  }

  X_proposed <- X
  caps <- list()
  current_aggregate <- list()
  proposed_aggregate <- list()
  per_row <- data.table::data.table(row_id = row_id)

  total_cells <- 0L
  at_cap_cells <- 0L
  top_decile_cells <- 0L
  top_decile_at_cap_cells <- 0L
  unchanged_cells <- 0L
  increment_total <- 0
  increment_mid <- 0
  budget_total <- 0
  unallocatable_total <- 0

  for (col in target) {
    current <- as.numeric(X[[col]])
    positive <- current[current > 0]
    if (length(positive) > 0L) {
      cap <- .mroi_percentile(positive, cap_percentile)
    } else {
      cap <- if (length(current) > 0L) max(current) else 0
    }

    current_agg <- sum(current)
    budget_add <- current_agg * budget_delta_pct / 100
    wf <- .mroi_waterfill(current, cap, budget_add)
    proposed <- wf$proposed
    increment <- wf$increment

    X_proposed[[col]] <- proposed
    caps[[col]] <- cap
    current_aggregate[[col]] <- current_agg
    proposed_aggregate[[col]] <- sum(proposed)
    per_row[[col]] <- proposed
    per_row[[paste0(col, "__current")]] <- current
    per_row[[paste0(col, "__increment")]] <- increment

    at_cap <- current >= cap
    top_threshold <- if (length(current) > 0L) .mroi_percentile(current, 90) else 0
    top_decile <- current >= top_threshold
    mid_tier <- (!top_decile) & (!at_cap)

    total_cells <- total_cells + length(current)
    at_cap_cells <- at_cap_cells + sum(at_cap)
    top_decile_cells <- top_decile_cells + sum(top_decile)
    top_decile_at_cap_cells <- top_decile_at_cap_cells + sum(top_decile & at_cap)
    unchanged_cells <- unchanged_cells + sum(increment <= 1e-9)
    increment_total <- increment_total + sum(increment)
    increment_mid <- increment_mid + sum(increment[mid_tier])
    budget_total <- budget_total + budget_add
    unallocatable_total <- unallocatable_total + wf$unallocatable
  }

  predicted_current <- .mroi_predict(model, X)
  predicted_proposed <- .mroi_predict(model, X_proposed)
  out_current <- sum(predicted_current)
  out_proposed <- sum(predicted_proposed)
  incremental <- out_proposed - out_current
  lift_pct <- if (out_current != 0) incremental / out_current * 100 else 0

  diagnostics <- structure(list(
    cap_percentile = cap_percentile,
    caps = caps,
    at_cap_fraction = if (total_cells > 0L) at_cap_cells / total_cells else 0,
    top_decile_at_cap_fraction =
      if (top_decile_cells > 0L) top_decile_at_cap_cells / top_decile_cells else 0,
    mid_tier_increment_fraction =
      if (increment_total > 0) increment_mid / increment_total else 0,
    unchanged_fraction = if (total_cells > 0L) unchanged_cells / total_cells else 0,
    unallocatable_fraction =
      if (budget_total > 0) unallocatable_total / budget_total else 0
  ), class = "reallocation_diagnostics")

  structure(list(
    budget_delta_pct = budget_delta_pct,
    channels = target,
    per_row = per_row,
    current_aggregate = current_aggregate,
    proposed_aggregate = proposed_aggregate,
    predicted_outcome_current = out_current,
    predicted_outcome_proposed = out_proposed,
    predicted_incremental_outcome = incremental,
    predicted_lift_pct = lift_pct,
    diagnostics = diagnostics
  ), class = "reallocation_plan")
}

# ---- reallocate_curve() -----------------------------------------------------

#' Sweep [reallocate()] across budget levels into a decision curve
#'
#' Runs the cap-bounded reallocation at every level in `budget_deltas` and
#' assembles a table a planner can read straight down: how much of the requested
#' budget actually lands, the predicted incremental outcome and lift, the
#' marginal return per landed touch, and where the per-customer cap starts to
#' bind. The full per-customer landing plan at every level is retained in
#' `plans` so an operational call list can be exported for the chosen level. R
#' mirror of the Python `treemmm.mroi.reallocate_curve`.
#'
#' @param model A fitted model (see [reallocate()]).
#' @param X Model-ready feature frame at the customer-period grain.
#' @param budget_deltas Budget levels to sweep, as percent increases (e.g.
#'   `c(10, 25, 50, 100)`). De-duplicated and sorted ascending before the sweep.
#' @param cap_percentile Per-customer cap percentile, held fixed across levels
#'   (default 95).
#' @param channel Reallocate a single named channel (takes precedence).
#' @param channels Channel set to reallocate. When both `channel` and `channels`
#'   are `NULL`, it is read from a `pipeline_result`'s configured `promo_vars`
#'   or inferred from another model's monotone constraints.
#' @param tol Unallocatable-fraction tolerance defining `max_allocatable_delta`.
#' @return A `reallocation_curve`: a list with the decision `table` (one row per
#'   level), the per-level `plans`, the swept `budget_deltas`, and
#'   `max_allocatable_delta` (the largest fully-allocatable level, or `NA` if
#'   even the smallest level overflows the cap).
#' @export
reallocate_curve <- function(model, X, budget_deltas, cap_percentile = 95,
                             channel = NULL, channels = NULL, tol = 1e-6) {
  deltas <- sort(unique(as.numeric(budget_deltas)))
  if (length(deltas) == 0L) {
    stop("budget_deltas must contain at least one level.", call. = FALSE)
  }

  plans <- vector("list", length(deltas))
  names(plans) <- vapply(deltas, .mroi_delta_key, character(1))
  rows <- vector("list", length(deltas))
  prev_inc <- NULL
  prev_touches <- NULL

  for (k in seq_along(deltas)) {
    delta <- deltas[k]
    plan <- reallocate(model, X, budget_delta_pct = delta,
                       cap_percentile = cap_percentile,
                       channel = channel, channels = channels)
    plans[[k]] <- plan
    placed <- sum(unlist(plan$proposed_aggregate)) -
      sum(unlist(plan$current_aggregate))
    inc <- plan$predicted_incremental_outcome
    marginal <- if (placed > 0) inc / placed else NA_real_
    if (is.null(prev_inc)) {
      step_marginal <- marginal
    } else {
      d_touch <- placed - prev_touches
      step_marginal <- if (d_touch > 0) (inc - prev_inc) / d_touch else NA_real_
    }
    rows[[k]] <- data.table::data.table(
      budget_delta_pct = delta,
      added_touches = placed,
      predicted_incremental_outcome = inc,
      predicted_lift_pct = plan$predicted_lift_pct,
      marginal_return_per_touch = marginal,
      step_marginal_return = step_marginal,
      mid_tier_increment_fraction = plan$diagnostics$mid_tier_increment_fraction,
      at_cap_fraction = plan$diagnostics$at_cap_fraction,
      unallocatable_fraction = plan$diagnostics$unallocatable_fraction
    )
    prev_inc <- inc
    prev_touches <- placed
  }

  table <- data.table::rbindlist(rows)
  allocatable <- deltas[vapply(
    seq_along(deltas),
    function(k) plans[[k]]$diagnostics$unallocatable_fraction <= tol,
    logical(1)
  )]
  max_allocatable_delta <- if (length(allocatable) > 0L) max(allocatable) else NA_real_

  structure(list(
    cap_percentile = cap_percentile,
    channels = plans[[1]]$channels,
    budget_deltas = deltas,
    table = table,
    plans = plans,
    max_allocatable_delta = max_allocatable_delta
  ), class = "reallocation_curve")
}
