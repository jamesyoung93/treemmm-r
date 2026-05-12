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
