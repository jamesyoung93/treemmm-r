# Generate the geo-panel specialty DGP

DGP designed to give aggregate-Bayesian methods their home turf: 200
regions x 52 weeks, three channels with planted geometric adstock and
logistic saturation. Used in the geo-panel comparison vs PyMC-Marketing
/ Robyn / Meridian. The planted adstock decays are applied via
`.apply_adstock()` using the CPG_ADSTOCK_DECAYS map (TV: 0.6, digital:
0.3, trade: 0.4).

## Usage

``` r
generate_geo_panel_dataset(n_regions = 200L, n_weeks = 52L, random_state = 42L)
```

## Arguments

- n_regions:

  Number of geographic regions. Default 200.

- n_weeks:

  Number of weekly periods. Default 52.

- random_state:

  Integer seed.

## Value

A `generated_dataset` list.
