# Fit the distributional-GLM baseline (correct family, no random effects)

Mirrors the Python GLMMDist-Naive baseline:
[`stats::glm`](https://rdrr.io/r/stats/glm.html) with Poisson,
`Gamma(link = "log")`, or Gaussian per the resolved objective. Tweedie
is approximated with Gamma(log) because base R doesn't ship a Tweedie
family; the `statmod::tweedie` family can be substituted by passing
`family_override`.

## Usage

``` r
fit_glmm_distributional(df, config, family_override = NULL)
```

## Arguments

- df:

  A panel.

- config:

  A
  [`run_config()`](https://jamesyoung93.github.io/treemmm-r/reference/run_config.md)
  object.

- family_override:

  Optional `family` object to use directly.

## Value

A list with `$model`, `$attribution_shares`, `$formula`, `$family`.
