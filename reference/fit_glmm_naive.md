# Fit the GLMM-Naive baseline (main effects + random customer intercept)

Uses [`lme4::lmer`](https://rdrr.io/pkg/lme4/man/lmer.html) on
`log1p(outcome)` for non-Gaussian families and on raw outcome for
Gaussian. Returns attribution shares derived from the absolute
standardized fixed-effect contributions. Matches the Python
implementation's GLMM-Naive baseline.

## Usage

``` r
fit_glmm_naive(df, config)
```

## Arguments

- df:

  A `data.frame` or `data.table` panel.

- config:

  A
  [`run_config()`](https://jamesyoung93.github.io/treemmm-r/reference/run_config.md)
  object.

## Value

A list with `$model`, `$attribution_shares`, `$formula`, `$objective`.
