# Decompose total predictor variance into within- and between-unit shares

For each feature column, returns the fraction of total variance that
lives within-unit (temporal variation, holding customer fixed) versus
between-unit (cross-sectional, holding period fixed).

## Usage

``` r
variation_decomposition(df, unit_col, feature_cols)
```

## Arguments

- df:

  A panel data.frame.

- unit_col:

  The column identifying the panel unit (e.g. customer_id).

- feature_cols:

  Numeric feature columns to decompose.

## Value

A data.table with columns `feature`, `within_share`, `between_share`.
