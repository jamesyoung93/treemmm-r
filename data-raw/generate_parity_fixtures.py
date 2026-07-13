"""Generate cross-implementation parity fixtures for the R reallocate port.

Runs the Python ``treemmm.mroi.reallocate`` / ``reallocate_curve`` on a fixed
toy panel and a deterministic linear-stub model, then writes the inputs and the
outputs to CSV.  The R suite (tests/testthat/test-reallocate-parity.R) reads the
same input panel, re-runs the R implementation, and asserts it reproduces these
numbers to float tolerance.

The reallocation algorithm is fully deterministic (water-fill arithmetic plus
model predictions, no RNG), and numpy's default ``np.percentile`` equals R's
``quantile(type = 7)``, so on identical inputs the two implementations agree to
machine precision.  The panel is generated once here (numpy RNG) and shipped as
a CSV so both sides consume byte-identical inputs.

Requires the Python ``treemmm`` package on the path.  Run from anywhere:

    python data-raw/generate_parity_fixtures.py

Floats are written with ``%.17g`` so the CSV round-trips IEEE-754 doubles
exactly.  Re-run only when the reallocation algorithm changes; commit the
refreshed tests/testthat/fixtures/parity_*.csv alongside the code change.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import pandas as pd

from treemmm.core.attribution.decomposer import decompose
from treemmm.core.interpret.shap_engine import SHAPResult
from treemmm.mroi import reallocate, reallocate_curve

OUT = Path(__file__).resolve().parents[1] / "tests" / "testthat" / "fixtures"
FLOAT_FMT = "%.17g"


class _LinearStub:
    """Copy of the test stub: predicts a positive linear combination."""

    def __init__(self, weights: dict[str, float], feature_names: list[str]):
        self._weights = weights
        self._feature_names = feature_names
        self._monotone_constraints = [
            1 if f in weights else 0 for f in feature_names
        ]
        self._model = type("_Inner", (), {"feature_name_": feature_names})()

    def predict(self, X: pd.DataFrame) -> np.ndarray:
        out = np.zeros(len(X), dtype=float)
        for col, w in self._weights.items():
            out = out + w * X[col].to_numpy(dtype=float)
        return out


def _toy_frame(n: int = 400, seed: int = 0) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    return pd.DataFrame(
        {
            "rep_visits": rng.poisson(3, n).astype(float),
            "samples": rng.poisson(2, n).astype(float),
            "control": rng.normal(size=n),
        },
        index=[f"row{i:04d}" for i in range(n)],
    )


def _plan_scalars(scenario: str, plan) -> list[dict]:
    d = plan.diagnostics
    rows = [
        ("predicted_outcome_current", plan.predicted_outcome_current),
        ("predicted_outcome_proposed", plan.predicted_outcome_proposed),
        ("predicted_incremental_outcome", plan.predicted_incremental_outcome),
        ("predicted_lift_pct", plan.predicted_lift_pct),
        ("at_cap_fraction", d.at_cap_fraction),
        ("top_decile_at_cap_fraction", d.top_decile_at_cap_fraction),
        ("mid_tier_increment_fraction", d.mid_tier_increment_fraction),
        ("unchanged_fraction", d.unchanged_fraction),
        ("unallocatable_fraction", d.unallocatable_fraction),
    ]
    for ch in plan.channels:
        rows.append((f"cap__{ch}", d.caps[ch]))
        rows.append((f"current_aggregate__{ch}", plan.current_aggregate[ch]))
        rows.append((f"proposed_aggregate__{ch}", plan.proposed_aggregate[ch]))
    return [{"scenario": scenario, "key": k, "value": v} for k, v in rows]


def _write_decomposer_fixtures() -> None:
    """Write deterministic log-link decomposer inputs and Python outputs."""
    scenarios = [
        {
            "name": "nonzero_base",
            "expected_value": 0.7,
            "predictions": np.array([4.2, 1.3], dtype=float),
            "shap_values": np.array(
                [[0.3, -0.2, 0.1], [-0.5, 0.0, 0.25]], dtype=float
            ),
        },
        {
            "name": "zero_total",
            "expected_value": 0.0,
            "predictions": np.array([2.5], dtype=float),
            "shap_values": np.zeros((1, 3), dtype=float),
        },
    ]
    feature_names = ["rep_visits", "samples", "control"]
    input_rows: list[dict] = []
    output_rows: list[dict] = []
    global_rows: list[dict] = []

    for scenario in scenarios:
        shap_values = scenario["shap_values"]
        predictions = scenario["predictions"]
        shap_result = SHAPResult(
            values=shap_values,
            expected_value=scenario["expected_value"],
            feature_names=feature_names,
            link="log",
        )
        attribution = decompose(shap_result, predictions)

        for row_idx in range(len(predictions)):
            row_id = f"row{row_idx + 1}"
            input_rows.append(
                {
                    "scenario": scenario["name"],
                    "row_id": row_id,
                    "expected_value": scenario["expected_value"],
                    "prediction": predictions[row_idx],
                    **{
                        f"shap__{name}": shap_values[row_idx, col_idx]
                        for col_idx, name in enumerate(feature_names)
                    },
                }
            )
            output_rows.append(
                {
                    "scenario": scenario["name"],
                    "row_id": row_id,
                    "_base": attribution.base_values[row_idx],
                    **{
                        name: attribution.values[row_idx, col_idx]
                        for col_idx, name in enumerate(feature_names)
                    },
                }
            )

        global_attribution = attribution.global_attribution()
        for row in global_attribution.itertuples(index=False):
            global_rows.append(
                {
                    "scenario": scenario["name"],
                    "variable": row.variable,
                    "share": row.pct_of_total / 100.0,
                }
            )

    pd.DataFrame(input_rows).to_csv(
        OUT / "parity_decomposer_input.csv", index=False, float_format=FLOAT_FMT
    )
    pd.DataFrame(output_rows).to_csv(
        OUT / "parity_decomposer_output.csv", index=False, float_format=FLOAT_FMT
    )
    pd.DataFrame(global_rows).to_csv(
        OUT / "parity_decomposer_global.csv", index=False, float_format=FLOAT_FMT
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    _write_decomposer_fixtures()
    df = _toy_frame()

    # Shared input panel (both implementations read this exact file).
    df.reset_index(names="row_id").to_csv(
        OUT / "parity_input.csv", index=False, float_format=FLOAT_FMT
    )

    cols = list(df.columns)
    scalars: list[dict] = []
    curve_rows: list[dict] = []

    # S1: single channel, +25%, cap 95.
    m_two = _LinearStub({"rep_visits": 2.0, "samples": 1.0}, cols)
    s1 = reallocate(m_two, df, budget_delta_pct=25.0, channel="rep_visits")
    scalars += _plan_scalars("S1_single", s1)
    s1.per_row.reset_index(names="row_id")[
        ["row_id", "rep_visits", "rep_visits__current", "rep_visits__increment"]
    ].to_csv(OUT / "parity_perrow.csv", index=False, float_format=FLOAT_FMT)

    # S2: multichannel, +25%, cap 95 (pooled diagnostics).
    s2 = reallocate(
        m_two, df, budget_delta_pct=25.0, channels=["rep_visits", "samples"]
    )
    scalars += _plan_scalars("S2_multi", s2)

    # S3: cap-percentile sensitivity at +25%.
    for pct in (90.0, 95.0, 98.0):
        sp = reallocate(
            m_two, df, budget_delta_pct=25.0, channel="rep_visits",
            cap_percentile=pct,
        )
        scalars += _plan_scalars(f"S3_cap{int(pct)}", sp)

    # S4: curve, no cap binding -> marginal collapses to the weight 2.5.
    m_25 = _LinearStub({"rep_visits": 2.5}, cols)
    c4 = reallocate_curve(
        m_25, df, budget_deltas=[5.0, 10.0, 20.0], channel="rep_visits"
    )
    for _, r in c4.table.iterrows():
        curve_rows.append({"scenario": "S4_curve_nobind", **r.to_dict()})
    scalars.append({
        "scenario": "S4_curve_nobind", "key": "max_allocatable_delta",
        "value": c4.max_allocatable_delta
        if c4.max_allocatable_delta is not None else math.nan,
    })

    # S5: curve, cap binding at the large level -> frontier below 1000.
    m_2 = _LinearStub({"rep_visits": 2.0}, cols)
    c5 = reallocate_curve(
        m_2, df, budget_deltas=[10.0, 25.0, 50.0, 1000.0], channel="rep_visits"
    )
    for _, r in c5.table.iterrows():
        curve_rows.append({"scenario": "S5_curve_bind", **r.to_dict()})
    scalars.append({
        "scenario": "S5_curve_bind", "key": "max_allocatable_delta",
        "value": c5.max_allocatable_delta
        if c5.max_allocatable_delta is not None else math.nan,
    })

    pd.DataFrame(scalars, columns=["scenario", "key", "value"]).to_csv(
        OUT / "parity_scalars.csv", index=False, float_format=FLOAT_FMT,
        na_rep="NA",
    )
    pd.DataFrame(curve_rows, columns=[
        "scenario", "budget_delta_pct", "added_touches",
        "predicted_incremental_outcome", "predicted_lift_pct",
        "marginal_return_per_touch", "step_marginal_return",
        "mid_tier_increment_fraction", "at_cap_fraction",
        "unallocatable_fraction",
    ]).to_csv(
        OUT / "parity_curve.csv", index=False, float_format=FLOAT_FMT,
        na_rep="NA",
    )

    print(f"wrote fixtures to {OUT}")
    for p in sorted(OUT.glob("parity_*.csv")):
        print(f"  {p.name}: {p.stat().st_size} bytes")


if __name__ == "__main__":
    main()
