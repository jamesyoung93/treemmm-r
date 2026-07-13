test_that("geometric adstock follows the Koyck recurrence", {
  x <- c(2, 0, 0, 0)
  expect_equal(
    apply_geometric_adstock(x, decay = 0.5),
    c(2, 1, 0.5, 0.25)
  )
  expect_equal(apply_geometric_adstock(x, decay = 0), as.numeric(x))

  matrix_x <- cbind(first = x, second = c(1, 1, 1, 1))
  transformed <- apply_geometric_adstock(matrix_x, decay = c(0.5, 0))
  expect_equal(transformed[, "first"], c(2, 1, 0.5, 0.25))
  expect_equal(transformed[, "second"], rep(1, 4))
  expect_identical(dimnames(transformed), dimnames(matrix_x))
})

test_that("geometric adstock validates input and decay", {
  expect_error(apply_geometric_adstock(letters[1:3], 0.5),
               "numeric vector or matrix")
  expect_error(apply_geometric_adstock(1:3, -0.1), "in \\[0, 1\\)")
  expect_error(apply_geometric_adstock(1:3, 1), "in \\[0, 1\\)")
  expect_error(apply_geometric_adstock(1:3, NA_real_), "finite numeric")
  expect_error(
    apply_geometric_adstock(matrix(1:6, ncol = 2), c(0.1, 0.2, 0.3)),
    "length 1 or 2"
  )
})

test_that("panel adstock resets by customer and preserves input row order", {
  df <- data.frame(
    row_tag = 1:4,
    customer = c("B", "A", "B", "A"),
    period = c(2, 2, 1, 1),
    spend = c(0, 0, 2, 1),
    unchanged = c(5, 6, 7, 8)
  )
  original <- df

  result <- apply_panel_adstock(
    df,
    time_col = "period",
    customer_id_col = "customer",
    channels = c("spend", "unchanged"),
    decay = c(spend = 0.5)
  )

  expect_identical(df, original)
  expect_identical(result$row_tag, df$row_tag)
  expect_equal(result$spend, c(1, 0.5, 2, 1))
  expect_equal(result$unchanged, df$unchanged)
})

test_that("panel adstock does not mutate data.table input", {
  df <- data.table::data.table(
    customer = c(1, 1, 2, 2),
    period = c(1, 2, 1, 2),
    spend = c(2, 0, 1, 0)
  )
  original <- data.table::copy(df)
  result <- apply_panel_adstock(
    df, "period", "customer", "spend", decay = 0.5
  )

  expect_identical(df, original)
  expect_s3_class(result, "data.table")
  expect_equal(result$spend, c(2, 1, 1, 0.5))
})

test_that("panel adstock validates required and numeric columns", {
  df <- data.frame(customer = c("A", "A"), period = 1:2,
                   spend = c(1, 0), label = c("x", "y"))

  expect_error(
    apply_panel_adstock(df, "missing", "customer", "spend", 0.5),
    "Columns not found"
  )
  expect_error(
    apply_panel_adstock(df, "period", "customer", "missing", 0.5),
    "Columns not found"
  )
  expect_error(
    apply_panel_adstock(df, "period", "customer", "label", 0.5),
    "must be numeric"
  )
  expect_error(
    apply_panel_adstock(df, "period", "customer", "spend", c(0.2, 0.3)),
    "must be named"
  )
})
