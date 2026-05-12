# Playing with the DGP

## Inspecting and tuning the synthetic DGPs

TreeMMM ships with six synthetic DGPs, each parameterizable along the
same axes: number of customers, number of periods, random seed, and (for
some) adstock decay. This vignette shows how to inspect what each DGP
plants and how to tune the knobs.

### Available DGPs

``` r

library(treemmm)

# Four headline DGPs
ds_pharma <- generate_pharma_dataset(n_customers = 30, n_periods = 12)
ds_cpg    <- generate_cpg_dataset(n_customers = 30, n_periods = 12)
ds_saas   <- generate_saas_dataset(n_customers = 30, n_periods = 12)
ds_lin    <- generate_linear_dataset(n_customers = 30, n_periods = 12)

# Two specialty DGPs
ds_adstock <- generate_pharma_adstock_dataset(n_customers = 30, n_periods = 12)
ds_geo     <- generate_geo_panel_dataset(n_regions = 30, n_weeks = 12)

# Each returns the same structure
lapply(list(ds_pharma, ds_cpg, ds_saas, ds_lin),
       function(d) c(rows = nrow(d$df), channels = length(d$columns$promo_vars)))
#> [[1]]
#>     rows channels 
#>      360        6 
#> 
#> [[2]]
#>     rows channels 
#>      360        5 
#> 
#> [[3]]
#>     rows channels 
#>      360        5 
#> 
#> [[4]]
#>     rows channels 
#>      360        3
```

### Inspecting the planted truth

`ground_truth$attribution_shares` is the reference each model is
benchmarked against:

``` r

sort(unlist(ds_pharma$ground_truth$attribution_shares), decreasing = TRUE)
#>          rep_visits             samples     dtc_advertising       peer_programs 
#>         0.382384881         0.320744537         0.158192763         0.050942927 
#> digital_impressions               _base        _seasonality        market_index 
#>         0.038096142         0.031440953         0.007572447         0.006928638 
#>          conference 
#>         0.003696713
```

`ground_truth$customer_sensitivities` gives the per-customer per-channel
sensitivity vector drawn from each segment’s multivariate normal:

``` r

str(head(ds_pharma$ground_truth$customer_sensitivities, 2))
#> List of 2
#>  $ : NULL
#>  $ : NULL
```

`ground_truth$interactions` lists the planted channel interactions:

``` r

ds_pharma$ground_truth$interactions
#> [[1]]
#> $var1
#> [1] "rep_visits"
#> 
#> $var2
#> [1] "samples"
#> 
#> $strength
#> [1] 0.6
#> 
#> attr(,"class")
#> [1] "interaction_spec"
#> 
#> [[2]]
#> $var1
#> [1] "dtc_advertising"
#> 
#> $var2
#> [1] "rep_visits"
#> 
#> $strength
#> [1] 0.4
#> 
#> attr(,"class")
#> [1] "interaction_spec"
#> 
#> [[3]]
#> $var1
#> [1] "peer_programs"
#> 
#> $var2
#> [1] "rep_visits"
#> 
#> $strength
#> [1] 0.3
#> 
#> attr(,"class")
#> [1] "interaction_spec"
```

### Heterogeneous customer sensitivity (HCS)

The pharma DGP plants a rheumatology/dermatology split. The mean
sensitivity vectors per segment determine the spread:

``` r

sens <- ds_pharma$ground_truth$customer_sensitivities

# Rheum vs derm rep_visits sensitivity
rheum_cids <- ds_pharma$df[specialty == "rheumatology", unique(customer_id)]
derm_cids  <- ds_pharma$df[specialty == "dermatology",  unique(customer_id)]

rheum_rep <- vapply(rheum_cids, function(id) sens[[id]][["rep_visits"]],
                    numeric(1))
derm_rep  <- vapply(derm_cids,  function(id) sens[[id]][["rep_visits"]],
                    numeric(1))

c(rheum_mean = mean(rheum_rep), derm_mean = mean(derm_rep))
#> rheum_mean  derm_mean 
#>  1.6358478  0.2961972
```

The DGP plants rheum mean 1.6 / derm mean 0.4 for rep_visits, so at any
nontrivial sample size the segment means should differ by roughly that
amount.

### Tuning sample size

The default sizes are small for fast tests. Headline-scale defaults
match the Python paper benchmark (3,000 x 36):

``` r

# Headline scale (slow!  this is the actual paper scale)
ds_full <- generate_pharma_dataset(
  n_customers  = 3000,
  n_periods    = 36,
  random_state = 42
)
```

### Tuning the random seed

Two runs at the same seed produce identical panels:

``` r

a <- generate_pharma_dataset(n_customers = 20, n_periods = 6, random_state = 7)
b <- generate_pharma_dataset(n_customers = 20, n_periods = 6, random_state = 7)
identical(a$df, b$df)
#> [1] TRUE
```

Different seeds produce different panels but the planted attribution
shares converge to the same values at scale (Monte Carlo error
diminishes with `n_customers x n_periods`).

### Adstock variant

The pharma-with-adstock DGP plants geometric carryover on each channel.
The raw and adstocked values are both available:

``` r

ds_adstock$columns$adstock_decays
#> $rep_visits
#> [1] 0.5
#> 
#> $dtc_advertising
#> [1] 0.3
#> 
#> $samples
#> [1] 0.4
#> 
#> $peer_programs
#> [1] 0.2
#> 
#> $digital_impressions
#> [1] 0.2
#> 
#> $conference
#> [1] 0
head(ds_adstock$df[, .(customer_id, period, rep_visits, rep_visits_raw)])
#>    customer_id period rep_visits rep_visits_raw
#>         <char>  <int>      <num>          <num>
#> 1:   cust_0000      1     2.0000              2
#> 2:   cust_0000      2     3.0000              2
#> 3:   cust_0000      3     4.5000              3
#> 4:   cust_0000      4     2.2500              0
#> 5:   cust_0000      5     6.1250              5
#> 6:   cust_0000      6     5.0625              2
```

The model sees `rep_visits` (the cumulative-exposure column); the
analyst can inspect `rep_visits_raw` to verify the carryover was planted
as expected.

### Reproducibility caveat across R and Python

R’s Mersenne Twister and Python’s PCG64 produce different samples at the
same numeric seed. The DGP coefficients and structural form match the
Python implementation exactly; the planted reference attribution shares
converge to the Python ones within Monte Carlo error (\< 0.5 pp at
headline scale). See `SPEC.md` in the repo for the formal specification
both implementations target.
