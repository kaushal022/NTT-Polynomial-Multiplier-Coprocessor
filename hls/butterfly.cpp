#include "butterfly.h"

static ap_uint<12> barrett_reduce(ap_uint<24> a) {
#pragma HLS INLINE
    const ap_uint<13> Q = 3329;
    const ap_uint<13> M = 5039;

    ap_uint<37> product_m = a * M;
    ap_uint<13> t = product_m >> 24;
    ap_uint<13> t_times_q = t * Q;
    ap_uint<13> r = (ap_uint<13>)a.range(12,0) - (ap_uint<13>)t_times_q.range(12,0);

    if (r >= Q)
        r -= Q;

    return (ap_uint<12>)r;
}

static ap_uint<12> mod_add(ap_uint<12> a, ap_uint<12> b) {
#pragma HLS INLINE
    ap_uint<13> sum = (ap_uint<13>)a + (ap_uint<13>)b;
    ap_uint<13> sum_q = sum - (ap_uint<13>)3329;
    return sum_q[12] ? (ap_uint<12>)sum : (ap_uint<12>)sum_q;
}

static ap_uint<12> mod_sub(ap_uint<12> a, ap_uint<12> b) {
#pragma HLS INLINE
    ap_int<13> diff = (ap_int<13>)a - (ap_int<13>)b;
    if (diff < 0)
        diff += 3329;
    return (ap_uint<12>)diff;
}

static ap_uint<12> mod_mul(ap_uint<12> a, ap_uint<12> b) {
#pragma HLS INLINE off
    ap_uint<24> product = (ap_uint<24>)a * (ap_uint<24>)b;
    return barrett_reduce(product);
}

#if VARIANT == 1

void butterfly_hls(
    ap_uint<12> a,
    ap_uint<12> b,
    ap_uint<12> w,
    ap_uint<1>  mode,
    ap_uint<12> &out_lo,
    ap_uint<12> &out_hi
) {
#pragma HLS INTERFACE ap_ctrl_hs port=return
#pragma HLS INTERFACE ap_none port=a
#pragma HLS INTERFACE ap_none port=b
#pragma HLS INTERFACE ap_none port=w
#pragma HLS INTERFACE ap_none port=mode
#pragma HLS INTERFACE ap_none port=out_lo
#pragma HLS INTERFACE ap_none port=out_hi
#pragma HLS PIPELINE II=1
#pragma HLS ALLOCATION function instances=mod_mul limit=1

    if (mode == 0) {
        ap_uint<12> t = mod_mul(b, w);
        out_lo = mod_add(a, t);
        out_hi = mod_sub(a, t);
    } else {
        ap_uint<12> sum  = mod_add(a, b);
        ap_uint<12> diff = mod_sub(b, a);
        out_lo = sum;
        out_hi = mod_mul(diff, w);
    }
}

#elif VARIANT == 2

void butterfly_hls(
    ap_uint<12> a,
    ap_uint<12> b,
    ap_uint<12> w,
    ap_uint<1>  mode,
    ap_uint<12> &out_lo,
    ap_uint<12> &out_hi
) {
#pragma HLS INTERFACE ap_ctrl_hs port=return
#pragma HLS INTERFACE ap_none port=a
#pragma HLS INTERFACE ap_none port=b
#pragma HLS INTERFACE ap_none port=w
#pragma HLS INTERFACE ap_none port=mode
#pragma HLS INTERFACE ap_none port=out_lo
#pragma HLS INTERFACE ap_none port=out_hi
#pragma HLS PIPELINE II=1
#pragma HLS ALLOCATION function instances=mod_mul limit=2

    if (mode == 0) {
        ap_uint<12> t = mod_mul(b, w);
        out_lo = mod_add(a, t);
        out_hi = mod_sub(a, t);
    } else {
        ap_uint<12> sum  = mod_add(a, b);
        ap_uint<12> diff = mod_sub(b, a);
        out_lo = sum;
        out_hi = mod_mul(diff, w);
    }
}

#else
#error "Define VARIANT=1 or VARIANT=2"
#endif
