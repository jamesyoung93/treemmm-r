# treemmm: Tree-Based Marketing Mix Modeling with SHAP Attribution

Tree-based MMM using gradient-boosted trees (LightGBM, XGBoost) paired
with SHAP attribution. R port of the Python TreeMMM package
(<https://github.com/jamesyoung93/treemmm>).

## Main entry points

- [`run_config()`](https://jamesyoung93.github.io/treemmm-r/reference/run_config.md)
  and
  [`column_spec()`](https://jamesyoung93.github.io/treemmm-r/reference/column_spec.md)
  to describe a panel and pipeline.

- [`treemmm_run()`](https://jamesyoung93.github.io/treemmm-r/reference/treemmm_run.md)
  to execute the pipeline end-to-end.

- [`generate_pharma_dataset()`](https://jamesyoung93.github.io/treemmm-r/reference/generate_pharma_dataset.md)
  and siblings to produce the synthetic DGPs.

## Status

Version 0.2.1.9000 is Phase 1 (scaffold). Functions are present as stubs
that throw `Not yet implemented`. See `ROADMAP.md` for the seven-phase
plan.

## See also

Useful links:

- <https://github.com/jamesyoung93/treemmm-r>

- Report bugs at <https://github.com/jamesyoung93/treemmm-r/issues>

## Author

**Maintainer**: James Young <46870524+jamesyoung93@users.noreply.github.com>

Authors:

- James Young <46870524+jamesyoung93@users.noreply.github.com>
