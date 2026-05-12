# Declare which columns play which role in a panel

Declare which columns play which role in a panel

## Usage

``` r
column_spec(
  customer_id,
  time_col,
  outcome_col,
  promo_vars,
  control_vars = character(0L),
  categorical_vars = character(0L)
)
```

## Arguments

- customer_id:

  Column name identifying the panel unit (HCP, store, account).

- time_col:

  Column name for the period index (month, week, quarter, ...).

- outcome_col:

  Column name for the response variable.

- promo_vars:

  Character vector of promotional channel column names.

- control_vars:

  Character vector of control column names. Default empty.

- categorical_vars:

  Character vector of categorical-variable column names (e.g. an HCS
  segment column). Default empty.

## Value

A `column_spec` list with class `column_spec`.
