# Coverage check: count training neighbors within a radius

For each row of `X_simulated`, counts how many rows of `X_train` lie
within Euclidean distance `radius` (after standardizing each column to
unit variance). Returns a vector of neighbor counts. Below
`min_neighbors` typically signals extrapolation regardless of method.

## Usage

``` r
coverage_check(X_train, X_simulated, radius = 0.5, min_neighbors = 30L)
```

## Arguments

- X_train:

  Numeric matrix or data.frame.

- X_simulated:

  Numeric matrix or data.frame with the same columns.

- radius:

  Distance threshold in standardized space.

- min_neighbors:

  Threshold below which extrapolation is flagged.

## Value

A list with `$counts` (per-simulated-row neighbor count) and
`$extrapolation_fraction` (fraction below `min_neighbors`).
