# Fit the tree-to-GLMM hybrid baseline

Two-stage procedure:

1.  Fit a LightGBM model and compute SHAP values.

2.  Rank feature pairs by mean product of \|SHAP_i \* SHAP_j\| across
    rows; pick the top `n_interactions`.

3.  Refit a GLMM
    ([`lme4::lmer`](https://rdrr.io/pkg/lme4/man/lmer.html)) with main
    effects plus those discovered interactions as fixed-effect product
    terms.

## Usage

``` r
fit_glmm_hybrid(df, config, n_interactions = 3L)
```

## Arguments

- df:

  A panel.

- config:

  A
  [`run_config()`](https://jamesyoung93.github.io/treemmm-r/reference/run_config.md)
  object.

- n_interactions:

  Number of top SHAP-derived interaction pairs to keep.

## Value

Same structure as
[`fit_glmm_naive()`](https://jamesyoung93.github.io/treemmm-r/reference/fit_glmm_naive.md)
plus `$discovered_interactions`.
