# Shared fixtures for the budget-reallocation tests. Mirror the Python
# `_LinearStub` / `_toy_frame` helpers in tests/test_budget_reallocation.py so
# the R behavioural tests exercise the same shapes as the Python suite.

# Minimal model: predicts a positive linear combination of channels. Carries
# `monotone_constraints` + `feature_names` so the channel-inference path can be
# exercised without a real LightGBM fit (R analogue of `_LinearStub`).
linear_stub <- function(weights, feature_names) {
  list(
    predict = function(X) {
      out <- numeric(nrow(X))
      for (col in names(weights)) {
        out <- out + weights[[col]] * as.numeric(X[[col]])
      }
      out
    },
    monotone_constraints = as.integer(feature_names %in% names(weights)),
    feature_names = feature_names
  )
}

# A model with no constraint metadata: channel inference must fail (R analogue
# of the `_Bare` class).
bare_stub <- function(channel) {
  list(
    predict = function(X) as.numeric(X[[channel]])
  )
}

# Toy customer-period frame with two promo channels and one control. Row names
# match the Python index (`row0000`..). Exact draws differ from numpy's RNG, so
# this is only used for property/behavioural tests; the cross-implementation
# parity tests read a shared fixture instead.
toy_frame <- function(n = 400L, seed = 0L) {
  set.seed(seed)
  df <- data.frame(
    rep_visits = as.numeric(stats::rpois(n, 3)),
    samples    = as.numeric(stats::rpois(n, 2)),
    control    = stats::rnorm(n)
  )
  rownames(df) <- sprintf("row%04d", seq_len(n) - 1L)
  df
}
