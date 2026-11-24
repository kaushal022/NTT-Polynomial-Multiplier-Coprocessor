import random
import sys
import json

Q = 3329
N = 256
N_INV = 3303
MONT_R = 2**16 % Q

ZETA = 17

def _bitrev7(x):
    result = 0
    for _ in range(7):
        result = (result << 1) | (x & 1)
        x >>= 1
    return result

def _precompute_zetas():
    zetas = [0] * 128
    for i in range(128):
        zetas[i] = pow(ZETA, _bitrev7(i), Q)
    return zetas

ZETAS = _precompute_zetas()

def mod_add(a, b):
    return (a + b) % Q

def mod_sub(a, b):
    return (a - b) % Q

def mod_mul(a, b):
    return (a * b) % Q

def mod_reduce(x):
    return x % Q

def barrett_reduce(a):
    BARRETT_M = (1 << 24) // Q
    t = (a * BARRETT_M) >> 24
    r = a - t * Q
    if r >= Q:
        r -= Q
    assert 0 <= r < Q, f"Barrett reduction failed: {a} -> {r}"
    return r

def ntt_forward(f):
    assert len(f) == N
    f_hat = [x % Q for x in f]

    k = 1
    length = 128
    while length >= 2:
        for start in range(0, N, 2 * length):
            zeta = ZETAS[k]
            k += 1
            for j in range(start, start + length):
                t = mod_mul(zeta, f_hat[j + length])
                f_hat[j + length] = mod_sub(f_hat[j], t)
                f_hat[j] = mod_add(f_hat[j], t)
        length >>= 1

    return f_hat

def ntt_inverse(f_hat):
    assert len(f_hat) == N
    f = [x % Q for x in f_hat]

    k = 127
    length = 2
    while length <= 128:
        for start in range(0, N, 2 * length):
            zeta = ZETAS[k]
            k -= 1
            for j in range(start, start + length):
                t = f[j]
                f[j] = mod_add(t, f[j + length])
                f[j + length] = mod_mul(zeta, mod_sub(f[j + length], t))
        length <<= 1

    for i in range(N):
        f[i] = mod_mul(f[i], N_INV)

    return f

def basemul(a0, a1, b0, b1, gamma):
    c0 = mod_add(mod_mul(a0, b0), mod_mul(mod_mul(a1, b1), gamma))
    c1 = mod_add(mod_mul(a0, b1), mod_mul(a1, b0))
    return c0, c1

def multiply_ntts(f_hat, g_hat):
    assert len(f_hat) == N and len(g_hat) == N
    h_hat = [0] * N

    for i in range(64):
        pass

    h_hat = [0] * N
    for i in range(64):
        gamma = ZETAS[64 + i]
        c0, c1 = basemul(f_hat[4*i], f_hat[4*i+1],
                         g_hat[4*i], g_hat[4*i+1],
                         gamma)
        h_hat[4*i] = c0
        h_hat[4*i+1] = c1

        neg_gamma = mod_sub(0, gamma)
        c0, c1 = basemul(f_hat[4*i+2], f_hat[4*i+3],
                         g_hat[4*i+2], g_hat[4*i+3],
                         neg_gamma)
        h_hat[4*i+2] = c0
        h_hat[4*i+3] = c1

    return h_hat

def poly_mul(f, g):
    f_hat = ntt_forward(f)
    g_hat = ntt_forward(g)
    h_hat = multiply_ntts(f_hat, g_hat)
    h = ntt_inverse(h_hat)
    return h

def poly_mul_schoolbook(f, g):
    assert len(f) == N and len(g) == N
    h = [0] * N
    for i in range(N):
        for j in range(N):
            idx = i + j
            if idx < N:
                h[idx] = mod_add(h[idx], mod_mul(f[i], g[j]))
            else:
                h[idx - N] = mod_sub(h[idx - N], mod_mul(f[i], g[j]))
    return h

def random_poly():
    return [random.randint(0, Q - 1) for _ in range(N)]

def zero_poly():
    return [0] * N

def one_poly():
    return [1] + [0] * (N - 1)

def max_poly():
    return [Q - 1] * N

def test_modular_arithmetic():
    print("Testing modular arithmetic...")

    assert mod_add(0, 0) == 0
    assert mod_add(Q - 1, 1) == 0
    assert mod_add(Q - 1, Q - 1) == (2 * Q - 2) % Q
    assert mod_sub(0, 1) == Q - 1
    assert mod_sub(0, 0) == 0
    assert mod_mul(0, Q - 1) == 0
    assert mod_mul(1, Q - 1) == Q - 1
    assert mod_mul(Q - 1, Q - 1) == ((Q - 1) * (Q - 1)) % Q

    for a in [0, 1, Q - 1, Q, Q + 1, Q * Q - 1, Q * (Q - 1)]:
        if 0 <= a < Q * Q:
            assert barrett_reduce(a) == a % Q, f"Barrett failed for {a}"

    for _ in range(10000):
        a = random.randint(0, Q - 1)
        b = random.randint(0, Q - 1)
        assert mod_add(a, b) == (a + b) % Q
        assert mod_sub(a, b) == (a - b) % Q
        assert mod_mul(a, b) == (a * b) % Q
        assert barrett_reduce(a * b) == (a * b) % Q

    print("  PASS: All modular arithmetic tests passed.")

def test_ntt_roundtrip():
    print("Testing NTT round-trip (forward then inverse)...")

    for name, poly_fn in [("zero", zero_poly), ("one", one_poly), ("max", max_poly)]:
        f = poly_fn()
        f_hat = ntt_forward(f)
        f_rec = ntt_inverse(f_hat)
        assert f == f_rec, f"Round-trip failed for {name} polynomial"
        print(f"  PASS: {name} polynomial round-trip.")

    for i in range(100):
        f = random_poly()
        f_hat = ntt_forward(f)
        f_rec = ntt_inverse(f_hat)
        assert f == f_rec, f"Round-trip failed for random poly {i}"
    print(f"  PASS: 100 random polynomial round-trips.")

def test_ntt_linearity():
    print("Testing NTT linearity...")
    for _ in range(20):
        f = random_poly()
        g = random_poly()
        a = random.randint(0, Q - 1)
        b = random.randint(0, Q - 1)

        af_plus_bg = [mod_add(mod_mul(a, f[i]), mod_mul(b, g[i])) for i in range(N)]
        ntt_sum = ntt_forward(af_plus_bg)

        ntt_f = ntt_forward(f)
        ntt_g = ntt_forward(g)
        expected = [mod_add(mod_mul(a, ntt_f[i]), mod_mul(b, ntt_g[i])) for i in range(N)]

        assert ntt_sum == expected, "NTT linearity failed"
    print("  PASS: NTT linearity verified.")

def test_poly_mul_vs_schoolbook():
    print("Testing NTT polynomial multiply vs schoolbook...")

    f_zero = zero_poly()
    f_one = one_poly()
    f_max = max_poly()
    f_rand = random_poly()

    assert poly_mul(f_zero, f_rand) == zero_poly(), "0 * f should be 0"

    h_ntt = poly_mul(f_rand, f_one)
    assert h_ntt == f_rand, "f * 1 should be f"
    print("  PASS: Identity multiplication.")

    n_tests = 100
    for i in range(n_tests):
        f = random_poly()
        g = random_poly()
        h_ntt = poly_mul(f, g)
        h_school = poly_mul_schoolbook(f, g)
        assert h_ntt == h_school, f"Mismatch at random test {i}"
    print(f"  PASS: {n_tests} random NTT vs schoolbook comparisons.")

def test_basemul():
    print("Testing base-case multiplication...")

    for gamma_idx in range(64):
        gamma = ZETAS[64 + gamma_idx]
        c0, c1 = basemul(1, 0, 1, 0, gamma)
        assert c0 == 1 and c1 == 0, f"1*1 basemul failed for gamma_idx={gamma_idx}"

    for _ in range(100):
        a = random.randint(0, Q - 1)
        b = random.randint(0, Q - 1)
        gamma = random.randint(0, Q - 1)
        c0, c1 = basemul(a, 0, b, 0, gamma)
        assert c0 == mod_mul(a, b) and c1 == 0

    for _ in range(100):
        a = random.randint(0, Q - 1)
        b = random.randint(0, Q - 1)
        gamma = random.randint(0, Q - 1)
        c0, c1 = basemul(0, a, 0, b, gamma)
        assert c0 == mod_mul(mod_mul(a, b), gamma) and c1 == 0

    print("  PASS: Base-case multiplication tests passed.")

def generate_test_vectors(filename="test_vectors.json"):
    print(f"Generating test vectors to {filename}...")

    vectors = []
    random.seed(42)

    for i in range(10):
        f = random_poly()
        g = random_poly()
        f_hat = ntt_forward(f)
        g_hat = ntt_forward(g)
        h_hat = multiply_ntts(f_hat, g_hat)
        h = ntt_inverse(h_hat)
        h_school = poly_mul_schoolbook(f, g)

        assert h == h_school, f"Vector {i} mismatch!"

        vectors.append({
            "id": i,
            "f": f,
            "g": g,
            "f_hat": f_hat,
            "g_hat": g_hat,
            "h_hat": h_hat,
            "h": h,
        })

    output = {
        "q": Q,
        "n": N,
        "n_inv": N_INV,
        "zetas": ZETAS,
        "vectors": vectors,
    }

    with open(filename, 'w') as fp:
        json.dump(output, fp, indent=2)

    print(f"  Generated {len(vectors)} test vectors.")
    return output

def generate_verilog_rom(filename="twiddle_rom_data.vh"):
    print(f"Generating Verilog twiddle ROM data to {filename}...")
    with open(filename, 'w') as fp:
        fp.write("// ML-KEM NTT Twiddle Factors (bit-reversed order, FIPS 203)\n")
        fp.write("// zetas[i] = 17^BitRev7(i) mod 3329\n")
        fp.write(f"// q = {Q}, zeta = {ZETA}\n\n")
        for i, z in enumerate(ZETAS):
            fp.write(f"    7'd{i:>3}: twiddle = 12'd{z}; // zeta^BitRev7({i}) = {z}\n")
    print(f"  Generated {len(ZETAS)} entries.")

def generate_hex_rom(filename="twiddle_rom.hex"):
    print(f"Generating hex ROM to {filename}...")
    with open(filename, 'w') as fp:
        for z in ZETAS:
            fp.write(f"{z:03X}\n")
    print(f"  Generated {len(ZETAS)} entries.")

if __name__ == "__main__":
    print("=" * 60)
    print("ML-KEM NTT Reference Model (FIPS 203)")
    print(f"q = {Q}, n = {N}, zeta = {ZETA}, n_inv = {N_INV}")
    print("=" * 60)

    assert (128 * N_INV) % Q == 1, f"N_INV verification failed: 128 * {N_INV} mod {Q} = {(128 * N_INV) % Q}"
    print(f"Verified: 128 * {N_INV} mod {Q} = {(128 * N_INV) % Q}")

    assert pow(ZETA, 256, Q) == 1, "zeta^256 != 1"
    assert pow(ZETA, 128, Q) != 1, "zeta^128 == 1 (not primitive)"
    print(f"Verified: {ZETA}^256 mod {Q} = 1 (primitive root)")

    print(f"\nFirst 10 zetas (bit-reversed): {ZETAS[:10]}")
    print(f"Last 10 zetas: {ZETAS[-10:]}")

    print()
    test_modular_arithmetic()
    test_ntt_roundtrip()
    test_ntt_linearity()
    test_basemul()
    test_poly_mul_vs_schoolbook()

    print()
    generate_test_vectors()
    generate_verilog_rom()
    generate_hex_rom()

    print("\n" + "=" * 60)
    print("ALL TESTS PASSED")
    print("=" * 60)
