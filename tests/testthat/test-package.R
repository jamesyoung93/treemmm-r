test_that("package loads", {
  expect_true(requireNamespace("treemmm", quietly = TRUE))
})

test_that("stubs throw helpful Not-yet-implemented errors", {
  # Phase 2 stubs
  expect_error(generate_pharma_dataset(), "Not yet implemented \\(Phase 2\\)")
  expect_error(generate_cpg_dataset(), "Not yet implemented \\(Phase 2\\)")
  expect_error(generate_saas_dataset(), "Not yet implemented \\(Phase 2\\)")
  expect_error(generate_linear_dataset(), "Not yet implemented \\(Phase 2\\)")

  # Phase 3 stubs
  expect_error(column_spec("id", "t", "y", c("a")), "Not yet implemented \\(Phase 3\\)")
  expect_error(run_config(list()), "Not yet implemented \\(Phase 3\\)")
  expect_error(diagnose_distribution(1:10), "Not yet implemented \\(Phase 3\\)")
  expect_error(treemmm_run(data.frame(), list()), "Not yet implemented \\(Phase 3\\)")
})
