import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from mlkem_ntt_ref import *

def write_hex(filename, coeffs):
    with open(filename, 'w') as f:
        for c in coeffs:
            f.write(f"{c:03X}\n")

if __name__ == "__main__":
    outdir = os.path.join(os.path.dirname(__file__), "..", "tb", "vectors")
    os.makedirs(outdir, exist_ok=True)

    f1 = list(range(256))
    f1_hat = ntt_forward(f1)
    f1_back = ntt_inverse(f1_hat)
    assert f1_back == f1, "Round-trip failed!"

    write_hex(os.path.join(outdir, "tv1_input.hex"), f1)
    write_hex(os.path.join(outdir, "tv1_ntt.hex"), f1_hat)

    f2 = [1] * 256
    f2_hat = ntt_forward(f2)
    write_hex(os.path.join(outdir, "tv2_input.hex"), f2)
    write_hex(os.path.join(outdir, "tv2_ntt.hex"), f2_hat)

    f3 = [1] + [0]*255
    f3_hat = ntt_forward(f3)
    write_hex(os.path.join(outdir, "tv3_input.hex"), f3)
    write_hex(os.path.join(outdir, "tv3_ntt.hex"), f3_hat)

    random.seed(12)
    f4 = random_poly()
    f4_hat = ntt_forward(f4)
    write_hex(os.path.join(outdir, "tv4_input.hex"), f4)
    write_hex(os.path.join(outdir, "tv4_ntt.hex"), f4_hat)

    f5 = random_poly()
    h_ntt = poly_mul(f4, f5)
    h_school = poly_mul_schoolbook(f4, f5)
    assert h_ntt == h_school, "Poly mul mismatch!"

    write_hex(os.path.join(outdir, "tv5_input.hex"), f5)
    write_hex(os.path.join(outdir, "tv_polymul_result.hex"), h_ntt)

    print(f"Generated test vectors in {outdir}")
    print(f"TV1 NTT[0:8]: {f1_hat[:8]}")
    print(f"TV3 NTT[0:4]: {f3_hat[:4]} (unit impulse should have specific pattern)")
    print(f"TV4 random input[0:4]: {f4[:4]}")
    print(f"TV5 random input[0:4]: {f5[:4]}")
    print(f"tv_polymul_result random input[0:4] result: {h_ntt[:4]}")
