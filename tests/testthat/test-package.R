test_that("package loads", {
  expect_true(requireNamespace("treemmm", quietly = TRUE))
})

test_that("package citation is present and renderable", {
  package_path <- system.file(package = "treemmm")
  installed_layout <- file.exists(
    file.path(dirname(package_path), "treemmm", "DESCRIPTION")
  )
  citation <- if (installed_layout) {
    utils::citation("treemmm")
  } else {
    utils::readCitationFile(
      system.file("CITATION", package = "treemmm"),
      meta = list(Package = "treemmm", Version = "0.3.1")
    )
  }

  expect_s3_class(citation, "citation")
  rendered <- format(citation, style = "text")
  expect_true(length(rendered) > 0L)
  expect_match(paste(rendered, collapse = " "), "ARXIV_ID", fixed = TRUE)
  expect_false(grepl("doi", paste(rendered, collapse = " "),
                     ignore.case = TRUE))
})
