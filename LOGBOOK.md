# TreeMMM R-port logbook

## 2026-07-13 — Pre-preprint Track A remediation (A5–A9)

**Hypotheses.** Tuning leakage could be eliminated by reserving a validation
window inside each outer training fold; log-link attribution could match the
Python response-scale decomposition when the base contribution is included;
decision helpers could safely infer promotional channels from the stored run
configuration; and public adstock transforms could replace the private
recurrence without altering current synthetic outputs.

**Result.** Implemented and tested all four hypotheses. Per-item R 4.3.3
documentation/test gates passed with 283 tests after A5, 291 after A6, 298
after A7, 319 after A8, and 323 after A9, with no test failures, warnings, or
skips at each final gate. A normal source-tarball build including vignettes
completed successfully. `R CMD check --no-manual` with
`_R_CHECK_FORCE_SUGGESTS_=false` finished with 0 errors, 0 warnings, and 1 NOTE
for unavailable optional Suggests (`treeshap`, `brms`). Deterministic Python
fixtures now cover the log-link decomposer as well as budget reallocation.

**Interpretation.** The R package now has explicit tuning/evaluation
separation, promo-only defaults for decision helpers, reusable and
non-mutating panel adstock preprocessing, an installed-package citation, and
truthful parity/DGP documentation. The published README verification values
were not edited, and the expensive C1/C2 benchmark reruns were intentionally
left for the later validation track.
