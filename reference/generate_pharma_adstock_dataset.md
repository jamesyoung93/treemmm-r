# Generate the pharma-with-adstock specialty DGP

Variant of
[`generate_pharma_dataset()`](https://jamesyoung93.github.io/treemmm-r/reference/generate_pharma_dataset.md)
with geometric adstock planted on each promotional channel. The raw
channel values are stored as `<channel>_raw`; the named promotional
columns hold the adstocked values.

## Usage

``` r
generate_pharma_adstock_dataset(
  n_customers = 500L,
  n_periods = 24L,
  random_state = 42L
)
```

## Value

A `generated_dataset` list.
