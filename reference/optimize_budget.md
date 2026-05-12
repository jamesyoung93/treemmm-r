# Reallocate a fixed budget across channels to maximize predicted outcome

Simple coordinate-ascent over a small fixed grid. Each channel is
constrained to `[per_customer_min, per_customer_max] * n_obs`. The total
budget is held constant; channels are shifted by `step_frac` of current
allocation each iteration until no shift improves predicted outcome.

## Usage

``` r
optimize_budget(result, channels = NULL, step_frac = 0.1, max_iter = 20L)
```

## Arguments

- result:

  A
  [`treemmm_run()`](https://jamesyoung93.github.io/treemmm-r/reference/treemmm_run.md)
  result.

- channels:

  Channels eligible for reallocation. Default: all `feature_cols`
  (caller should restrict to promo_vars).

- step_frac:

  Fraction of current allocation moved per iteration.

- max_iter:

  Hard cap on coordinate-ascent iterations.

## Value

A list with `$allocation` (new per-channel total) and `$predicted_lift`
(relative improvement vs current allocation).
