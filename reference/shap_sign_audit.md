# Audit the per-channel sign distribution of SHAP values

For each feature column in a SHAP result, returns the fraction of
observations with negative / positive SHAP, the signed and unsigned
means, and the dominant sign. Useful for verifying monotone constraints
are producing the expected directional behavior (note: a
monotone-positive constraint guarantees a non-decreasing GLOBAL
response, but local SHAP values can still be negative under interaction
effects — that is mathematically expected, not a violation).

## Usage

``` r
shap_sign_audit(shap_result)
```

## Arguments

- shap_result:

  Output of `compute_shap()`.

## Value

A data.table with one row per channel.
