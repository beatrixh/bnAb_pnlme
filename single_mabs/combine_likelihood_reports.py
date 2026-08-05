from __future__ import annotations

from pathlib import Path

import pandas as pd

from report_likelihood import PROJECTS, build_report

OUT_PATH = Path("/mnt/c/Users/bhaddock/repos/bnAb_pnlme/single_mabs/combined_likelihood_report.csv")


def main() -> None:
    reports = []
    for project in PROJECTS:
        report = build_report(project)
        report.insert(0, "project", project)
        reports.append(report)

    # pd.concat aligns on column name and fills any column missing from one
    # side (e.g. s_random/s_mab_virus/s_goes_down, which only 5PL has) with
    # NaN for the other project's rows.
    combined = pd.concat(reports, ignore_index=True, sort=False)

    front = ["project", "model"]
    toggle_cols = [c for c in combined.columns if c not in front + ["AIC", "BICc"]]
    combined = combined[front + toggle_cols + ["AIC", "BICc"]]
    combined = combined.sort_values("BICc", na_position="last").reset_index(drop=True)

    print(combined.to_string(index=False))
    combined.to_csv(OUT_PATH, index=False)
    print(f"\nwrote {OUT_PATH}")


if __name__ == "__main__":
    main()
