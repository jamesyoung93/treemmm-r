# Package index

## Pipeline

Configure and run TreeMMM end-to-end.

- [`run_config()`](https://jamesyoung93.github.io/treemmm-r/reference/run_config.md)
  : Build a TreeMMM pipeline configuration
- [`column_spec()`](https://jamesyoung93.github.io/treemmm-r/reference/column_spec.md)
  : Declare which columns play which role in a panel
- [`treemmm_run()`](https://jamesyoung93.github.io/treemmm-r/reference/treemmm_run.md)
  : Run the TreeMMM pipeline on a panel dataset
- [`diagnose_distribution()`](https://jamesyoung93.github.io/treemmm-r/reference/diagnose_distribution.md)
  : Diagnose the appropriate outcome distribution from data

## Synthetic DGPs

Reproducible panel data with known ground truth.

- [`generate_pharma_dataset()`](https://jamesyoung93.github.io/treemmm-r/reference/generate_pharma_dataset.md)
  : Generate the synthetic pharma DGP (NegBin)
- [`generate_cpg_dataset()`](https://jamesyoung93.github.io/treemmm-r/reference/generate_cpg_dataset.md)
  : Generate the synthetic CPG DGP (Tweedie)
- [`generate_saas_dataset()`](https://jamesyoung93.github.io/treemmm-r/reference/generate_saas_dataset.md)
  : Generate the synthetic SaaS DGP (ZI-Gamma)
- [`generate_linear_dataset()`](https://jamesyoung93.github.io/treemmm-r/reference/generate_linear_dataset.md)
  : Generate the linear baseline DGP (Gaussian, honesty test)
- [`generate_pharma_adstock_dataset()`](https://jamesyoung93.github.io/treemmm-r/reference/generate_pharma_adstock_dataset.md)
  : Generate the pharma-with-adstock specialty DGP
- [`generate_geo_panel_dataset()`](https://jamesyoung93.github.io/treemmm-r/reference/generate_geo_panel_dataset.md)
  : Generate the geo-panel specialty DGP

## Baselines

Regression and Bayesian baseline fitters for benchmark comparison.

- [`fit_glmm_naive()`](https://jamesyoung93.github.io/treemmm-r/reference/fit_glmm_naive.md)
  : Fit the GLMM-Naive baseline (main effects + random customer
  intercept)
- [`fit_glmm_oracle()`](https://jamesyoung93.github.io/treemmm-r/reference/fit_glmm_oracle.md)
  : Fit the GLMM-Oracle baseline (main effects + planted interactions)
- [`fit_glmm_distributional()`](https://jamesyoung93.github.io/treemmm-r/reference/fit_glmm_distributional.md)
  : Fit the distributional-GLM baseline (correct family, no random
  effects)
- [`fit_glmm_distributional_oracle()`](https://jamesyoung93.github.io/treemmm-r/reference/fit_glmm_distributional_oracle.md)
  : Fit the GLMMDist-Oracle baseline (distributional GLM + planted
  interactions)
- [`fit_bayesian_hier_naive()`](https://jamesyoung93.github.io/treemmm-r/reference/fit_bayesian_hier_naive.md)
  : Fit the PyMC-Hier-Naive baseline via brms
- [`fit_bayesian_hier_oracle()`](https://jamesyoung93.github.io/treemmm-r/reference/fit_bayesian_hier_oracle.md)
  : Fit the PyMC-Hier-Oracle baseline via brms (+ planted interactions)
- [`fit_glmm_hybrid()`](https://jamesyoung93.github.io/treemmm-r/reference/fit_glmm_hybrid.md)
  : Fit the tree-to-GLMM hybrid baseline

## Marginal ROI

Response-curve sweeps, mROI ranking, and budget reallocation.

- [`simulate_response()`](https://jamesyoung93.github.io/treemmm-r/reference/simulate_response.md)
  : Sweep allocation 0-150 percent of observed level and return the
  response curve
- [`mroi_ranking()`](https://jamesyoung93.github.io/treemmm-r/reference/mroi_ranking.md)
  : Estimate marginal ROI (mROI) per channel
- [`mroi_benchmark()`](https://jamesyoung93.github.io/treemmm-r/reference/mroi_benchmark.md)
  : Benchmark model mROI against DGP ground-truth mROI
- [`optimize_budget()`](https://jamesyoung93.github.io/treemmm-r/reference/optimize_budget.md)
  : Reallocate a fixed budget across channels to maximize predicted
  outcome

## Diagnostics

Coverage, variation decomposition, ESS, SHAP-sign audit.

- [`coverage_check()`](https://jamesyoung93.github.io/treemmm-r/reference/coverage_check.md)
  : Coverage check: count training neighbors within a radius
- [`variation_decomposition()`](https://jamesyoung93.github.io/treemmm-r/reference/variation_decomposition.md)
  : Decompose total predictor variance into within- and between-unit
  shares
- [`tree_ess_per_param()`](https://jamesyoung93.github.io/treemmm-r/reference/tree_ess_per_param.md)
  : Effective-sample-size analog for a tree learner
- [`shap_sign_audit()`](https://jamesyoung93.github.io/treemmm-r/reference/shap_sign_audit.md)
  : Audit the per-channel sign distribution of SHAP values
