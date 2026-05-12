test_that("package loads", {
  expect_true(requireNamespace("treemmm", quietly = TRUE))
})

test_that("Phase 3+ stubs throw helpful Not-yet-implemented errors", {
  # Phase 3 stubs (pipeline + config infrastructure)
  expect_error(column_spec("id", "t", "y", c("a")), "Not yet implemented \\(Phase 3\\)")
  expect_error(run_config(list()), "Not yet implemented \\(Phase 3\\)")
  expect_error(diagnose_distribution(1:10), "Not yet implemented \\(Phase 3\\)")
  expect_error(treemmm_run(data.frame(), list()), "Not yet implemented \\(Phase 3\\)")
})
