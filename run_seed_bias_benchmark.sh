#!/usr/bin/env bash
set -euo pipefail

RESULTS_ROOT="results_seed_bias"
LOG_DIR="$RESULTS_ROOT/logs"
mkdir -p "$LOG_DIR"

# ── System info ──
{
    echo "=== System Info ==="
    echo "Date:     $(date -Iseconds)"
    echo "Host:     $(hostname)"
    echo "CPU:      $(lscpu | grep 'Model name' | sed 's/.*: *//')"
    echo "Cores:    $(nproc)"
    echo "RAM:      $(free -h | awk '/Mem:/{print $2}')"
    echo "OS:       $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY | cut -d= -f2)"
    echo ""
    echo "=== Git Info ==="
    echo "Branch:   $(git branch --show-current)"
    echo "Commits:"
    git log --oneline -5
    echo ""
} | tee "$RESULTS_ROOT/system_info.txt"

# ── Helper ──
run_variant() {
    local name="$1"
    local commit="$2"
    local seed_source="$3"
    local output_dir="$RESULTS_ROOT/$name/nguyen"
    local log_file="$LOG_DIR/${name}.log"

    echo ""
    echo "================================================================"
    echo "  VARIANT: $name"
    echo "  Commit:  $commit"
    echo "  Seeds:   $seed_source"
    echo "  Output:  $output_dir"
    echo "  Started: $(date -Iseconds)"
    echo "================================================================"

    # Checkout and rebuild if needed
    git checkout "$commit"
    echo "Building at $(git log --oneline -1)..."
    pip install -e . --no-build-isolation -q 2>&1 | tail -3

    echo "Build done. Starting benchmark..."
    echo ""

    # Run benchmark — results are saved incrementally per-case CSV
    python -m imcts.benchmarks \
        --group Nguyen \
        --cases all \
        --runs 100 \
        --seed-source "$seed_source" \
        --output "$output_dir" \
        --workers "$(nproc)" \
        2>&1 | tee "$log_file"

    echo ""
    echo "  Variant $name finished: $(date -Iseconds)"
    echo "  Results in: $output_dir"
    echo ""

    # Generate summary
    python3 summarize_results.py "$output_dir" | tee "$RESULTS_ROOT/${name}_summary.txt"
}

# ── Run all 3 variants ──

echo "Starting 3-variant seed bias benchmark at $(date -Iseconds)"
echo ""

# Variant 1: MT19937 + SRBench seeds (upstream baseline)
run_variant "mt19937-srbench" "48d10f2" "srbench"

# Variant 2: MT19937 + quantum seeds
run_variant "mt19937-quantum" "48d10f2" "quantum"

# Variant 3: PCG + quantum seeds
run_variant "pcg-quantum" "5f2b5c3" "quantum"

# ── Final comparison ──
echo ""
echo "================================================================"
echo "  ALL VARIANTS COMPLETE: $(date -Iseconds)"
echo "================================================================"
python3 summarize_results.py "$RESULTS_ROOT/mt19937-srbench/nguyen" "$RESULTS_ROOT/mt19937-quantum/nguyen" "$RESULTS_ROOT/pcg-quantum/nguyen" \
    | tee "$RESULTS_ROOT/comparison.txt"

echo ""
echo "Results saved in: $RESULTS_ROOT/"
echo "To copy results: scp -r root@\$(hostname -I | awk '{print \$1}'):$(pwd)/$RESULTS_ROOT ."
