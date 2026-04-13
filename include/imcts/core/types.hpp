// include/imcts/core/types.hpp
#pragma once
#include <cstdint>
#include <cstddef>
#include <random>
#include <vector>
#include <span>

#include "third_party/pcg/pcg_random.hpp"

namespace imcts {

using Scalar = double;
using Hash   = uint64_t;
using RandomGenerator = pcg_engines::setseq_dxsm_128_64;

struct Range {
    std::size_t start{0};
    std::size_t size{0};
};

} // namespace imcts
