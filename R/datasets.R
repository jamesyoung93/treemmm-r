# Synthetic DGPs. Each generator produces a list with:
#   $df: a data.table of (customer, period) rows with channels, controls,
#        and the outcome
#   $columns: column_spec describing role of each column
#   $ground_truth: list with $attribution_shares plus DGP coefficients
# Mirrors treemmm.demo.datasets.* in the Python package.
# Both implementations must produce numerically-equivalent attribution shares
# at seed = 42. See SPEC.md for the formal specification.
# TODO Phase 2: port all DGP generators.

#' Generate the synthetic pharma DGP (NegBin)
#'
#' Mirrors `treemmm.demo.datasets.pharma_brand.generate_pharma_dataset` in the
#' Python package. Six promotional channels (rep_visits, dtc_advertising,
#' samples, peer_programs, digital_impressions, conference), heterogeneous
#' customer sensitivity by specialty (rheumatology vs dermatology), targeting
#' bias, three planted channel interactions.
#'
#' @param n_customers Number of HCPs.
#' @param n_periods Number of monthly periods.
#' @param random_state Integer seed.
#' @param with_adstock Whether to plant geometric adstock decay. Defaults `FALSE`.
#' @return A `generated_dataset` list.
#' @export
generate_pharma_dataset <- function(n_customers = 500L,
                                    n_periods = 24L,
                                    random_state = 42L,
                                    with_adstock = FALSE) {
  stop("Not yet implemented (Phase 2). See ROADMAP.md.")
}

#' Generate the synthetic CPG DGP (Tweedie)
#'
#' Five channels (tv_grps, digital_spend, trade_promo, radio, print), store-size
#' heterogeneous customer sensitivity (small/medium/large), one planted
#' interaction, zero-inflated continuous outcome with Tweedie likelihood.
#'
#' @inheritParams generate_pharma_dataset
#' @return A `generated_dataset` list.
#' @export
generate_cpg_dataset <- function(n_customers = 500L,
                                 n_periods = 24L,
                                 random_state = 42L) {
  stop("Not yet implemented (Phase 2). See ROADMAP.md.")
}

#' Generate the synthetic SaaS DGP (ZI-Gamma)
#'
#' Five channels (csm_meetings, sdr_outreach, content_downloads, event_attendance,
#' paid_search), tier-based heterogeneous customer sensitivity (Enterprise/SMB),
#' two planted interactions, zero-inflated Gamma outcome.
#'
#' @inheritParams generate_pharma_dataset
#' @return A `generated_dataset` list.
#' @export
generate_saas_dataset <- function(n_customers = 500L,
                                  n_periods = 24L,
                                  random_state = 42L) {
  stop("Not yet implemented (Phase 2). See ROADMAP.md.")
}

#' Generate the linear honesty-test DGP (Gaussian)
#'
#' Three channels (channel_a, channel_b, channel_c), no interactions, no
#' heterogeneous sensitivity, linear additive effects. Used to confirm that
#' TreeMMM does not invent non-linearity where none exists; GLMM should match
#' or beat TreeMMM at panel scale on this DGP.
#'
#' @inheritParams generate_pharma_dataset
#' @return A `generated_dataset` list.
#' @export
generate_linear_dataset <- function(n_customers = 500L,
                                    n_periods = 24L,
                                    random_state = 42L) {
  stop("Not yet implemented (Phase 2). See ROADMAP.md.")
}

#' Generate the pharma-with-adstock DGP (NegBin + geometric carryover)
#'
#' Variant of `generate_pharma_dataset()` with geometric adstock planted on
#' `rep_visits`. Used to benchmark adstock-aware preprocessing.
#'
#' @inheritParams generate_pharma_dataset
#' @param decay Geometric adstock decay rate on `rep_visits`. Default 0.5.
#' @return A `generated_dataset` list.
#' @export
generate_pharma_adstock_dataset <- function(n_customers = 500L,
                                            n_periods = 24L,
                                            random_state = 42L,
                                            decay = 0.5) {
  stop("Not yet implemented (Phase 2). See ROADMAP.md.")
}

#' Generate the geo-panel DGP (Tweedie, 200 regions x 52 weeks)
#'
#' DGP designed to give aggregate-Bayesian methods their home turf: three
#' channels (tv_grps, digital_spend, trade_promo) with planted geometric
#' adstock and logistic saturation. Used in the geo-panel comparison vs
#' PyMC-Marketing / Robyn / Meridian.
#'
#' @param n_regions Number of geographic regions. Default 200.
#' @param n_weeks Number of weekly periods. Default 52.
#' @param random_state Integer seed.
#' @return A `generated_dataset` list.
#' @export
generate_geo_panel_dataset <- function(n_regions = 200L,
                                       n_weeks = 52L,
                                       random_state = 42L) {
  stop("Not yet implemented (Phase 2). See ROADMAP.md.")
}
