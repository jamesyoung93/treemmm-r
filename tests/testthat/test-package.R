test_that("package loads", {
  expect_true(requireNamespace("treemmm", quietly = TRUE))
})

test_that("Phase 4+ stubs throw helpful Not-yet-implemented errors", {
  # GLMM baselines (Phase 4)
  expect_error(fit_glmm_naive(matrix(0), 0, list()),
               "Not yet implemented \\(Phase 4\\)")
  expect_error(fit_bayesian_hier_naive(matrix(0), 0, list()),
               "Not yet implemented \\(Phase 4\\)")
})
