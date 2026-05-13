#!/usr/bin/env bash
set -euo pipefail

# Usage: ./run_seed_bias_benchmark.sh [GROUP]
# GROUP defaults to Nguyen. Examples: Nguyen, Livermore, Jin, NguyenC

GROUP="${1:-Nguyen}"
GROUP_LOWER=$(echo "$GROUP" | tr '[:upper:]' '[:lower:]')

COMMIT_MT="48d10f2"   # upstream + seed-source CLI (MT19937)
COMMIT_PCG="5f2b5c3"  # upstream + seed-source + PCG64DXSM

RESULTS_ROOT="results_seed_bias/${GROUP_LOWER}"
LOG_DIR="$RESULTS_ROOT/logs"
SUMMARIZE="$(cd "$(dirname "$0")" && pwd)/summarize_results.py"

mkdir -p "$LOG_DIR"

# ── System info ──
{
    echo "=== System Info ==="
    echo "Date:     $(date -Iseconds)"
    echo "Host:     $(hostname)"
    echo "CPU:      $(lscpu | grep 'Model name' | sed 's/.*: *//')"
    echo "Cores:    $(nproc)"
    echo "RAM:      $(free -h | awk '/Mem:/{print $2}')"
    echo ""
    echo "=== Benchmark ==="
    echo "Group:    $GROUP"
    echo ""
    echo "=== Branch commits ==="
    git log --oneline benchmark/seed-bias -5
    echo ""
    echo "=== Hyperparameters (from basic.yaml, NOT paper Table 4) ==="
    echo "c=6.0 (paper: 1)  gp_rate=0.5 (paper: 0.2)  exploration_rate=0.1 (paper: 0.2)"
    echo "gamma=0.5  mutation_rate=0.1  K=500  max_depth=6  max_evals=2000000"
    echo "lm_iterations=50  max_constants=10  test_ratio=0.5  sample_multiplier=2.0"
    echo "HP changed by upstream in commits 04e143a and 6012a9d after publication."
    echo ""
} | tee "$RESULTS_ROOT/system_info.txt"

run_variant() {
    local name="$1"
    local commit="$2"
    local seed_source="$3"
    local output_dir="$RESULTS_ROOT/$name/$GROUP_LOWER"
    local log_file="$LOG_DIR/${name}.log"

    echo ""
    echo "================================================================"
    echo "  VARIANT: $name"
    echo "  Commit:  $(git log --oneline -1 "$commit")"
    echo "  Seeds:   $seed_source"
    echo "  Group:   $GROUP"
    echo "  Output:  $output_dir"
    echo "  Started: $(date -Iseconds)"
    echo "================================================================"

    git checkout "$commit" --quiet
    pip install -e . --no-build-isolation --quiet 2>&1 | tail -2

    python -m imcts.benchmarks \
        --group "$GROUP" \
        --cases all \
        --runs 100 \
        --seed-source "$seed_source" \
        --output "$output_dir" \
        --workers "$(nproc)" \
        2>&1 | tee "$log_file"

    echo ""
    echo "  Variant $name finished: $(date -Iseconds)"
    python3 "$SUMMARIZE" "$output_dir" | tee "$RESULTS_ROOT/${name}_summary.txt"
}

echo "Starting 3-variant seed bias benchmark ($GROUP) at $(date -Iseconds)"

run_variant "mt19937-srbench" "$COMMIT_MT" "srbench"
run_variant "mt19937-quantum" "$COMMIT_MT" "quantum"
run_variant "pcg-quantum"     "$COMMIT_PCG" "quantum"

git checkout benchmark/seed-bias --quiet

echo ""
echo "================================================================"
echo "  ALL VARIANTS COMPLETE ($GROUP): $(date -Iseconds)"
echo "================================================================"
python3 "$SUMMARIZE" \
    "$RESULTS_ROOT/mt19937-srbench/$GROUP_LOWER" \
    "$RESULTS_ROOT/mt19937-quantum/$GROUP_LOWER" \
    "$RESULTS_ROOT/pcg-quantum/$GROUP_LOWER" \
    | tee "$RESULTS_ROOT/comparison.txt"
