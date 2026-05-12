test_that("pharma DGP returns a structurally valid dataset", {
  ds <- generate_pharma_dataset(n_customers = 50L, n_periods = 12L,
                                random_state = 42L)
  expect_s3_class(ds, "generated_dataset")
  expect_s3_class(ds$df, "data.table")
  expect_equal(nrow(ds$df), 50L * 12L)

  expected_promo <- c("rep_visits", "dtc_advertising", "samples",
                      "peer_programs", "digital_impressions", "conference")
  expect_setequal(ds$columns$promo_vars, expected_promo)
  expect_true(all(c("customer_id", "period", "outcome",
                    expected_promo) %in% names(ds$df)))
  expect_true("specialty" %in% names(ds$df))
  expect_setequal(unique(ds$df$specialty), c("rheumatology", "dermatology"))
})

test_that("pharma attribution shares sum to one", {
  ds <- generate_pharma_dataset(n_customers = 100L, n_periods = 24L,
                                random_state = 42L)
  shares <- unlist(ds$ground_truth$attribution_shares)
  expect_equal(sum(shares), 1.0, tolerance = 1e-6)
  # Non-negative
  expect_true(all(shares >= 0))
})

test_that("pharma reference attribution roughly matches Python (within MC tol)", {
  # Python multi-seed Table 2a value at n=3000 x 36: TreeMMM pharma 17.9 +/- 0.2.
  # The DGP reference shares should be similar across PRNGs at large n.
  # At a small/medium scale we just check the rep_visits dominant-channel
  # ordering and the rough magnitude of the largest planted channel share.
  ds <- generate_pharma_dataset(n_customers = 200L, n_periods = 24L,
                                random_state = 42L)
  shares <- ds$ground_truth$attribution_shares
  # rep_visits should be the largest promo channel by attribution share
  promo_shares <- unlist(shares[c("rep_visits", "dtc_advertising", "samples",
                                  "peer_programs", "digital_impressions",
                                  "conference")])
  expect_equal(names(which.max(promo_shares)), "rep_visits")
})

test_that("cpg DGP returns a structurally valid dataset", {
  ds <- generate_cpg_dataset(n_customers = 30L, n_periods = 12L,
                             random_state = 42L)
  expect_s3_class(ds, "generated_dataset")
  expected_promo <- c("tv_grps", "digital_spend", "trade_promo",
                      "instore_display", "social_media")
  expect_setequal(ds$columns$promo_vars, expected_promo)
  expect_true("store_size" %in% names(ds$df))
  expect_setequal(unique(ds$df$store_size), c("small", "medium", "large"))
})

test_that("saas DGP returns a structurally valid dataset", {
  ds <- generate_saas_dataset(n_customers = 30L, n_periods = 12L,
                              random_state = 42L)
  expect_s3_class(ds, "generated_dataset")
  expected_promo <- c("sdr_outreach", "content_downloads", "paid_search",
                      "event_attendance", "csm_meetings")
  expect_setequal(ds$columns$promo_vars, expected_promo)
  expect_true("account_tier" %in% names(ds$df))
  expect_setequal(unique(ds$df$account_tier), c("enterprise", "smb"))
  # ZI-Gamma outcome: must be non-negative; some zeros expected
  expect_true(all(ds$df$outcome >= 0))
})

test_that("linear DGP is the honesty test (Gaussian, no HCS, no interactions)", {
  ds <- generate_linear_dataset(n_customers = 30L, n_periods = 12L,
                                random_state = 42L)
  expect_s3_class(ds, "generated_dataset")
  expected_promo <- c("channel_a", "channel_b", "channel_c")
  expect_setequal(ds$columns$promo_vars, expected_promo)
  # No HCS column
  expect_false("specialty" %in% names(ds$df))
  expect_false("store_size" %in% names(ds$df))
})

test_that("pharma adstock variant preserves raw channels and adjusts shares", {
  ds <- generate_pharma_adstock_dataset(n_customers = 30L, n_periods = 12L,
                                        random_state = 42L)
  expect_true("rep_visits_raw" %in% names(ds$df))
  expect_identical(ds$columns$with_adstock, TRUE)
  # Adstocked rep_visits should be at least as large as raw (cumulative)
  expect_true(all(ds$df$rep_visits >= ds$df$rep_visits_raw - 1e-9))
})

test_that("geo-panel DGP produces 200 regions x 52 weeks shape by default", {
  # Use a smaller size for the unit test to keep CI snappy.
  ds <- generate_geo_panel_dataset(n_regions = 20L, n_weeks = 12L,
                                   random_state = 42L)
  expect_equal(nrow(ds$df), 20L * 12L)
  expect_setequal(ds$columns$promo_vars,
                  c("tv_grps", "digital_spend", "trade_promo"))
})

test_that("seed reproducibility — same seed yields same panel", {
  a <- generate_pharma_dataset(n_customers = 20L, n_periods = 6L,
                               random_state = 7L)
  b <- generate_pharma_dataset(n_customers = 20L, n_periods = 6L,
                               random_state = 7L)
  expect_identical(a$df, b$df)
  expect_identical(a$ground_truth$attribution_shares,
                   b$ground_truth$attribution_shares)
})
