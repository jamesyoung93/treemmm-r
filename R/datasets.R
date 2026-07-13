# Synthetic DGPs. Each generator returns a `generated_dataset` list with:
#   $df: a data.table of (customer, period) rows with channels, controls,
#        and the outcome
#   $columns: column role mapping
#   $ground_truth: list with $attribution_shares plus DGP coefficients
# Mirrors treemmm.demo.datasets.* in the Python package.
# Both implementations must produce numerically-equivalent attribution
# shares at seed = 42 (within Monte Carlo error). See SPEC.md.


# Adstock decay defaults, mirroring Python.
PHARMA_ADSTOCK_DECAYS <- list(
  rep_visits          = 0.5,
  dtc_advertising     = 0.3,
  samples             = 0.4,
  peer_programs       = 0.2,
  digital_impressions = 0.2,
  conference          = 0.0
)

CPG_ADSTOCK_DECAYS <- list(
  tv_grps         = 0.6,
  digital_spend   = 0.3,
  trade_promo     = 0.4,
  instore_display = 0.2,
  social_media    = 0.2
)


# ---------------------------------------------------------------------------
# Pharma brand DGP — specialty biologic in rheumatology / dermatology
# ---------------------------------------------------------------------------
.pharma_dgp_config <- function(n_customers, n_periods, random_state) {
  promo_vars <- list(
    promo_var_spec("rep_visits",          response = "log",
                   mean_weight = 2.0, gen_min = 0L, gen_max = 6L,
                   gen_style = "poisson", gen_lambda = 2.0),
    promo_var_spec("dtc_advertising",     response = "sqrt",
                   mean_weight = 1.6, gen_min = 0L, gen_max = 10L,
                   gen_style = "poisson", gen_lambda = 3.0),
    promo_var_spec("samples",             response = "linear",
                   mean_weight = 1.5, gen_min = 0L, gen_max = 6L,
                   gen_style = "poisson", gen_lambda = 2.0),
    promo_var_spec("peer_programs",       response = "sqrt",
                   mean_weight = 0.8, gen_min = 0L, gen_max = 3L,
                   gen_style = "poisson", gen_lambda = 0.8),
    promo_var_spec("digital_impressions", response = "log",
                   mean_weight = 0.5, gen_min = 0L, gen_max = 8L,
                   gen_style = "poisson", gen_lambda = 3.0),
    promo_var_spec("conference",          response = "log",
                   mean_weight = 0.3, gen_min = 0L, gen_max = 1L,
                   gen_style = "binary", gen_lambda = 0.15, lag = 2L)
  )

  control_vars <- list(
    control_var_spec("market_index", weight = 0.2,
                     gen_style = "normal", gen_mean = 0.0, gen_std = 0.5,
                     time_varying = TRUE)
  )

  interactions <- list(
    interaction_spec("rep_visits",       "samples",    strength = 0.6),
    interaction_spec("dtc_advertising",  "rep_visits", strength = 0.4),
    interaction_spec("peer_programs",    "rep_visits", strength = 0.3)
  )

  hcs <- hcs_spec(
    segment_col = "specialty",
    segment_means = list(
      rheumatology = c(1.6, 0.5, 1.5, 1.0, 0.4, 1.0),
      dermatology  = c(0.4, 1.5, 0.5, 1.0, 1.6, 1.0)
    ),
    covariance = diag(c(0.08, 0.06, 0.06, 0.05, 0.04, 0.02)),
    sensitivity_std = 0.25
  )

  targeting <- list(
    targeting_bias_spec("rep_visits", strength = 0.4),
    targeting_bias_spec("samples",    strength = 0.3)
  )

  cc <- channel_correlation_spec(strength = 0.3)

  dgp_config(
    name = "pharma_brand",
    n_customers = n_customers, n_periods = n_periods,
    base_mean = 2.5, base_customer_std = 0.4, noise_std = 0.08,
    distribution = "negbin", negbin_overdispersion = 5.0,
    promo_vars = promo_vars, control_vars = control_vars,
    interactions = interactions, hcs = hcs,
    targeting_bias = targeting, channel_correlation = cc,
    seasonality_amplitude = 0.15,
    random_state = random_state
  )
}

#' Generate the synthetic pharma DGP (NegBin)
#'
#' @inheritParams generate_pharma_dataset
#' @return A `generated_dataset` list.
#' @export
generate_pharma_dataset <- function(n_customers = 500L,
                                    n_periods = 24L,
                                    random_state = 42L,
                                    with_adstock = FALSE) {
  config <- .pharma_dgp_config(n_customers, n_periods, random_state)
  ds <- generate_panel(config)
  if (with_adstock) {
    ds <- .apply_adstock(ds, PHARMA_ADSTOCK_DECAYS)
  }
  ds
}


# ---------------------------------------------------------------------------
# CPG brand DGP — grocery retail (Tweedie)
# ---------------------------------------------------------------------------
.cpg_dgp_config <- function(n_customers, n_periods, random_state) {
  promo_vars <- list(
    promo_var_spec("tv_grps",         response = "sqrt",
                   mean_weight = 1.5, gen_max = 10L,
                   gen_style = "poisson", gen_lambda = 3.0),
    promo_var_spec("digital_spend",   response = "log",
                   mean_weight = 1.0, gen_max = 8L,
                   gen_style = "poisson", gen_lambda = 2.5),
    promo_var_spec("trade_promo",     response = "linear",
                   mean_weight = 1.2, gen_max = 5L,
                   gen_style = "poisson", gen_lambda = 1.5),
    promo_var_spec("instore_display", response = "sqrt",
                   mean_weight = 0.8, gen_max = 4L,
                   gen_style = "poisson", gen_lambda = 1.0),
    promo_var_spec("social_media",    response = "log",
                   mean_weight = 0.4, gen_max = 6L,
                   gen_style = "poisson", gen_lambda = 2.0)
  )

  control_vars <- list(
    control_var_spec("competitor_price_idx", weight = 0.3,
                     gen_style = "normal", gen_mean = 1.0, gen_std = 0.15,
                     time_varying = TRUE)
  )

  interactions <- list(
    interaction_spec("digital_spend", "trade_promo", strength = 0.35)
  )

  hcs <- hcs_spec(
    segment_col = "store_size",
    segment_means = list(
      small  = c(0.5, 0.8, 1.6, 1.6, 1.0),
      medium = c(1.0, 1.0, 1.0, 1.0, 1.0),
      large  = c(1.5, 1.2, 0.4, 0.4, 1.0)
    ),
    covariance = diag(c(0.06, 0.05, 0.06, 0.06, 0.04))
  )

  dgp_config(
    name = "cpg_brand",
    n_customers = n_customers, n_periods = n_periods,
    base_mean = 2.5, base_customer_std = 0.5, noise_std = 0.15,
    distribution = "tweedie", tweedie_power = 1.5,
    gamma_shape = 8.0, zero_inflation = 0.08,
    promo_vars = promo_vars, control_vars = control_vars,
    interactions = interactions, hcs = hcs,
    seasonality_amplitude = 0.25,
    random_state = random_state
  )
}

#' Generate the synthetic CPG DGP (Tweedie)
#'
#' @inheritParams generate_pharma_dataset
#' @return A `generated_dataset` list.
#' @export
generate_cpg_dataset <- function(n_customers = 200L,
                                 n_periods = 36L,
                                 random_state = 42L,
                                 with_adstock = FALSE) {
  config <- .cpg_dgp_config(n_customers, n_periods, random_state)
  ds <- generate_panel(config)
  if (with_adstock) {
    ds <- .apply_adstock(ds, CPG_ADSTOCK_DECAYS)
  }
  ds
}


# ---------------------------------------------------------------------------
# SaaS brand DGP — B2B SaaS (ZI-Gamma)
# ---------------------------------------------------------------------------
.saas_dgp_config <- function(n_customers, n_periods, random_state) {
  promo_vars <- list(
    promo_var_spec("sdr_outreach",      response = "sqrt",
                   mean_weight = 0.6, gen_max = 8L,
                   gen_style = "poisson", gen_lambda = 2.0),
    promo_var_spec("content_downloads", response = "log",
                   mean_weight = 1.0, gen_max = 10L,
                   gen_style = "poisson", gen_lambda = 3.0),
    promo_var_spec("paid_search",       response = "log",
                   mean_weight = 0.8, gen_max = 6L,
                   gen_style = "poisson", gen_lambda = 2.0),
    promo_var_spec("event_attendance",  response = "sqrt",
                   mean_weight = 0.9, gen_max = 3L,
                   gen_style = "poisson", gen_lambda = 0.8),
    promo_var_spec("csm_meetings",      response = "log",
                   mean_weight = 1.5, gen_max = 4L,
                   gen_style = "poisson", gen_lambda = 1.0)
  )

  control_vars <- list(
    control_var_spec("product_releases", weight = 0.25,
                     gen_style = "binary", time_varying = TRUE)
  )

  interactions <- list(
    interaction_spec("content_downloads", "event_attendance", strength = 0.40),
    interaction_spec("csm_meetings",      "sdr_outreach",     strength = 0.25)
  )

  hcs <- hcs_spec(
    segment_col = "account_tier",
    segment_means = list(
      enterprise = c(0.4, 0.8, 0.8, 0.9, 1.8),
      smb        = c(1.2, 1.3, 1.2, 1.3, 0.3)
    ),
    covariance = diag(c(0.06, 0.05, 0.05, 0.05, 0.08))
  )

  dgp_config(
    name = "saas_brand",
    n_customers = n_customers, n_periods = n_periods,
    base_mean = 1.5, base_customer_std = 0.5, noise_std = 0.15,
    distribution = "zi_gamma", gamma_shape = 8.0, zero_inflation = 0.10,
    promo_vars = promo_vars, control_vars = control_vars,
    interactions = interactions, hcs = hcs,
    seasonality_amplitude = 0.1,
    random_state = random_state
  )
}

#' Generate the synthetic SaaS DGP (ZI-Gamma)
#'
#' @inheritParams generate_pharma_dataset
#' @return A `generated_dataset` list.
#' @export
generate_saas_dataset <- function(n_customers = 500L,
                                  n_periods = 24L,
                                  random_state = 42L) {
  config <- .saas_dgp_config(n_customers, n_periods, random_state)
  generate_panel(config)
}


# ---------------------------------------------------------------------------
# Linear baseline DGP — Gaussian, no HCS, no interactions (honesty test)
# ---------------------------------------------------------------------------
.linear_dgp_config <- function(n_customers, n_periods, random_state) {
  promo_vars <- list(
    promo_var_spec("channel_a", response = "linear", mean_weight = 1.5,
                   gen_max = 10L, gen_style = "uniform_int"),
    promo_var_spec("channel_b", response = "linear", mean_weight = 1.0,
                   gen_max = 8L,  gen_style = "uniform_int"),
    promo_var_spec("channel_c", response = "linear", mean_weight = 0.5,
                   gen_max = 6L,  gen_style = "uniform_int")
  )

  control_vars <- list(
    control_var_spec("macro_index", weight = 0.3,
                     gen_style = "normal", gen_mean = 0.0, gen_std = 1.0,
                     time_varying = TRUE)
  )

  dgp_config(
    name = "linear_baseline",
    n_customers = n_customers, n_periods = n_periods,
    base_mean = 5.0, base_customer_std = 1.0, noise_std = 0.5,
    distribution = "gaussian",
    promo_vars = promo_vars, control_vars = control_vars,
    interactions = list(), hcs = NULL,
    seasonality_amplitude = 0.15,
    random_state = random_state
  )
}

#' Generate the linear baseline DGP (Gaussian, honesty test)
#'
#' Three channels (channel_a, channel_b, channel_c), no interactions, no
#' heterogeneous sensitivity. Used to confirm that TreeMMM does not invent
#' non-linearity where none exists.
#'
#' @inheritParams generate_pharma_dataset
#' @return A `generated_dataset` list.
#' @export
generate_linear_dataset <- function(n_customers = 500L,
                                    n_periods = 24L,
                                    random_state = 42L) {
  config <- .linear_dgp_config(n_customers, n_periods, random_state)
  generate_panel(config)
}


# ---------------------------------------------------------------------------
# Pharma + adstock specialty DGP
# ---------------------------------------------------------------------------

#' Generate the pharma-with-adstock specialty DGP
#'
#' Variant of [generate_pharma_dataset()] with geometric adstock planted on
#' each promotional channel. The raw channel values are stored as
#' `<channel>_raw`; the named promotional columns hold the adstocked values.
#'
#' @inheritParams generate_pharma_dataset
#' @return A `generated_dataset` list.
#' @export
generate_pharma_adstock_dataset <- function(n_customers = 500L,
                                            n_periods = 24L,
                                            random_state = 42L) {
  generate_pharma_dataset(n_customers = n_customers,
                          n_periods = n_periods,
                          random_state = random_state,
                          with_adstock = TRUE)
}


# ---------------------------------------------------------------------------
# Geo-panel DGP — approximate R stress-test, not the paper comparison DGP
# ---------------------------------------------------------------------------
.geo_panel_dgp_config <- function(n_regions, n_weeks, random_state) {
  promo_vars <- list(
    promo_var_spec("tv_grps",       response = "sqrt",
                   mean_weight = 1.8, gen_max = 10L,
                   gen_style = "poisson", gen_lambda = 3.0),
    promo_var_spec("digital_spend", response = "log",
                   mean_weight = 1.4, gen_max = 8L,
                   gen_style = "poisson", gen_lambda = 2.5),
    promo_var_spec("trade_promo",   response = "linear",
                   mean_weight = 0.6, gen_max = 5L,
                   gen_style = "poisson", gen_lambda = 1.5)
  )

  dgp_config(
    name = "geo_panel",
    n_customers = n_regions, n_periods = n_weeks,
    base_mean = 2.5, base_customer_std = 0.4, noise_std = 0.10,
    distribution = "tweedie", tweedie_power = 1.5,
    gamma_shape = 8.0, zero_inflation = 0.05,
    promo_vars = promo_vars,
    control_vars = list(),
    interactions = list(), hcs = NULL,
    seasonality_amplitude = 0.20,
    random_state = random_state
  )
}

#' Generate the geo-panel specialty DGP
#'
#' This is an approximate R-only geo-panel stress-test, not a faithful
#' implementation of the paper's aggregate-comparator DGP. Both the current
#' Python and R geo generators draw Tweedie outcomes, but this R generator
#' draws the outcome from generic square-root, log, and linear responses before
#' applying adstock only to the returned feature columns. Consequently, its
#' outcome is not planted from the transformed features. It also omits the
#' Python generator's explicit logistic saturation, market control, and region
#' sensitivity. The R decays are TV 0.6, digital 0.3, and trade 0.4; the Python
#' decays are 0.5, 0.3, and 0, respectively. Do not use this generator to claim
#' paper-DGP or cross-method equivalence.
#'
#' @param n_regions Number of geographic regions. Default 200.
#' @param n_weeks Number of weekly periods. Default 52.
#' @param random_state Integer seed.
#' @return A `generated_dataset` list.
#' @export
generate_geo_panel_dataset <- function(n_regions = 200L,
                                       n_weeks = 52L,
                                       random_state = 42L) {
  config <- .geo_panel_dgp_config(n_regions, n_weeks, random_state)
  ds <- generate_panel(config)
  decays <- CPG_ADSTOCK_DECAYS[c("tv_grps", "digital_spend", "trade_promo")]
  .apply_adstock(ds, decays)
}


# ---------------------------------------------------------------------------
# Apply geometric adstock to a generated_dataset and rebalance shares
# ---------------------------------------------------------------------------
.apply_adstock <- function(ds, decay_map) {
  df <- data.table::copy(ds$df)
  channels <- ds$columns$promo_vars
  decay_map <- decay_map[intersect(names(decay_map), channels)]

  # Preserve raw values
  for (ch in names(decay_map)) {
    df[[paste0(ch, "_raw")]] <- df[[ch]]
  }

  # Apply per-customer geometric adstock without changing row order.
  cust_col <- ds$columns$customer_id
  time_col <- ds$columns$time_col
  df <- apply_panel_adstock(
    df = df,
    time_col = time_col,
    customer_id_col = cust_col,
    channels = names(decay_map),
    decay = decay_map
  )

  # Rebalance ground-truth attribution shares by amplification factor
  gt <- ds$ground_truth
  orig <- gt$attribution_shares
  non_promo_total <- sum(unlist(orig[setdiff(names(orig), channels)]))

  amps <- vapply(channels, function(ch) {
    d <- decay_map[[ch]]
    if (is.null(d) || d <= 0) 1.0 else 1.0 / (1.0 - d)
  }, numeric(1L))
  names(amps) <- channels

  orig_promo <- vapply(channels, function(ch)
    if (is.null(orig[[ch]])) 0 else orig[[ch]], numeric(1L))
  names(orig_promo) <- channels
  amplified <- orig_promo * amps
  amp_total <- sum(amplified)
  promo_fraction <- 1.0 - non_promo_total

  new_shares <- list()
  for (k in names(orig)) {
    if (!(k %in% channels)) new_shares[[k]] <- orig[[k]]
  }
  for (ch in channels) {
    new_shares[[ch]] <- if (amp_total > 0) {
      promo_fraction * amplified[ch] / amp_total
    } else {
      orig_promo[ch]
    }
  }

  gt$attribution_shares <- new_shares

  cols <- ds$columns
  cols$with_adstock <- TRUE
  cols$adstock_decays <- decay_map

  structure(list(df = df, ground_truth = gt, columns = cols),
            class = "generated_dataset")
}
