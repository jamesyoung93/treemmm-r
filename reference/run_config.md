# Build a TreeMMM pipeline configuration

Build a TreeMMM pipeline configuration

## Usage

``` r
run_config(
  columns,
  objective = "auto",
  tweedie_variance_power = 1.5,
  n_optuna_trials = 4L,
  n_folds = 5L,
  min_train_frac = 0.75,
  random_state = 42L
)
```

## Arguments

- columns:

  A
  [`column_spec()`](https://jamesyoung93.github.io/treemmm-r/reference/column_spec.md)
  result.

- objective:

  One of `"auto"`, `"gaussian"`, `"poisson"`, `"tweedie"`, `"gamma"`.
  `"auto"` triggers distribution detection in
  [`diagnose_distribution()`](https://jamesyoung93.github.io/treemmm-r/reference/diagnose_distribution.md)
  at run time.

- tweedie_variance_power:

  Only used when objective is `"tweedie"`.

- n_optuna_trials:

  Hyperparameter grid size for the LightGBM tuner. The R port uses a
  fixed grid (the Python implementation uses Optuna); this controls the
  number of grid points actually evaluated.

- n_folds:

  Number of rolling-origin temporal CV folds.

- min_train_frac:

  Fraction of the time horizon used for the first training window in
  rolling-origin CV.

- random_state:

  Integer seed for reproducibility.

## Value

A `run_config` list with class `run_config`.
