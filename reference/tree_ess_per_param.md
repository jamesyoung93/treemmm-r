# Effective-sample-size analog for a tree learner

Crude analog to `arviz.ess / n_parameters` for Bayesian models: training
rows divided by the number of leaves at max depth, summed across
estimators. Below ~20 obs per parameter both paradigms are weakly
identified.

## Usage

``` r
tree_ess_per_param(n_train, n_estimators, max_depth)
```

## Arguments

- n_train:

  Number of training rows.

- n_estimators:

  Number of boosting rounds.

- max_depth:

  Maximum tree depth.

## Value

A list with `$ess_per_param`, `$n_params`, `$diagnostic` (`"adequate"`,
`"weak"`, `"insufficient"`).
