# Benchmark model mROI against DGP ground-truth mROI

Compares the model-derived mROI ranking (from
[`mroi_ranking()`](https://jamesyoung93.github.io/treemmm-r/reference/mroi_ranking.md))
against the DGP-derived mROI ranking (from the synthetic dataset's
ground-truth attribution shares). Returns Spearman rank correlation and
direction accuracy (fraction of channels where the model and DGP agree
on the sign of the marginal effect).

## Usage

``` r
mroi_benchmark(result, dataset)
```

## Arguments

- result:

  A
  [`treemmm_run()`](https://jamesyoung93.github.io/treemmm-r/reference/treemmm_run.md)
  result.

- dataset:

  A `generated_dataset` (from any `generate_*_dataset()`).

## Value

A list with `$rank_correlation`, `$direction_accuracy`, and the
underlying per-channel comparison table.
