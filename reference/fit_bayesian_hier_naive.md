# Fit the PyMC-Hier-Naive baseline via brms

Customer-level hierarchical Bayesian baseline: main effects with a
per-customer random intercept, fit via `brms::brm`. The objective
resolves to a `brms` family (Gaussian / Poisson / Gamma). Use cmdstanr
backend if available for faster sampling.

## Usage

``` r
fit_bayesian_hier_naive(df, config, n_chains = 2L, n_iter = 1000L)
```

## Arguments

- df:

  A panel.

- config:

  A
  [`run_config()`](https://jamesyoung93.github.io/treemmm-r/reference/run_config.md)
  object.

- n_chains:

  Number of MCMC chains. Default 2.

- n_iter:

  Number of MCMC iterations per chain (including warmup). Default 1000.

## Value

A list with `$model` (a brmsfit), `$attribution_shares`, `$formula`,
`$objective`.
