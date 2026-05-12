# Sweep allocation 0-150 percent of observed level and return the response curve

For each multiplier in `sweep`, replace the channel's values in a
reference feature matrix with `multiplier * original_value`, predict the
outcome via the fitted model, and average across observations. Returns a
data.table with one row per multiplier (`pct_of_current`,
`mean_outcome`).

## Usage

``` r
simulate_response(result, channel, sweep = seq(0, 1.5, by = 0.1), X_ref = NULL)
```

## Arguments

- result:

  A
  [`treemmm_run()`](https://jamesyoung93.github.io/treemmm-r/reference/treemmm_run.md)
  result.

- channel:

  Name of the promotional channel to sweep.

- sweep:

  Numeric vector of allocation multipliers (default 0.0..1.5).

- X_ref:

  Optional reference matrix to evaluate at. Defaults to the last-fold
  test set's feature matrix from the pipeline result.

## Value

A data.table with columns `pct_of_current`, `mean_outcome`.
