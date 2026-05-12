# cran-comments

## Test environments

* local Windows install, R 4.3
* GitHub Actions: ubuntu-latest, R release
* No win-builder or rhub submission yet (deferred)

## R CMD check results

`R CMD check --no-manual --no-build-vignettes --ignore-vignettes` passes
with the documented status:

* 0 errors
* 0 warnings
* a small number of NOTES (typical for an initial CRAN submission):
  * "New submission" — first time on CRAN
  * "GNU make is a SystemRequirements" — inherited from the `lightgbm`
    dependency
  * Possibly "no man pages found" when run without first calling
    `roxygen2::roxygenize()`; the CI workflow runs that step automatically

## Downstream dependencies

This is a fresh package; there are no reverse dependencies.

## Status

The R port is at v0.2.1, mirroring the Python TreeMMM v0.2.1 release. The
core pipeline, six baselines, mROI module, diagnostics suite, three
vignettes, and pkgdown configuration are all in place. CRAN submission
is optional; the package is fully usable via `devtools::install_github`
in the meantime.
