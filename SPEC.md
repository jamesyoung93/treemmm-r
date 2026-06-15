# TreeMMM Specification

This document defines the data-generating processes (DGPs) and the benchmark metric used by both the Python TreeMMM and the R port. Both implementations must produce numerically equivalent panels at seed = 42 and the same per-channel attribution shares within float tolerance.

For the formal write-up, see the paper at https://github.com/jamesyoung93/treemmm/blob/main/paper/TreeMMM_White_Paper.md. This SPEC is the engineering-side summary that the two implementations must satisfy.

## Pharma DGP (NegBin)

- Customers: `n_customers` HCPs (default 500, headline 3,000).
- Periods: `n_periods` months (default 24, headline 36).
- Channels: `rep_visits`, `dtc_advertising`, `samples`, `peer_programs`, `digital_impressions`, `conference`.
- Heterogeneous customer sensitivity (HCS): each HCP draws a per-channel sensitivity vector from a segment-specific multivariate normal. Segments: rheumatology, dermatology.
- Targeting bias: rep visits weighted toward HCPs with higher latent prescribing potential.
- Channel correlation: digital and conference co-vary; rep visits and samples co-allocated.
- Functional form:

  $$\lambda_{i,t} = \exp\left(\beta_0 + \sum_k \beta_{i,k} f_k(x_{i,k,t}) + \gamma_1 x_{\text{rep}} x_{\text{samp}} + \gamma_2 x_{\text{dtc}} x_{\text{rep}} + \gamma_3 x_{\text{peer}} x_{\text{rep}} + \delta Z_{i,t} \right)$$
  $$y_{i,t} \sim \text{NegBin}(\lambda_{i,t}, r = 5)$$

  where `f_k` is log, sqrt, or linear per channel and `Z_{i,t}` are controls (seasonality, market_index).

- Planted interactions: `(rep_visits, samples)` strength 0.60, `(dtc_advertising, rep_visits)` strength 0.40, `(peer_programs, rep_visits)` strength 0.30.

## CPG DGP (Tweedie)

- 5 channels: `tv_grps`, `digital_spend`, `trade_promo`, `radio`, `print`.
- Heterogeneous customer sensitivity by store size (S/M/L).
- One planted interaction: `(digital_spend, trade_promo)` strength 0.35.
- Tweedie likelihood with power = 1.5; zero-inflation around 10–20%.

## SaaS DGP (ZI-Gamma)

- 5 channels: `csm_meetings`, `sdr_outreach`, `content_downloads`, `event_attendance`, `paid_search`.
- Heterogeneous customer sensitivity by tier (Enterprise, SMB).
- Two planted interactions: `(content_downloads, event_attendance)` strength 0.40, `(csm_meetings, sdr_outreach)` strength 0.25.
- Zero-inflated Gamma with ZI fraction around 30%, Gamma shape 2.0.

## Linear DGP (Gaussian) — honesty test

- 3 channels: `channel_a`, `channel_b`, `channel_c`.
- No interactions, no HCS, no targeting bias.
- Gaussian outcome with linear additive effects.
- Used to confirm that TreeMMM does not invent non-linearity where none exists; GLMM-Naive is expected to match or beat TreeMMM at panel scale on this DGP.

## Reference attribution shares

For each DGP, the **reference attribution share** per channel is computed as:

```
share_k = (L1 norm of mean-centered DGP component contribution for channel k) / sum across channels
```

This is a variance-attribution heuristic (component-magnitude decomposition), not the Shapley decomposition of the DGP function. Both implementations must compute identical reference shares from the same generated panel.

## Benchmark metric

**Attribution-share MAPE**:

```
share_mape(model, dgp) = mean over channels with reference_share > 0.005 of
                        |recovered_share - reference_share| / reference_share
```

The 0.005 threshold drops near-zero channels from the MAPE computation; both implementations must use the same threshold.

## Random seed handling

Both implementations use `random_state = 42` as the default. Because Python `numpy` and R `set.seed` use different PRNGs, exact panel equivalence is not achievable — but the planted attribution shares (which depend only on the structural coefficients, not the random draws) must match exactly. The DGP-generated panels are expected to produce attribution-share MAPE within ± 0.5 pp between the two implementations at the headline scale.

## Budget reallocation parity (v0.3.x)

The `reallocate` / `reallocate_curve` budget-simulation layer is deterministic: it water-fills a committed budget increase across customer-period cells with headroom below a per-customer cap, then predicts the incremental outcome. There is no random draw, so unlike the DGP panels the two implementations must agree on identical inputs, not merely within Monte Carlo error.

- Per-customer cap: the `cap_percentile` of observed positive touches, computed with linear interpolation. Python `np.percentile` (default) and R `quantile(..., type = 7)` use the same interpolation, so the cap matches exactly.
- Water-fill: the increment is split across below-cap cells in proportion to their headroom (cap minus current); cells at or above the cap absorb nothing and are never reduced. Overflow above total headroom is reported as the unallocatable fraction.
- Units: outputs are in model-outcome and touch units; no cost or revenue per touch is assumed.

Both implementations must reproduce the shared fixtures in `tests/testthat/fixtures/parity_*.csv` (generated from the Python package via `data-raw/generate_parity_fixtures.py`) to float tolerance.

## Version tracking

This SPEC is versioned alongside the package. Changes to DGP math require synchronized PRs against both Python and R repos with a bumped SPEC version. SPEC version: **0.3.1**.
