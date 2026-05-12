# Preprocessing transforms. Mirrors treemmm.core.preprocessing in the Python package.
# TODO Phase 3-5: implement geometric adstock + per-channel decay maps.

# apply_geometric_adstock applies a geometric decay transform to a single
# channel: x_adstocked[t] = x[t] + decay * x_adstocked[t-1].
# Operates per customer.
# TODO Phase 3.
apply_geometric_adstock <- function(df,
                                    channel_col,
                                    customer_col,
                                    time_col,
                                    decay) {
  stop("Not yet implemented (Phase 3). See ROADMAP.md.")
}

# apply_adstock_panel applies channel-specific decays across a panel.
# TODO Phase 5.
apply_adstock_panel <- function(df,
                                customer_col,
                                time_col,
                                decay_map) {
  stop("Not yet implemented (Phase 5). See ROADMAP.md.")
}
