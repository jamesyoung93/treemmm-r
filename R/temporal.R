# Rolling-origin temporal CV. Mirrors treemmm.core.temporal.splitter in the
# Python package.

#' Produce rolling-origin train/test splits for panel data
#'
#' Each fold's training horizon expands forward in time. The first fold's
#' training window covers periods 1..(min_train_frac * n_t); the test
#' window covers a fraction (1 - min_train_frac) / n_folds. Subsequent
#' folds extend the training window by the same fraction.
#'
#' @param df A `data.frame` or `data.table` with one row per (customer, period).
#' @param time_col Name of the time column.
#' @param n_folds Number of folds.
#' @param min_train_frac Fraction of the time horizon used in fold 1's train.
#' @return A list of length `n_folds`, each element a list with
#'   `train_idx`, `test_idx`, `fold` (1-based).
#' @noRd
get_splits <- function(df, time_col, n_folds = 5L, min_train_frac = 0.5) {
  times <- sort(unique(df[[time_col]]))
  n_t <- length(times)
  if (n_t < n_folds + 2L) {
    stop("Not enough unique time periods for ", n_folds,
         "-fold rolling-origin CV. Found ", n_t, " periods; need at least ",
         n_folds + 2L, ".")
  }
  test_frac_each <- (1 - min_train_frac) / n_folds
  splits <- vector("list", n_folds)
  for (k in seq_len(n_folds)) {
    train_end_frac <- min_train_frac + (k - 1L) * test_frac_each
    test_end_frac  <- min_train_frac + k * test_frac_each
    train_end <- max(1L, floor(train_end_frac * n_t))
    test_end  <- min(n_t, max(train_end + 1L, floor(test_end_frac * n_t)))

    train_times <- times[seq_len(train_end)]
    test_times  <- times[(train_end + 1L):test_end]
    splits[[k]] <- list(
      fold       = k,
      train_idx  = which(df[[time_col]] %in% train_times),
      test_idx   = which(df[[time_col]] %in% test_times),
      train_times = train_times,
      test_times  = test_times
    )
  }
  splits
}


# Split an outer fold's training window into model-training and tuning windows.
#
# The validation window is carved from the latest complete periods in the
# outer training window.  Splitting by period (rather than by row) keeps every
# customer's observations for a period together and is robust to the panel's
# customer-then-time row ordering.
.split_tuning_validation <- function(df, split, time_col,
                                     validation_frac = 0.2) {
  if (!is.numeric(validation_frac) || length(validation_frac) != 1L ||
      !is.finite(validation_frac) || validation_frac <= 0 ||
      validation_frac >= 1) {
    stop("`validation_frac` must be a single number in (0, 1).")
  }

  train_times <- sort(unique(split$train_times))
  if (length(train_times) < 2L) {
    stop("The outer training window needs at least two periods so one can be ",
         "reserved for tuning validation.")
  }

  n_val_times <- max(1L, floor(length(train_times) * validation_frac))
  n_val_times <- min(n_val_times, length(train_times) - 1L)
  first_val <- length(train_times) - n_val_times + 1L
  tuning_train_times <- train_times[seq_len(first_val - 1L)]
  tuning_val_times <- train_times[first_val:length(train_times)]

  outer_train_idx <- split$train_idx
  outer_train_periods <- df[[time_col]][outer_train_idx]
  tuning_train_idx <- outer_train_idx[
    outer_train_periods %in% tuning_train_times
  ]
  tuning_val_idx <- outer_train_idx[
    outer_train_periods %in% tuning_val_times
  ]
  test_idx <- split$test_idx

  if (length(tuning_train_idx) == 0L || length(tuning_val_idx) == 0L ||
      length(test_idx) == 0L) {
    stop("Training, tuning-validation, and test windows must all be non-empty.")
  }
  if (length(intersect(tuning_train_idx, tuning_val_idx)) > 0L ||
      length(intersect(tuning_train_idx, test_idx)) > 0L ||
      length(intersect(tuning_val_idx, test_idx)) > 0L) {
    stop("Training, tuning-validation, and test row indices overlap.")
  }
  if (!(max(tuning_train_times) < min(tuning_val_times) &&
        max(tuning_val_times) < min(split$test_times))) {
    stop("Training, tuning-validation, and test periods are not ordered.")
  }

  list(
    fold = split$fold,
    outer_train_idx = outer_train_idx,
    tuning_train_idx = tuning_train_idx,
    tuning_val_idx = tuning_val_idx,
    test_idx = test_idx,
    tuning_train_times = tuning_train_times,
    tuning_val_times = tuning_val_times,
    test_times = split$test_times
  )
}
