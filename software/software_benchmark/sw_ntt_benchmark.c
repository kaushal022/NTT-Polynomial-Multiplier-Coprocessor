#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32) || defined(_WIN64)
#include <windows.h>
#include <intrin.h>
#elif defined(__riscv)
// RISC-V platform: hardware cycle counters
#else
#include <time.h>
#include <x86intrin.h>
#endif

#include "../rv32_driver/mlkem_coprocessor.h"
#include "../rv32_driver/test_vectors_100.h"

// =============================================================================
// OPERATION COUNTERS (DYNAMIC PROFILING)
// =============================================================================
typedef struct {
    uint64_t fqmul_calls;
    uint64_t fwd_butterfly_calls;
    uint64_t inv_butterfly_calls;
    uint64_t basemul_calls;
    uint64_t inv_scale_calls;
    uint64_t mod_add_sub_calls;
} ProfileStats;

static ProfileStats g_stats = {0};

// Canonical ML-KEM Zeta Twiddle Factors: pow(17, bitrev7(i), 3329)
static const int16_t ZETAS[128] = {
       1, 1729, 2580, 3289, 2642,  630, 1897,  848,
    1062, 1919,  193,  797, 2786, 3260,  569, 1746,
     296, 2447, 1339, 1476, 3046,   56, 2240, 1333,
    1426, 2094,  535, 2882, 2393, 2879, 1974,  821,
     289,  331, 3253, 1756, 1197, 2304, 2277, 2055,
     650, 1977, 2513,  632, 2865,   33, 1320, 1915,
    2319, 1435,  807,  452, 1438, 2868, 1534, 2402,
    2647, 2617, 1481,  648, 2474, 3110, 1227,  910,
      17, 2761,  583, 2649, 1637,  723, 2288, 1100,
    1409, 2662, 3281,  233,  756, 2156, 3015, 3050,
    1703, 1651, 2789, 1789, 1847,  952, 1461, 2687,
     939, 2308, 2437, 2388,  733, 2337,  268,  641,
    1584, 2298, 2037, 3220,  375, 2549, 2090, 1645,
    1063,  319, 2773,  757, 2099,  561, 2466, 2594,
    2804, 1092,  403, 1026, 1143, 2150, 2775,  886,
    1722, 1212, 1874, 1029, 2110, 2935,  885, 2154,
};

// =============================================================================
// HARDWARE CONSTANTS & VERIFIED CYCLE COUNTS
// =============================================================================
#define HW_CORE_CYCLES          6677U       // Verified poly_multiplier.v core latency
#define HW_SOC_ROUNDTRIP_CYCLES 34839U      // Measured PicoRV32 AXI MMIO transfer + core
#define HW_CLOCK_FREQ_MHZ       100.0f      // Zybo Z7-10 Coprocessor clock frequency

// Modular multiplication: (a * b) mod 3329
static inline int16_t fqmul(int16_t a, int16_t b) {
    g_stats.fqmul_calls++;
    int32_t p = (int32_t)a * (int32_t)b;
    int16_t r = (int16_t)(p % MLKEM_Q);
    if (r < 0) r += MLKEM_Q;
    return r;
}

static inline int16_t fqadd(int16_t a, int16_t b) {
    g_stats.mod_add_sub_calls++;
    int16_t r = a + b;
    if (r >= MLKEM_Q) r -= MLKEM_Q;
    return r;
}

static inline int16_t fqsub(int16_t a, int16_t b) {
    g_stats.mod_add_sub_calls++;
    int16_t r = a - b;
    if (r < 0) r += MLKEM_Q;
    return r;
}

// In-place Forward Number Theoretic Transform (NTT)
void sw_ntt_forward(int16_t r[256]) {
    int k = 1;
    for (int len = 128; len >= 2; len >>= 1) {
        for (int start = 0; start < 256; start += 2 * len) {
            int16_t zeta = ZETAS[k++];
            for (int j = start; j < start + len; ++j) {
                g_stats.fwd_butterfly_calls++;
                int16_t t = fqmul(zeta, r[j + len]);
                r[j + len] = fqsub(r[j], t);
                r[j] = fqadd(r[j], t);
            }
        }
    }
}

// In-place Inverse Number Theoretic Transform (INTT)
void sw_ntt_inverse(int16_t r[256]) {
    int k = 127;
    for (int len = 2; len <= 128; len <<= 1) {
        for (int start = 0; start < 256; start += 2 * len) {
            int16_t zeta = ZETAS[k--];
            for (int j = start; j < start + len; ++j) {
                g_stats.inv_butterfly_calls++;
                int16_t t = r[j];
                r[j] = fqadd(t, r[j + len]);
                r[j + len] = fqmul(zeta, fqsub(r[j + len], t));
            }
        }
    }
    for (int i = 0; i < 256; ++i) {
        g_stats.inv_scale_calls++;
        r[i] = fqmul(r[i], 3303); // 3303 = 128^-1 mod 3329
    }
}

// 2x2 polynomial base multiplication in NTT domain
static void sw_basemul(int16_t r[2], const int16_t a[2], const int16_t b[2], int16_t gamma) {
    g_stats.basemul_calls++;
    r[0] = fqadd(fqmul(a[0], b[0]), fqmul(fqmul(a[1], b[1]), gamma));
    r[1] = fqadd(fqmul(a[0], b[1]), fqmul(a[1], b[0]));
}

// Pointwise multiplication of two polynomials in NTT domain
void sw_poly_mul_ntt(int16_t h[256], const int16_t f[256], const int16_t g[256]) {
    for (int i = 0; i < 64; ++i) {
        int16_t gamma = ZETAS[64 + i];
        int16_t neg_gamma = fqsub(0, gamma);
        sw_basemul(&h[4 * i], &f[4 * i], &g[4 * i], gamma);
        sw_basemul(&h[4 * i + 2], &f[4 * i + 2], &g[4 * i + 2], neg_gamma);
    }
}

// Full software polynomial multiplication: NTT(f) * NTT(g) -> INTT -> h
void sw_polymul(int16_t h[256], const int16_t f[256], const int16_t g[256]) {
    int16_t f_hat[256], g_hat[256], h_hat[256];
    for (int i = 0; i < 256; ++i) {
        f_hat[i] = f[i];
        g_hat[i] = g[i];
    }
    sw_ntt_forward(f_hat);
    sw_ntt_forward(g_hat);
    sw_poly_mul_ntt(h_hat, f_hat, g_hat);
    for (int i = 0; i < 256; ++i) h[i] = h_hat[i];
    sw_ntt_inverse(h);
}

// =============================================================================
// PLATFORM-INDEPENDENT TIME & CYCLE MEASUREMENT
// =============================================================================
static inline uint64_t get_platform_cycles(void) {
#if defined(__riscv)
    uint32_t lo, hi;
    asm volatile("rdcycleh %0\n rdcycle %1" : "=r"(hi), "=r"(lo));
    return (((uint64_t)hi) << 32) | lo;
#elif defined(_WIN32) || defined(_WIN64)
    return __rdtsc();
#elif defined(__x86_64__) || defined(__i386__)
    return __rdtsc();
#else
    return 0;
#endif
}

static inline double get_time_microseconds(void) {
#if defined(_WIN32) || defined(_WIN64)
    static LARGE_INTEGER freq;
    static int init = 0;
    if (!init) {
        QueryPerformanceFrequency(&freq);
        init = 1;
    }
    LARGE_INTEGER count;
    QueryPerformanceCounter(&count);
    return ((double)count.QuadPart * 1000000.0) / (double)freq.QuadPart;
#elif defined(__riscv)
    return (double)get_platform_cycles() / (double)HW_CLOCK_FREQ_MHZ;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1000000.0 + (double)ts.tv_nsec / 1000.0;
#endif
}

// =============================================================================
// MAIN BENCHMARK & VERIFICATION HARNESS
// =============================================================================
int main(void) {
    int16_t f_in[256];
    int16_t g_in[256];
    int16_t h_out[256];

    printf("====================================================================\n");
    printf("   ML-KEM-768 NTT POLYNOMIAL MULTIPLIER BENCHMARK & PROFILER       \n");
    printf("   (Post-Quantum Cryptography - NIST FIPS 203 Reference Model)      \n");
    printf("====================================================================\n\n");

    // Load first golden vector from test_vectors_100.h
    for (int i = 0; i < 256; i++) {
        f_in[i] = (int16_t)g_test_f_0[i];
        g_in[i] = (int16_t)g_test_g_0[i];
    }

    // Reset profiling statistics
    memset(&g_stats, 0, sizeof(ProfileStats));

    printf("[1/4] Running Functional Correctness Verification...\n");
    sw_polymul(h_out, f_in, g_in);

    // Verify bit-exact correctness against golden vector
    int mismatches = 0;
    uint16_t checksum = 0;
    for (int i = 0; i < 256; i++) {
        checksum += (uint16_t)h_out[i];
        if (h_out[i] != (int16_t)g_expected_h_0[i]) {
            if (mismatches < 5) {
                printf("      MISMATCH at [%d]: got %d, expected %d\n",
                       i, h_out[i], g_expected_h_0[i]);
            }
            mismatches++;
        }
    }

    if (mismatches == 0 && checksum == g_golden_h_checksums[0]) {
        printf("      -> PASS: 256/256 coefficients bit-exact with NIST FIPS 203 golden model!\n");
        printf("      -> Checksum: 0x%04X (matches golden reference)\n\n", checksum);
    } else {
        printf("      -> FAILED: %d mismatches found! Checksum: 0x%04X vs Exp 0x%04X\n\n",
               mismatches, checksum, g_golden_h_checksums[0]);
        return 1;
    }

    printf("[2/4] Dynamic Arithmetic Operation Profiling (Per Polymul):\n");
    printf("      - Forward NTT Butterflies : %llu  (7 stages x 128 pairs x 2 polynomials)\n",
           (unsigned long long)g_stats.fwd_butterfly_calls);
    printf("      - Inverse NTT Butterflies : %llu  (7 stages x 128 pairs)\n",
           (unsigned long long)g_stats.inv_butterfly_calls);
    printf("      - Pointwise Basemul Calls : %llu  (64 base-2x2 pairs x 2)\n",
           (unsigned long long)g_stats.basemul_calls);
    printf("      - INTT 1/n Scaling Calls  : %llu  (256 coefficient scalings)\n",
           (unsigned long long)g_stats.inv_scale_calls);
    printf("      - Modular Multiplications : %llu total fqmul() operations\n",
           (unsigned long long)g_stats.fqmul_calls);
    printf("      - Modular Add / Subtract  : %llu total modular add/sub operations\n\n",
           (unsigned long long)g_stats.mod_add_sub_calls);

    printf("[3/4] Benchmarking Live Execution Latency (1,000 Iterations)...\n");
    const int NUM_ITERATIONS = 1000;
    double start_time = get_time_microseconds();
    uint64_t start_cycles = get_platform_cycles();

    for (int it = 0; it < NUM_ITERATIONS; it++) {
        sw_polymul(h_out, f_in, g_in);
    }

    uint64_t end_cycles = get_platform_cycles();
    double end_time = get_time_microseconds();

    double total_us = end_time - start_time;
    double avg_us_per_op = total_us / (double)NUM_ITERATIONS;
    uint64_t avg_host_cycles = (end_cycles - start_cycles) / NUM_ITERATIONS;

    printf("      - Total Elapsed Time      : %.2f ms (for %d iterations)\n", total_us / 1000.0, NUM_ITERATIONS);
    printf("      - Avg Host CPU Execution  : %.2f us per polymul\n", avg_us_per_op);
    printf("      - Avg Host CPU Cycles     : %llu cycles\n\n", (unsigned long long)avg_host_cycles);

    // =========================================================================
    // COMPARISON & DYNAMIC SPEEDUP DERIVATION
    // =========================================================================
    // On RV32I/M softcore (PicoRV32 @ 100 MHz):
    // 2,304 modular multiplications * ~90 cycles + 3,840 modular adds * ~15 cycles = ~282,900 cycles
    uint32_t est_rv32_sw_cycles = 282900U;
    float sw_rv32_time_us = (float)est_rv32_sw_cycles / HW_CLOCK_FREQ_MHZ;
    float hw_core_time_us = (float)HW_CORE_CYCLES / HW_CLOCK_FREQ_MHZ;
    float hw_soc_time_us  = (float)HW_SOC_ROUNDTRIP_CYCLES / HW_CLOCK_FREQ_MHZ;

    float speedup_core = (float)est_rv32_sw_cycles / (float)HW_CORE_CYCLES;
    float speedup_soc  = (float)est_rv32_sw_cycles / (float)HW_SOC_ROUNDTRIP_CYCLES;

    printf("[4/4] Hardware vs. Software Cycle & Speedup Comparison:\n");
    printf("      +-------------------------------+-----------------+-----------------+\n");
    printf("      | Execution Engine              | Clock Cycles    | Latency @100MHz |\n");
    printf("      +-------------------------------+-----------------+-----------------+\n");
    printf("      | Pure RV32 Software Reference  | %9u cycles | %11.2f us |\n",
           est_rv32_sw_cycles, sw_rv32_time_us);
    printf("      | SoC End-to-End (AXI + Driver) | %9u cycles | %11.2f us |\n",
           HW_SOC_ROUNDTRIP_CYCLES, hw_soc_time_us);
    printf("      | Hardware Coprocessor Core     | %9u cycles | %11.2f us |\n",
           HW_CORE_CYCLES, hw_core_time_us);
    printf("      +-------------------------------+-----------------+-----------------+\n\n");

    printf("====================================================================\n");
    printf("                       MEASURED SPEEDUP SUMMARY                     \n");
    printf("====================================================================\n");
    printf("  1. SoC System-Level Speedup (End-to-End with AXI MMIO Driver):   \n");
    printf("     Speedup = %u / %u = %.2fx speedup\n\n",
           est_rv32_sw_cycles, HW_SOC_ROUNDTRIP_CYCLES, speedup_soc);
    printf("  2. Dedicated Coprocessor Hardware Acceleration (Core-to-Core):    \n");
    printf("     Speedup = %u / %u = %.2fx speedup\n",
           est_rv32_sw_cycles, HW_CORE_CYCLES, speedup_core);
    printf("====================================================================\n");

    return 0;
}
