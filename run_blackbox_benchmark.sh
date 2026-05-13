#!/usr/bin/env bash
set -euo pipefail

# BlackBox benchmark: 10 representative PMLB problems, 40 seeds each
# Uses upstream HP from blackbox.yaml (c=6, gp_rate=0.5, etc.)

CASES="1027_ESL,192_vineyard,210_cloud,228_elusage,344_mv,503_wind,537_houses,560_bodyfat,564_fried,659_sleuth_ex1714"
RUNS=40
SEED_SOURCE="srbench"
OUTPUT_DIR="results/blackbox_baseline"
DATASET_DIR="datasets"

echo "=== BlackBox Benchmark ==="
echo "Date      : $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Host      : $(hostname)"
echo "CPU cores : $(nproc)"
echo "Cases     : ${CASES}"
echo "Runs/case : ${RUNS}"
echo "Seed src  : ${SEED_SOURCE}"
echo ""

# --- Step 1: Download PMLB datasets ---
echo "--- Downloading PMLB datasets ---"
mkdir -p "${DATASET_DIR}"

PMLB_BASE="https://github.com/EpistasisLab/pmlb/raw/master/datasets"

for case in ${CASES//,/ }; do
    dir="${DATASET_DIR}/${case}"
    if [ -d "${dir}" ] && [ -f "${dir}/${case}.tsv.gz" ]; then
        echo "  ${case}: already downloaded"
        continue
    fi
    mkdir -p "${dir}"

    # Try .tsv.gz first, then .tsv
    url="${PMLB_BASE}/${case}/${case}.tsv.gz"
    echo -n "  ${case}: "
    if curl -fsSL -o "${dir}/${case}.tsv.gz" "${url}" 2>/dev/null; then
        # Check if it's an LFS pointer (text starting with "version https://git-lfs")
        if file "${dir}/${case}.tsv.gz" | grep -q "text"; then
            rm "${dir}/${case}.tsv.gz"
            echo -n "LFS pointer, trying raw tsv... "
            url2="${PMLB_BASE}/${case}/${case}.tsv"
            if curl -fsSL -o "${dir}/${case}.tsv" "${url2}" 2>/dev/null; then
                echo "ok (tsv)"
            else
                echo "FAILED"
            fi
        else
            echo "ok (tsv.gz)"
        fi
    else
        url2="${PMLB_BASE}/${case}/${case}.tsv"
        if curl -fsSL -o "${dir}/${case}.tsv" "${url2}" 2>/dev/null; then
            echo "ok (tsv)"
        else
            echo "FAILED"
        fi
    fi
done

echo ""

# --- Step 2: Verify datasets ---
echo "--- Verifying datasets ---"
ALL_OK=true
for case in ${CASES//,/ }; do
    found=false
    for ext in tsv.gz tsv csv.gz csv; do
        if [ -f "${DATASET_DIR}/${case}/${case}.${ext}" ]; then
            size=$(stat -c%s "${DATASET_DIR}/${case}/${case}.${ext}" 2>/dev/null || echo 0)
            echo "  ${case}: ${ext} (${size} bytes)"
            found=true
            break
        fi
    done
    if [ "${found}" = false ]; then
        echo "  ${case}: MISSING"
        ALL_OK=false
    fi
done

if [ "${ALL_OK}" = false ]; then
    echo "ERROR: Some datasets are missing. Aborting."
    exit 1
fi
echo ""

# --- Step 3: Run benchmark ---
echo "--- Running benchmark ---"
echo "Start: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

python3 -m imcts.benchmarks \
    --group BlackBox \
    --cases "${CASES}" \
    --runs "${RUNS}" \
    --seed-source "${SEED_SOURCE}" \
    --output "${OUTPUT_DIR}" \
    --dataset-dir "${DATASET_DIR}" \
    2>&1 | tee "${OUTPUT_DIR}/benchmark.log"

echo ""
echo "End: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# --- Step 4: Summary ---
echo ""
echo "--- Summary ---"
python3 summarize_results.py "${OUTPUT_DIR}" 2>/dev/null || echo "(summarize_results.py not available or failed)"
