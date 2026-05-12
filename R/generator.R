# Configurable DGP engine for TreeMMM demo datasets.
# Port of treemmm/demo/generator.py.
#
# Generates reproducible panel datasets with known ground-truth attribution,
# heterogeneous customer sensitivity (HCS), and configurable non-linear
# response functions.
#
# Spec consistency with Python: see SPEC.md. R uses Mersenne Twister via
# set.seed() rather than PCG64 (numpy), so exact panel equivalence at seed 42
# is not achievable. The DGP coefficients and structural form match Python
# exactly; the reference attribution shares converge to the Python ones
# within Monte Carlo error (< 0.5 pp at 3000 x 36 scale).


# ---------------------------------------------------------------------------
# Response functions
# ---------------------------------------------------------------------------
.resp_linear <- function(x) x
.resp_log    <- function(x) log1p(x)
.resp_sqrt   <- function(x) sqrt(pmax(x, 0))
.resp_threshold <- function(x, lower = 0, upper = 1) {
  pmin(pmax(x - lower, 0), upper - lower)
}

.response_fn <- function(name) {
  switch(name,
         linear    = .resp_linear,
         log       = .resp_log,
         sqrt      = .resp_sqrt,
         threshold = .resp_threshold,
         stop("Unknown response type: ", name))
}


# ---------------------------------------------------------------------------
# Spec constructors (lightweight named lists with class tags)
# ---------------------------------------------------------------------------

#' Promotional variable specification
#'
#' @noRd
promo_var_spec <- function(name,
                           response = "linear",
                           response_kwargs = list(),
                           mean_weight = 1.0,
                           gen_min = 0L,
                           gen_max = 10L,
                           gen_style = "uniform_int",
                           lag = 0L,
                           gen_lambda = 2.0) {
  structure(
    list(name = name, response = response, response_kwargs = response_kwargs,
         mean_weight = mean_weight, gen_min = gen_min, gen_max = gen_max,
         gen_style = gen_style, lag = lag, gen_lambda = gen_lambda),
    class = "promo_var_spec"
  )
}

#' Control variable specification
#' @noRd
control_var_spec <- function(name,
                             weight = 0.5,
                             gen_style = "normal",
                             gen_mean = 0.0,
                             gen_std = 1.0,
                             time_varying = TRUE) {
  structure(
    list(name = name, weight = weight, gen_style = gen_style,
         gen_mean = gen_mean, gen_std = gen_std, time_varying = time_varying),
    class = "control_var_spec"
  )
}

#' Interaction specification
#' @noRd
interaction_spec <- function(var1, var2, strength = 0.5) {
  structure(list(var1 = var1, var2 = var2, strength = strength),
            class = "interaction_spec")
}

#' Heterogeneous customer sensitivity specification
#' @noRd
hcs_spec <- function(segment_col,
                     segment_means = list(),
                     covariance = NULL,
                     sensitivity_std = 0.3) {
  structure(
    list(segment_col = segment_col, segment_means = segment_means,
         covariance = covariance, sensitivity_std = sensitivity_std),
    class = "hcs_spec"
  )
}

#' Targeting bias specification
#' @noRd
targeting_bias_spec <- function(promo_var, strength = 0.5) {
  structure(list(promo_var = promo_var, strength = strength),
            class = "targeting_bias_spec")
}

#' Channel correlation specification
#' @noRd
channel_correlation_spec <- function(strength = 0.3) {
  structure(list(strength = strength), class = "channel_correlation_spec")
}


# ---------------------------------------------------------------------------
# Full DGP configuration
# ---------------------------------------------------------------------------

#' DGP configuration
#'
#' Bundle of parameters consumed by [generate_panel()].
#' @noRd
dgp_config <- function(name,
                       n_customers = 500L,
                       n_periods = 24L,
                       base_mean = 3.0,
                       base_customer_std = 0.5,
                       noise_std = 0.3,
                       distribution = "negbin",
                       negbin_overdispersion = 2.0,
                       tweedie_power = 1.5,
                       gamma_shape = 2.0,
                       zero_inflation = NULL,
                       promo_vars = list(),
                       control_vars = list(),
                       interactions = list(),
                       hcs = NULL,
                       targeting_bias = list(),
                       channel_correlation = NULL,
                       seasonality_amplitude = 0.2,
                       random_state = 42L) {
  structure(
    list(name = name, n_customers = n_customers, n_periods = n_periods,
         base_mean = base_mean, base_customer_std = base_customer_std,
         noise_std = noise_std, distribution = distribution,
         negbin_overdispersion = negbin_overdispersion,
         tweedie_power = tweedie_power, gamma_shape = gamma_shape,
         zero_inflation = zero_inflation,
         promo_vars = promo_vars, control_vars = control_vars,
         interactions = interactions, hcs = hcs,
         targeting_bias = targeting_bias,
         channel_correlation = channel_correlation,
         seasonality_amplitude = seasonality_amplitude,
         random_state = random_state),
    class = "dgp_config"
  )
}


# ---------------------------------------------------------------------------
# Multivariate normal sampler (base-R Cholesky; avoids extra deps)
# ---------------------------------------------------------------------------
.rmvn <- function(n, mu, sigma) {
  p <- length(mu)
  if (n == 1L) {
    z <- matrix(stats::rnorm(p), nrow = 1L)
  } else {
    z <- matrix(stats::rnorm(n * p), nrow = n, ncol = p)
  }
  L <- chol(sigma)            # upper triangular: L'L = sigma
  out <- z %*% L              # z %*% chol(sigma) gives MVN(0, sigma) rows
  out <- sweep(out, 2L, mu, "+")
  out
}


# ---------------------------------------------------------------------------
# The generator
# ---------------------------------------------------------------------------

#' Generate a synthetic panel from a DGP configuration
#'
#' Port of treemmm.demo.generator.generate() in the Python implementation.
#' Returns a list with `$df` (data.table), `$ground_truth` (list with
#' attribution_shares, customer_sensitivities, base_rates, seasonality), and
#' `$columns` (role mapping).
#'
#' @param config A [dgp_config()] result.
#' @return A list with class "generated_dataset".
#' @noRd
generate_panel <- function(config) {
  if (!inherits(config, "dgp_config")) {
    stop("`config` must be a dgp_config object.")
  }

  set.seed(config$random_state)

  n_c <- as.integer(config$n_customers)
  n_t <- as.integer(config$n_periods)
  promo <- config$promo_vars
  n_promo <- length(promo)

  # --- Customer-level base rates ---
  base_rates <- stats::rnorm(n_c, mean = config$base_mean,
                             sd = config$base_customer_std)

  # --- HCS: per-customer sensitivity vectors ---
  sensitivities <- matrix(1.0, nrow = n_c, ncol = n_promo)
  segments <- rep("default", n_c)
  if (!is.null(config$hcs)) {
    hcs <- config$hcs
    if (!is.null(hcs$covariance)) {
      cov_mat <- hcs$covariance
    } else {
      cov_mat <- diag(n_promo) * hcs$sensitivity_std ^ 2
    }
    seg_names <- names(hcs$segment_means)
    if (length(seg_names) > 0L) {
      # Assign segments cyclically (matches Python's i % len behavior)
      segments <- seg_names[((seq_len(n_c) - 1L) %% length(seg_names)) + 1L]
      for (i in seq_len(n_c)) {
        mean_vec <- hcs$segment_means[[segments[i]]]
        sens <- as.numeric(.rmvn(1L, mean_vec, cov_mat))
        sensitivities[i, ] <- pmax(sens, 0.05)
      }
    }
  }

  # --- Channel correlation: per-customer engagement score ---
  engagement <- rep(0.0, n_c)
  if (!is.null(config$channel_correlation)) {
    engagement <- stats::rnorm(n_c)
  }

  # --- Pre-compute seasonality ---
  seasonality <- config$seasonality_amplitude *
    cos(2 * pi * seq(0L, n_t - 1L) / 12)

  promo_names <- vapply(promo, `[[`, "", "name")
  control_names <- vapply(config$control_vars, `[[`, "", "name")
  weight_map <- setNames(vapply(promo, `[[`, 1.0, "mean_weight"), promo_names)

  # Accumulators for centered ground-truth attribution
  total_rows <- n_c * n_t
  component_values <- list()
  component_values[["_base"]]        <- numeric(total_rows)
  component_values[["_seasonality"]] <- numeric(total_rows)
  for (nm in promo_names)   component_values[[nm]] <- numeric(total_rows)
  for (nm in control_names) component_values[[nm]] <- numeric(total_rows)

  # Per-customer outputs
  out_list <- vector("list", n_c)
  row_idx <- 0L

  for (i in seq_len(n_c)) {
    base_i <- base_rates[i]

    cc_mult <- 1.0
    if (!is.null(config$channel_correlation)) {
      cc_mult <- max(0.3,
        1.0 + config$channel_correlation$strength * engagement[i])
    }

    # --- promo time series for this customer ---
    promo_series <- vector("list", n_promo)
    names(promo_series) <- promo_names
    for (j in seq_along(promo)) {
      pv <- promo[[j]]
      vals <- switch(pv$gen_style,
        uniform_int = sample.int(pv$gen_max - pv$gen_min + 1L, n_t,
                                  replace = TRUE) - 1L + pv$gen_min,
        poisson     = stats::rpois(n_t, pv$gen_lambda),
        binary      = stats::rbinom(n_t, 1, pv$gen_lambda / pv$gen_max),
        sample.int(pv$gen_max - pv$gen_min + 1L, n_t,
                   replace = TRUE) - 1L + pv$gen_min
      )
      vals <- as.numeric(vals)

      if (!is.null(config$channel_correlation)) {
        vals <- pmax(0, vals * cc_mult)
        if (pv$gen_style %in% c("uniform_int", "poisson", "binary")) {
          vals <- round(vals)
        }
      }

      for (tb in config$targeting_bias) {
        if (tb$promo_var == pv$name) {
          bias_factor <- 1.0 + tb$strength *
            ((base_i - config$base_mean) / config$base_customer_std)
          vals <- pmax(0, vals * max(0.2, bias_factor))
          if (pv$gen_style %in% c("uniform_int", "poisson", "binary")) {
            vals <- round(vals)
          }
        }
      }

      promo_series[[pv$name]] <- vals
    }

    # --- control time series ---
    control_series <- vector("list", length(config$control_vars))
    names(control_series) <- control_names
    for (cv in config$control_vars) {
      vals <- if (cv$gen_style == "binary") {
        as.numeric(stats::rbinom(n_t, 1, 0.3))
      } else if (cv$gen_style == "normal" && !cv$time_varying) {
        rep(stats::rnorm(1, cv$gen_mean, cv$gen_std), n_t)
      } else {
        stats::rnorm(n_t, cv$gen_mean, cv$gen_std)
      }
      control_series[[cv$name]] <- vals
    }

    # --- per-period outcome ---
    cust_id <- sprintf("cust_%04d", i - 1L)  # match Python's 0-indexed cust_id
    cust_rows <- vector("list", n_t)

    for (t in seq_len(n_t)) {
      eta <- base_i
      row_idx <- row_idx + 1L
      component_values[["_base"]][row_idx] <- base_i

      eta <- eta + seasonality[t]
      component_values[["_seasonality"]][row_idx] <- seasonality[t]

      promo_contribs <- setNames(numeric(n_promo), promo_names)
      for (j in seq_along(promo)) {
        pv <- promo[[j]]
        if (pv$lag > 0L && t > pv$lag) {
          x_t <- promo_series[[pv$name]][t - pv$lag]
        } else if (pv$lag > 0L) {
          x_t <- 0
        } else {
          x_t <- promo_series[[pv$name]][t]
        }
        transformed <- do.call(.response_fn(pv$response),
                               c(list(x_t), pv$response_kwargs))
        contrib <- sensitivities[i, j] * pv$mean_weight * transformed
        eta <- eta + contrib
        promo_contribs[pv$name] <- contrib
      }

      for (cv in config$control_vars) {
        contrib <- cv$weight * control_series[[cv$name]][t]
        eta <- eta + contrib
        component_values[[cv$name]][row_idx] <- contrib
      }

      for (inter in config$interactions) {
        x1 <- promo_series[[inter$var1]][t]
        x2 <- promo_series[[inter$var2]][t]
        ival <- inter$strength * x1 * x2
        eta <- eta + ival
        w1 <- weight_map[[inter$var1]]
        w2 <- weight_map[[inter$var2]]
        tot <- w1 + w2
        promo_contribs[inter$var1] <- promo_contribs[inter$var1] + ival * (w1 / tot)
        promo_contribs[inter$var2] <- promo_contribs[inter$var2] + ival * (w2 / tot)
      }

      for (nm in promo_names) {
        component_values[[nm]][row_idx] <- promo_contribs[nm]
      }

      eta <- eta + stats::rnorm(1L, 0, config$noise_std)

      y <- .draw_outcome(eta, config)

      r <- list(customer_id = cust_id,
                period = t,
                outcome = y)
      for (nm in promo_names)   r[[nm]] <- promo_series[[nm]][t]
      for (nm in control_names) r[[nm]] <- control_series[[nm]][t]
      r[["seasonality"]] <- seasonality[t]
      if (!is.null(config$hcs) && nzchar(config$hcs$segment_col)) {
        r[[config$hcs$segment_col]] <- segments[i]
      }
      cust_rows[[t]] <- r
    }

    out_list[[i]] <- data.table::rbindlist(cust_rows)
  }

  df <- data.table::rbindlist(out_list)

  # --- Compute centered ground-truth attribution shares ---
  comp_sums <- vapply(component_values,
                      function(v) sum(abs(v - mean(v))),
                      numeric(1L))
  total_abs <- sum(comp_sums)
  attribution_shares <- if (total_abs > 0) comp_sums / total_abs
                        else rep(0, length(comp_sums))
  names(attribution_shares) <- names(component_values)

  # Per-customer sensitivities (named list of named numeric vectors)
  customer_sensitivities <- vector("list", n_c)
  for (i in seq_len(n_c)) {
    cust_id <- sprintf("cust_%04d", i - 1L)
    sens_vec <- setNames(sensitivities[i, ], promo_names)
    customer_sensitivities[[cust_id]] <- sens_vec
  }

  base_rates_dict <- setNames(as.list(base_rates),
                              sprintf("cust_%04d", seq_len(n_c) - 1L))

  ground_truth <- structure(
    list(
      attribution_shares = as.list(attribution_shares),
      customer_sensitivities = customer_sensitivities,
      interactions = config$interactions,
      targeting_bias_vars = vapply(config$targeting_bias,
                                   `[[`, "", "promo_var"),
      config = config,
      base_rates = base_rates_dict,
      seasonality = seasonality
    ),
    class = "ground_truth"
  )

  control_names_with_seas <- c(control_names, "seasonality")
  columns <- list(
    customer_id  = "customer_id",
    time_col     = "period",
    outcome_col  = "outcome",
    promo_vars   = promo_names,
    control_vars = control_names_with_seas,
    categorical_vars = if (!is.null(config$hcs) &&
                           nzchar(config$hcs$segment_col)) {
      config$hcs$segment_col
    } else {
      character(0L)
    }
  )

  structure(list(df = df,
                 ground_truth = ground_truth,
                 columns = columns),
            class = "generated_dataset")
}


# ---------------------------------------------------------------------------
# Outcome distribution sampling (mirrors Python branch logic)
# ---------------------------------------------------------------------------
.draw_outcome <- function(eta, config) {
  d <- config$distribution
  if (d == "negbin") {
    mu <- max(0.01, min(exp(eta * 0.50), 5000))
    r  <- config$negbin_overdispersion
    # R's rnbinom(n, size = r, mu = mu) matches numpy parameterization
    return(as.numeric(stats::rnbinom(1L, size = r, mu = mu)))
  }
  if (d == "gaussian") {
    return(eta + stats::rnorm(1L, 0, 0.5))
  }
  if (d == "tweedie") {
    mu <- max(0.01, exp(eta * 0.18))
    zi <- if (is.null(config$zero_inflation)) 0.2 else config$zero_inflation
    k  <- config$gamma_shape
    if (stats::runif(1L) < zi) return(0)
    return(stats::rgamma(1L, shape = k, scale = mu / k))
  }
  if (d == "zi_gamma") {
    mu <- max(0.01, exp(eta * 0.22))
    zi <- if (is.null(config$zero_inflation)) 0.3 else config$zero_inflation
    k  <- config$gamma_shape
    if (stats::runif(1L) < zi) return(0)
    return(stats::rgamma(1L, shape = k, scale = mu / k))
  }
  return(max(0, eta))
}
