# Fit the GLMM-Oracle baseline (main effects + planted interactions)

Identical to
[`fit_glmm_naive()`](https://jamesyoung93.github.io/treemmm-r/reference/fit_glmm_naive.md)
except the planted DGP interactions are added as fixed-effect product
terms. Represents the upper bound for a regression baseline assuming the
analyst knows which channels co-modulate.

## Usage

``` r
fit_glmm_oracle(df, config, planted_interactions)
```

## Arguments

- df:

  A `data.frame` or `data.table` panel.

- config:

  A
  [`run_config()`](https://jamesyoung93.github.io/treemmm-r/reference/run_config.md)
  object.

- planted_interactions:

  List of `interaction_spec()` objects (typically
  `ground_truth$interactions`).

## Value

Same structure as
[`fit_glmm_naive()`](https://jamesyoung93.github.io/treemmm-r/reference/fit_glmm_naive.md).
