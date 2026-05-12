# Diagnose the appropriate outcome distribution from data

Heuristic rules in decreasing priority:

- Strictly non-negative integers with variance \> 1.5 \* mean -\>
  "poisson" (LightGBM's poisson objective handles overdispersion through
  tuning; a true Negative Binomial objective is not available in stock
  LightGBM).

- Non-negative continuous with at least 5 percent zeros -\> "tweedie".

- Strictly positive continuous -\> "gamma".

- Otherwise -\> "gaussian".

## Usage

``` r
diagnose_distribution(y)
```

## Arguments

- y:

  Numeric vector of outcomes.

## Value

A list with `family` (the detected objective string) and `reasoning` (a
short human-readable description of the rule that fired).
