# Generate the linear baseline DGP (Gaussian, honesty test)

Three channels (channel_a, channel_b, channel_c), no interactions, no
heterogeneous sensitivity. Used to confirm that TreeMMM does not invent
non-linearity where none exists.

## Usage

``` r
generate_linear_dataset(
  n_customers = 500L,
  n_periods = 24L,
  random_state = 42L
)
```

## Value

A `generated_dataset` list.
