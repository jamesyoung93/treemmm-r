# Cross-implementation parity for the log-link attribution decomposer.

DECOMPOSER_TOL <- 1e-8

test_that("log-link decomposer matches Python including base and zero totals", {
  inp <- as.data.frame(data.table::fread(
    test_path("fixtures", "parity_decomposer_input.csv")
  ))
  expected <- as.data.frame(data.table::fread(
    test_path("fixtures", "parity_decomposer_output.csv")
  ))
  expected_global <- as.data.frame(data.table::fread(
    test_path("fixtures", "parity_decomposer_global.csv")
  ))
  shap_cols <- grep("^shap__", names(inp), value = TRUE)
  feature_names <- sub("^shap__", "", shap_cols)

  for (scenario in unique(inp$scenario)) {
    in_scenario <- inp[inp$scenario == scenario, , drop = FALSE]
    out_scenario <- expected[expected$scenario == scenario, , drop = FALSE]
    global_scenario <- expected_global[
      expected_global$scenario == scenario, , drop = FALSE
    ]
    shap_values <- as.matrix(in_scenario[, shap_cols, drop = FALSE])
    colnames(shap_values) <- feature_names
    shap_result <- list(
      shap_values = shap_values,
      expected_value = unique(in_scenario$expected_value),
      link = "log"
    )

    attribution <- treemmm:::decompose(
      shap_result,
      predictions = in_scenario$prediction,
      link = "log"
    )
    expected_matrix <- as.matrix(
      out_scenario[, c("_base", feature_names), drop = FALSE]
    )
    rownames(expected_matrix) <- NULL
    expect_equal(attribution$per_obs, expected_matrix,
                 tolerance = DECOMPOSER_TOL, info = scenario)
    expect_true(treemmm:::verify_attribution_sums(
      attribution, in_scenario$prediction, tol = DECOMPOSER_TOL
    ))

    actual_global <- unlist(treemmm:::global_attribution(attribution))
    expected_shares <- stats::setNames(
      global_scenario$share, global_scenario$variable
    )
    expect_equal(actual_global[names(expected_shares)], expected_shares,
                 tolerance = DECOMPOSER_TOL, info = scenario)
  }
})

test_that("promo_only_shares filters and renormalizes full attribution", {
  shares <- list("_base" = 0.6, rep = 0.2, digital = -0.1, control = 0.1)
  expect_equal(
    promo_only_shares(shares, c("rep", "digital")),
    c(rep = 2 / 3, digital = 1 / 3),
    tolerance = 1e-12
  )
  expect_equal(
    promo_only_shares(c(rep = 0, digital = 0), c("rep", "digital")),
    c(rep = 0, digital = 0)
  )
})
