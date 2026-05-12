# Estimate marginal ROI (mROI) per channel

Computes the endpoint-slope mROI for each channel: the change in mean
outcome between 100 percent and 150 percent of current allocation,
divided by the change in input. Returns a named numeric vector ordered
largest-first.

## Usage

``` r
mroi_ranking(result, channels = NULL)
```

## Arguments

- result:

  A
  [`treemmm_run()`](https://jamesyoung93.github.io/treemmm-r/reference/treemmm_run.md)
  result.

- channels:

  Optional subset of channels. Defaults to all promo_vars in the
  pipeline's column spec.

## Value

A named numeric vector of mROI per channel.
