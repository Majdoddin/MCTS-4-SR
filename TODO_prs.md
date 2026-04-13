# TODO: PRs to upstream

**Repo:** github.com/PKU-CMEGroup/MCTS-4-SR

## 1. Fix case-sensitive filesystem build failure

**Issue:** `pip install -e .` fails on Linux (case-sensitive fs) because CMakeLists.txt references `imcts/` but the directory is `iMCTS/`.

**Fix:** Rename `iMCTS/` → `imcts/` to match CMakeLists.txt references (lines 73-85).

**Root cause:** Developed on macOS (case-insensitive fs) where `iMCTS` == `imcts`. Breaks on Linux.

**Workaround:** `ln -s iMCTS imcts` in repo root.

## 2. Pass tolerance to nsimplify in pretty.py

**Issue:** `pretty.py:34` calls `sp.nsimplify(simplified)` with no tolerance. Default `nsimplify` only finds exact rationals, so float constants like `0.500011933` stay as-is instead of snapping to `1/2`. Tiny spurious constants like `0.000342` also stay in the output.

**Fix:** Pass `tolerance=1e-3` (or expose as a parameter) to `nsimplify()`. This will:
- Snap near-integer/rational constants to exact values (`0.99999975 → 1`, `0.500012 → 1/2`)
- Drop tiny spurious coefficients (`0.000342 → 0`)

**Impact:** Benchmark `simplified_expression` column becomes readable. Recovery rates may go up if exact-match tolerance is checked on the simplified form.

**Also:** `simplify_with_complexity()` in the benchmark runner is called without `rationalize_constants=True`. Either flip the default or pass the flag.

## 3. Editable install should pick up data file changes

**Issue:** Changing `basic.json` or `basic.yaml` (or `blackbox.*`) requires a full `pip install -e .` to take effect. These are configuration files — no reason a rebuild (which also re-runs CMake and C++ compilation) should be needed.

**Cause:** `CMakeLists.txt` (lines 73-85) uses `install(FILES ...)` to copy data files to the package directory. In editable mode, these copies are stale relative to the source tree.

**Fix:** Load data files directly from the source tree using `importlib.resources` on the source path, or use `scikit-build-core`'s `wheel.packages` / `build.editable` options to link data files instead of copying. Alternatively, move data files out of CMake entirely — have Python read them from the source directory via `__file__`.

**Impact:** Dev loop becomes usable — tweak a benchmark config and re-run, no 30s rebuild.

## 4. Replace MT19937_64 with PCG64DXSM

**Issue:** `include/imcts/core/types.hpp` uses `std::mt19937_64` as the MCTS random generator. MT19937 has known problems for Monte Carlo work with seeded runs:
- Poor single-integer seed diffusion — nearby seeds produce highly correlated internal states and near-identical early rollout trajectories.
- Large 2.5 KB state (PCG64: 16 B, xoshiro256**: 32 B).
- Fails two TestU01 BigCrush tests (linear complexity).
- NumPy replaced MT19937 with PCG64 as default in 1.17 (2019) for these reasons.

**Fix:** Use PCG64DXSM from `imneme/pcg-cpp` (header-only). Single-line swap in `types.hpp`:

```cpp
#include "third_party/pcg/pcg_random.hpp"
using RandomGenerator = pcg_engines::setseq_dxsm_128_64;
```

DXSM variant fixes the self-correlation issue NumPy patched in [numpy#18906](https://github.com/numpy/numpy/pull/18906). All `rng() % N` call sites work unchanged — PCG64's `operator()` returns `uint64_t` like MT's.

**Impact:** Marginal on Nguyen-3 success rate (50% → 60% on 10 seeds, within noise). **But the seed sensitivity on Nguyen-3 [-1,1] is not an RNG problem** — it's benchmark under-determination (multiple transcendental formulas hit reward 1.0 by exploiting narrow-range Taylor approximations). Swapping RNG just changes *which* seeds land in exploit basins. The real fix is widening the range to [-10, 10] or adopting suggestion 1 (common random numbers for siblings) from `huang2025_notes.md`.

Still worth doing for code-quality and modernization reasons.

## 5. Add R (constant token) to default Nguyen ops

**Issue:** Nguyen-12* requires the constant `0.5`, but the default ops for Nguyen exclude `R`. This makes it essentially unrecoverable (only 22% recovery in the paper), since `0.5` can't be constructed from the other ops within the depth limit.

**Fix:** Move `Nguyen` from `no_constants` to `requires_constants` in `basic.json` and `DEFAULT_CONSTANT_GROUPS` in `runner.py`. Recovery on Nguyen-12* jumps from 22% to ~100% in our tests.

**Note:** This deviates from the DSR/NGGP convention, but the convention was set before Nguyen-12* (which needs `0.5`) replaced the original Nguyen-12 (which didn't). The convention is outdated for the current benchmark.
