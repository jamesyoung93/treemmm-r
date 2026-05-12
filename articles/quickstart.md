# TreeMMM Quickstart

## A five-minute tour of TreeMMM

TreeMMM is a tree-based Marketing Mix Modeling tool. Given a panel of
customer-by-period observations and a set of promotional columns, it
fits a gradient-boosted tree model, computes SHAP-derived attribution
shares per promotional channel, and produces marginal-ROI response
curves.

This vignette walks through the smallest end-to-end run.

### Generate a synthetic panel

The package ships with six synthetic data-generating processes (DGPs)
with known ground truth. We use the pharma DGP at a small scale:

``` r

library(treemmm)

ds <- generate_pharma_dataset(
  n_customers  = 50,
  n_periods    = 12,
  random_state = 42
)

# The result is a list with three elements:
names(ds)
#> [1] "df"           "ground_truth" "columns"
```

`ds$df` is the panel; `ds$columns` is the role mapping;
`ds$ground_truth` contains the planted attribution shares (the answer
the model is trying to recover):

``` r

head(ds$df)
#>    customer_id period outcome rep_visits dtc_advertising samples peer_programs
#>         <char>  <int>   <num>      <num>           <num>   <num>         <num>
#> 1:   cust_0000      1    5634          8               4       0             0
#> 2:   cust_0000      2    8463          8               4       8             1
#> 3:   cust_0000      3    8653          2               5       1             2
#> 4:   cust_0000      4     806          3               4       0             0
#> 5:   cust_0000      5    7033          3               7       1             1
#> 6:   cust_0000      6     218          2               1       0             1
#>    digital_impressions conference market_index   seasonality    specialty
#>                  <num>      <num>        <num>         <num>       <char>
#> 1:                   5          1   -1.0356939  1.500000e-01 rheumatology
#> 2:                   1          0   -0.1250326  1.299038e-01 rheumatology
#> 3:                   4          0   -0.5908252  7.500000e-02 rheumatology
#> 4:                   5          0    0.7209686  9.184851e-18 rheumatology
#> 5:                   2          0    0.6789478 -7.500000e-02 rheumatology
#> 6:                   4          1    0.1672514 -1.299038e-01 rheumatology
ds$columns
#> $customer_id
#> [1] "customer_id"
#> 
#> $time_col
#> [1] "period"
#> 
#> $outcome_col
#> [1] "outcome"
#> 
#> $promo_vars
#> [1] "rep_visits"          "dtc_advertising"     "samples"            
#> [4] "peer_programs"       "digital_impressions" "conference"         
#> 
#> $control_vars
#> [1] "market_index" "seasonality" 
#> 
#> $categorical_vars
#> [1] "specialty"
ds$ground_truth$attribution_shares
#> $`_base`
#> [1] 0.02976721
#> 
#> $`_seasonality`
#> [1] 0.007724263
#> 
#> $rep_visits
#> [1] 0.3798444
#> 
#> $dtc_advertising
#> [1] 0.1724115
#> 
#> $samples
#> [1] 0.3144318
#> 
#> $peer_programs
#> [1] 0.05318893
#> 
#> $digital_impressions
#> [1] 0.03249839
#> 
#> $conference
#> [1] 0.003597644
#> 
#> $market_index
#> [1] 0.006535855
```

### Configure the pipeline

[`run_config()`](https://jamesyoung93.github.io/treemmm-r/reference/run_config.md)
packages the pipeline parameters;
[`column_spec()`](https://jamesyoung93.github.io/treemmm-r/reference/column_spec.md)
describes which column plays which role. The defaults pick a sensible
objective based on the outcome distribution.

``` r

cfg <- run_config(
  columns = column_spec(
    customer_id  = ds$columns$customer_id,
    time_col     = ds$columns$time_col,
    outcome_col  = ds$columns$outcome_col,
    promo_vars   = ds$columns$promo_vars,
    control_vars = ds$columns$control_vars
  ),
  objective       = "auto",
  n_optuna_trials = 2L,
  n_folds         = 3L,
  min_train_frac  = 0.5,
  random_state    = 42L
)
```

### Run

``` r

result <- treemmm_run(ds$df, cfg)
```

### Inspect the result

The recovered attribution shares per channel:

``` r

sort(unlist(result$attribution_shares), decreasing = TRUE)
#>          rep_visits             samples     dtc_advertising       peer_programs 
#>          0.47204301          0.25701416          0.15664642          0.04798009 
#> digital_impressions         seasonality        market_index          conference 
#>          0.03861532          0.01688033          0.01082067          0.00000000
```

Per-fold performance metrics:

``` r

do.call(rbind, lapply(result$fold_metrics, as.data.frame))
#>   fold        r2     wmape      mae n_test
#> 1    1 0.3222962 0.7096601 1659.789    100
#> 2    2 0.4972595 0.5933536 1564.412    100
#> 3    3 0.5416289 0.5554942 1344.885    100
```

### What next

- See
  [`vignette("benchmark")`](https://jamesyoung93.github.io/treemmm-r/articles/benchmark.md)
  for a head-to-head comparison against the GLMM-Naive and GLMM-Oracle
  baselines.
- See
  [`vignette("dgp_play")`](https://jamesyoung93.github.io/treemmm-r/articles/dgp_play.md)
  for how to tune DGP parameters and inspect the planted ground truth.
- [`simulate_response()`](https://jamesyoung93.github.io/treemmm-r/reference/simulate_response.md)
  and
  [`mroi_ranking()`](https://jamesyoung93.github.io/treemmm-r/reference/mroi_ranking.md)
  show how to read marginal ROI off the fitted model.
