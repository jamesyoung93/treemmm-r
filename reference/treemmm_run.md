# Run the TreeMMM pipeline on a panel dataset

Orchestrates data preparation, distribution detection, rolling-origin
CV, LightGBM training with monotone constraints, SHAP attribution via
the link-function-aware decomposer, and aggregation into per-channel
attribution shares.

## Usage

``` r
treemmm_run(df, config, output_dir = NULL)
```

## Arguments

- df:

  A `data.frame` or `data.table` panel: one row per (customer, period).

- config:

  A
  [`run_config()`](https://jamesyoung93.github.io/treemmm-r/reference/run_config.md)
  object.

- output_dir:

  Optional path. Reserved for writing CSV results (Phase 5 will
  populate; currently unused).

## Value

A `pipeline_result` list with fields:

- `attribution_shares` — named list of per-feature shares summing to 1

- `fold_metrics` — list of per-fold R-squared / WMAPE / MAE / n_test

- `prepared_data` — output of `prepare_data()`

- `model` — the last fold's fitted LightGBM model

- `shap_result` — SHAP values + expected_value + link on the test set

- `attribution` — the link-aware attribution matrix

- `objective` — the resolved objective string

## Details

Attribution is computed from the *last* CV fold's model. Performance
metrics in `$fold_metrics` are computed per fold on each fold's held-out
test set.
