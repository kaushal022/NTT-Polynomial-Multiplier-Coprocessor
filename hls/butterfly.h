#ifndef BUTTERFLY_H
#define BUTTERFLY_H

#include <ap_int.h>

#define MLKEM_Q      3329
#define MLKEM_N      256
#define BARRETT_M    5039

void butterfly_hls(
    ap_uint<12> a,
    ap_uint<12> b,
    ap_uint<12> w,
    ap_uint<1>  mode,
    ap_uint<12> &out_lo,
    ap_uint<12> &out_hi
);

#endif
