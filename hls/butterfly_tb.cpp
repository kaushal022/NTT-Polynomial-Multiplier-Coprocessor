#include <iostream>
#include <cassert>
#include "butterfly.h"

static ap_uint<12> ref_mod_add(ap_uint<12> a, ap_uint<12> b) {
    uint32_t sum = (uint32_t)a + (uint32_t)b;
    return (sum >= MLKEM_Q) ? (sum - MLKEM_Q) : sum;
}

static ap_uint<12> ref_mod_sub(ap_uint<12> a, ap_uint<12> b) {
    int32_t diff = (int32_t)a - (int32_t)b;
    if (diff < 0) diff += MLKEM_Q;
    return diff;
}

static ap_uint<12> ref_mod_mul(ap_uint<12> a, ap_uint<12> b) {
    uint64_t prod = (uint64_t)a * (uint64_t)b;
    return (prod % MLKEM_Q);
}

int main(void) {
    std::cout << "=== HLS Butterfly C++ Testbench ===" << std::endl;
    int errors = 0;

    for (int a = 0; a < 3329; a += 331) {
        for (int b = 0; b < 3329; b += 419) {
            for (int w = 1; w < 3329; w += 523) {
                ap_uint<12> out_lo, out_hi;
                butterfly_hls(a, b, w, 0, out_lo, out_hi);

                ap_uint<12> t = ref_mod_mul(b, w);
                ap_uint<12> exp_lo = ref_mod_add(a, t);
                ap_uint<12> exp_hi = ref_mod_sub(a, t);

                if (out_lo != exp_lo || out_hi != exp_hi) {
                    std::cerr << "FWD FAIL: a=" << a << " b=" << b << " w=" << w
                              << " got(" << out_lo << "," << out_hi << ")"
                              << " exp(" << exp_lo << "," << exp_hi << ")" << std::endl;
                    errors++;
                }
            }
        }
    }

    for (int a = 0; a < 3329; a += 331) {
        for (int b = 0; b < 3329; b += 419) {
            for (int w = 1; w < 3329; w += 523) {
                ap_uint<12> out_lo, out_hi;
                butterfly_hls(a, b, w, 1, out_lo, out_hi);

                ap_uint<12> exp_lo = ref_mod_add(a, b);
                ap_uint<12> diff = ref_mod_sub(b, a);
                ap_uint<12> exp_hi = ref_mod_mul(diff, w);

                if (out_lo != exp_lo || out_hi != exp_hi) {
                    std::cerr << "INV FAIL: a=" << a << " b=" << b << " w=" << w
                              << " got(" << out_lo << "," << out_hi << ")"
                              << " exp(" << exp_lo << "," << exp_hi << ")" << std::endl;
                    errors++;
                }
            }
        }
    }

    if (errors == 0) {
        std::cout << "SUCCESS: All HLS butterfly test cases passed!" << std::endl;
        return 0;
    } else {
        std::cerr << "FAILED: " << errors << " test cases failed!" << std::endl;
        return 1;
    }
}
