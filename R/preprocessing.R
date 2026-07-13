# Adstock preprocessing transforms. Mirrors
# treemmm.core.preprocessing.adstock in the Python package.

#' Apply geometric adstock to one or more time series
#'
#' Applies the Koyck recurrence `x_adstocked[t] = x[t] + decay *
#' x_adstocked[t - 1]`. Matrix rows are interpreted as ordered time steps and
#' columns as channels.
#'
#' @param x Numeric vector or matrix. Matrix columns are transformed
#'   independently.
#' @param decay Numeric carryover rate in `[0, 1)`. Supply one value for all
#'   channels or one value per matrix column.
#' @return A numeric vector or matrix with the same dimensions and dimnames as
#'   `x`.
#' @export
apply_geometric_adstock <- function(x, decay) {
  if (!is.numeric(x) || length(dim(x)) > 2L) {
    stop("`x` must be a numeric vector or matrix.", call. = FALSE)
  }

  is_vector <- is.null(dim(x))
  original_names <- names(x)
  if (is_vector) {
    values <- matrix(as.numeric(x), ncol = 1L)
  } else {
    values <- as.matrix(x)
    storage.mode(values) <- "double"
  }

  n_channels <- ncol(values)
  if (!is.numeric(decay) || length(decay) == 0L ||
      !length(decay) %in% c(1L, n_channels) || any(!is.finite(decay)) ||
      any(decay < 0 | decay >= 1)) {
    stop(
      "`decay` must be finite numeric values in [0, 1), with length 1 or ",
      n_channels, ".",
      call. = FALSE
    )
  }
  decay <- rep(as.numeric(decay), length.out = n_channels)

  transformed <- matrix(
    0,
    nrow = nrow(values),
    ncol = n_channels,
    dimnames = dimnames(values)
  )
  if (nrow(values) > 0L) {
    transformed[1L, ] <- values[1L, ]
    if (nrow(values) > 1L) {
      for (row in 2:nrow(values)) {
        transformed[row, ] <- values[row, ] +
          decay * transformed[row - 1L, ]
      }
    }
  }

  if (is_vector) {
    result <- transformed[, 1L]
    names(result) <- original_names
    return(result)
  }
  transformed
}


#' Apply geometric adstock independently within panel units
#'
#' Each customer's rows are ordered by `time_col`, transformed independently,
#' and written back to their original row positions. The input is never
#' modified, and the returned rows remain in the same order as the input.
#'
#' @param df A data frame or data table with one row per customer-period.
#' @param time_col Name of the sortable time column.
#' @param customer_id_col Name of the customer identifier column.
#' @param channels Character vector of numeric channel columns to transform.
#' @param decay Either one numeric rate applied to all channels or a named
#'   numeric vector/list of per-channel rates. Channels absent from a named map
#'   use zero decay.
#' @return A copy of `df` with the requested channel columns transformed.
#' @export
apply_panel_adstock <- function(df,
                                time_col,
                                customer_id_col,
                                channels,
                                decay) {
  if (!inherits(df, "data.frame")) {
    stop("`df` must be a data.frame or data.table.", call. = FALSE)
  }
  if (!is.character(time_col) || length(time_col) != 1L ||
      is.na(time_col) || !nzchar(time_col)) {
    stop("`time_col` must name one column.", call. = FALSE)
  }
  if (!is.character(customer_id_col) || length(customer_id_col) != 1L ||
      is.na(customer_id_col) || !nzchar(customer_id_col)) {
    stop("`customer_id_col` must name one column.", call. = FALSE)
  }
  if (!is.character(channels) || anyNA(channels) || any(!nzchar(channels)) ||
      anyDuplicated(channels)) {
    stop("`channels` must contain unique, non-missing column names.",
         call. = FALSE)
  }

  required <- c(time_col, customer_id_col, channels)
  missing_cols <- setdiff(required, names(df))
  if (length(missing_cols) > 0L) {
    stop("Columns not found in `df`: ", paste(missing_cols, collapse = ", "),
         call. = FALSE)
  }
  df_frame <- as.data.frame(df, stringsAsFactors = FALSE,
                            check.names = FALSE)
  non_numeric <- channels[!vapply(df_frame[, channels, drop = FALSE],
                                  is.numeric, logical(1L))]
  if (length(non_numeric) > 0L) {
    stop("Channel columns must be numeric: ",
         paste(non_numeric, collapse = ", "), call. = FALSE)
  }

  out <- if (inherits(df, "data.table")) data.table::copy(df) else df
  if (length(channels) == 0L || nrow(df) == 0L) {
    return(out)
  }

  decay_values <- unlist(decay, use.names = TRUE)
  if (!is.numeric(decay_values) || length(decay_values) == 0L) {
    stop("`decay` must contain numeric carryover rates.", call. = FALSE)
  }
  has_decay_names <- !is.null(names(decay_values)) &&
    any(nzchar(names(decay_values)))
  if (length(decay_values) == 1L && !has_decay_names) {
    resolved_decay <- rep(as.numeric(decay_values), length(channels))
  } else {
    if (!has_decay_names || is.null(names(decay_values))) {
      stop("Per-channel `decay` values must be named.", call. = FALSE)
    }
    resolved_decay <- vapply(
      channels,
      function(channel) {
        if (channel %in% names(decay_values)) decay_values[[channel]] else 0
      },
      numeric(1L)
    )
  }
  # Centralize length/range validation in the vector-level transform.
  apply_geometric_adstock(matrix(0, nrow = 1L, ncol = length(channels)),
                          resolved_decay)

  groups <- split(seq_len(nrow(df)), df[[customer_id_col]], drop = TRUE)
  for (indices in groups) {
    sorted_indices <- indices[order(df[[time_col]][indices],
                                    na.last = TRUE, method = "radix")]
    raw_values <- as.matrix(df_frame[sorted_indices, channels, drop = FALSE])
    storage.mode(raw_values) <- "double"
    transformed <- apply_geometric_adstock(raw_values, resolved_decay)
    for (column_idx in seq_along(channels)) {
      out[[channels[column_idx]]][sorted_indices] <- transformed[, column_idx]
    }
  }
  out
}


# Backward-compatible internal spelling retained for code that used the
# pre-v0.3 development stub.
apply_adstock_panel <- function(df, customer_col, time_col, decay_map) {
  apply_panel_adstock(
    df = df,
    time_col = time_col,
    customer_id_col = customer_col,
    channels = names(decay_map),
    decay = decay_map
  )
}
