"""Summarize benchmark CSV results per case and overall."""

import csv
import sys
from pathlib import Path
from collections import defaultdict


def load_results(directory: Path) -> list[dict]:
    rows = []
    for csv_path in sorted(directory.glob("*.csv")):
        with csv_path.open() as f:
            for row in csv.DictReader(f):
                rows.append(row)
    return rows


def summarize(directory: Path, label: str | None = None):
    rows = load_results(directory)
    if not rows:
        print(f"  No results in {directory}")
        return

    label = label or directory.parent.name
    cases = defaultdict(list)
    for row in rows:
        cases[row["case_name"]].append(row)

    print(f"\n{'='*70}")
    print(f"  {label}  ({len(rows)} runs, {len(cases)} cases)")
    print(f"{'='*70}")
    print(f"  {'Case':<14} {'Runs':>5} {'Recovery%':>10} {'Med Evals':>11} {'Med Time':>9} {'Mean R²':>9}")
    print(f"  {'-'*14} {'-'*5} {'-'*10} {'-'*11} {'-'*9} {'-'*9}")

    total_success = 0
    total_runs = 0

    for case_name in sorted(cases.keys(), key=lambda n: int(n.split("-")[-1].rstrip("*")) if n.split("-")[-1].rstrip("*").isdigit() else 999):
        case_rows = cases[case_name]
        n = len(case_rows)
        successes = sum(1 for r in case_rows if r["success"].lower() == "true")
        evals = sorted(int(r["evaluations"]) for r in case_rows)
        times = sorted(float(r["time_sec"]) for r in case_rows)
        test_r2s = [float(r["test_r2"]) for r in case_rows if r["test_r2"] != "nan"]

        med_evals = evals[len(evals) // 2]
        med_time = times[len(times) // 2]
        mean_r2 = sum(test_r2s) / len(test_r2s) if test_r2s else float("nan")
        recovery = 100.0 * successes / n

        total_success += successes
        total_runs += n

        print(f"  {case_name:<14} {n:>5} {recovery:>9.1f}% {med_evals:>11,} {med_time:>8.1f}s {mean_r2:>9.4f}")

    overall = 100.0 * total_success / total_runs if total_runs else 0
    print(f"  {'-'*14} {'-'*5} {'-'*10} {'-'*11} {'-'*9} {'-'*9}")
    print(f"  {'OVERALL':<14} {total_runs:>5} {overall:>9.2f}%")
    print()


if __name__ == "__main__":
    dirs = [Path(a) for a in sys.argv[1:]]
    if not dirs:
        print("Usage: python summarize_results.py <results_dir> [<results_dir2> ...]")
        sys.exit(1)
    for d in dirs:
        summarize(d)
