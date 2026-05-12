# Benchmarking TreeMMM Against Regression Baselines

## Benchmarking TreeMMM head to head

The Python TreeMMM paper benchmarks the tree-based pipeline against
three regression families on four synthetic DGPs. This vignette runs the
same benchmark on the pharma DGP at a small scale so the result fits in
a local R session.

### Setup

``` r

library(treemmm)

ds <- generate_pharma_dataset(
  n_customers  = 100,
  n_periods    = 12,
  random_state = 42
)

cfg <- run_config(
  columns = column_spec(
    customer_id  = ds$columns$customer_id,
    time_col     = ds$columns$time_col,
    outcome_col  = ds$columns$outcome_col,
    promo_vars   = ds$columns$promo_vars,
    control_vars = ds$columns$control_vars
  ),
  objective    = "auto",
  random_state = 42L
)
```

### TreeMMM

``` r

tree_result <- treemmm_run(ds$df, cfg)
tree_shares <- unlist(tree_result$attribution_shares)
```

### GLMM-Naive (main effects only, random customer intercept)

``` r

glmm_naive <- fit_glmm_naive(ds$df, cfg)
naive_shares <- unlist(glmm_naive$attribution_shares)
```

### GLMM-Oracle (planted interactions given)

``` r

glmm_oracle <- fit_glmm_oracle(ds$df, cfg, ds$ground_truth$interactions)
oracle_shares <- unlist(glmm_oracle$attribution_shares)
```

### Distributional-GLM ablation

This isolates “did the wrong link function fix the problem?”. A
distributional GLM with the matched Poisson likelihood replaces the
log1p transform used by GLMM-Naive.

``` r

glmm_dist <- fit_glmm_distributional(ds$df, cfg)
dist_shares <- unlist(glmm_dist$attribution_shares)
```

### Compare attribution shares

Each baseline’s recovered share per promotional channel, side by side
with the planted DGP reference share:

``` r

promo <- ds$columns$promo_vars
true_shares <- unlist(ds$ground_truth$attribution_shares)[promo]

cmp <- data.frame(
  channel    = promo,
  truth      = round(true_shares,                   3),
  treemmm    = round(tree_shares[promo],            3),
  glmm_naive = round(naive_shares[promo],           3),
  glmm_orcl  = round(oracle_shares[promo],          3),
  glmm_dist  = round(dist_shares[promo],            3),
  row.names  = NULL
)
cmp
#>               channel truth treemmm glmm_naive glmm_orcl glmm_dist
#> 1          rep_visits 0.361   0.419      0.347     0.427     0.282
#> 2     dtc_advertising 0.190   0.164      0.225     0.193     0.241
#> 3             samples 0.305   0.291      0.279     0.290     0.299
#> 4       peer_programs 0.053   0.040      0.077     0.059     0.056
#> 5 digital_impressions 0.040   0.030      0.045     0.023     0.023
#> 6          conference 0.004   0.001      0.001     0.005     0.020
```

### Attribution-share MAPE (lower is better)

``` r

mape <- function(recovered, truth) {
  active <- truth > 0.005
  mean(abs(recovered[active] - truth[active]) / truth[active])
}

c(
  treemmm    = mape(tree_shares[promo],   true_shares),
  glmm_naive = mape(naive_shares[promo],  true_shares),
  glmm_orcl  = mape(oracle_shares[promo], true_shares),
  glmm_dist  = mape(dist_shares[promo],   true_shares)
)
#>    treemmm glmm_naive  glmm_orcl  glmm_dist 
#>  0.1718523  0.1736835  0.1589810  0.1978675
```

At small scale results are noisy. The Python paper’s headline values
(3,000 customers x 36 months, N=5 seeds) are TreeMMM 17.9 +/- 0.2 vs.
GLMM-Naive 22.2 +/- 0.3.

### Marginal ROI

``` r

mroi_ranking(tree_result, channels = promo)
#>          rep_visits     dtc_advertising             samples digital_impressions 
#>           269.38132           169.51215           168.63796            35.95923 
#>       peer_programs          conference 
#>             0.00000             0.00000
```

Compare the model’s mROI ranking against the DGP’s:

``` r

bench <- mroi_benchmark(tree_result, ds)
bench$rank_correlation
#> [1] 0.840668
bench$direction_accuracy
#> [1] 0.6666667
bench$table
#>                channel model_mroi  true_share
#>                 <char>      <num>       <num>
#> 1:          rep_visits  269.38132 0.360963182
#> 2:     dtc_advertising  169.51215 0.189770001
#> 3:             samples  168.63796 0.305462192
#> 4:       peer_programs    0.00000 0.053305953
#> 5: digital_impressions   35.95923 0.040495114
#> 6:          conference    0.00000 0.004253207
```
