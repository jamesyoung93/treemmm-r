# cran-comments

## Test environments

* local Windows install, R 4.3
* GitHub Actions: ubuntu-latest, R release
* No win-builder or rhub submission yet (deferred)

## R CMD check results

The built source tarball was checked locally on Windows with R 4.3.3 using
`R CMD check --no-manual` and `_R_CHECK_FORCE_SUGGESTS_=false`:

* 0 errors
* 0 warnings
* 1 NOTE: optional suggested packages `treeshap` and `brms` were unavailable
  in the offline check library

## Downstream dependencies

This is a fresh package; there are no reverse dependencies.

## Status

The R port is at v0.3.1. The end-to-end LightGBM/SHAP pipeline, regression
and optional Bayesian baselines, mROI and cap-bounded reallocation,
diagnostics, public adstock transforms, three vignettes, deterministic
Python/R parity fixtures, and pkgdown configuration are in place. The R port
implements the shared core workflow but does not claim full Python feature or
stochastic-DGP parity. CRAN submission remains optional; the package is usable
via `devtools::install_github`.
