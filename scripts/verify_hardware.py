import argparse
import os
import random
import struct
import sys
import time

try:
    import serial
except ImportError:
    print("ERROR: pyserial not found. Install with: pip install pyserial")
    sys.exit(1)

_SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
_REF_DIR     = os.path.normpath(os.path.join(_SCRIPT_DIR, "..", "reference"))

if _REF_DIR not in sys.path:
    sys.path.insert(0, _REF_DIR)

try:
    from mlkem_ntt_ref import poly_mul, random_poly, Q, N
except ImportError:
    print("[INFO] reference/mlkem_ntt_ref.py not found — using built-in reference.")

    Q, N, _ZETA = 3329, 256, 17

    def _br7(k):
        return int(f"{k:07b}"[::-1], 2)

    _ZETAS = [pow(_ZETA, _br7(i), Q) for i in range(128)]

    def _ntt(f_in):
        f = [x % Q for x in f_in]
        k, length = 1, 128
        while length >= 2:
            for start in range(0, N, 2 * length):
                z = _ZETAS[k]; k += 1
                for j in range(start, start + length):
                    t = z * f[j + length] % Q
                    f[j + length] = (f[j] - t) % Q
                    f[j]          = (f[j] + t) % Q
            length >>= 1
        return f

    def _basemul(a0, a1, b0, b1, gamma):
        return (a0*b0 + a1*b1*gamma) % Q, (a0*b1 + a1*b0) % Q

    def _mul_ntts(fh, gh):
        hh = [0] * N
        for i in range(64):
            g    = _ZETAS[64 + i]
            ng   = (Q - g) % Q
            c0, c1 = _basemul(fh[4*i],   fh[4*i+1], gh[4*i],   gh[4*i+1],  g)
            hh[4*i],   hh[4*i+1]   = c0, c1
            c0, c1 = _basemul(fh[4*i+2], fh[4*i+3], gh[4*i+2], gh[4*i+3], ng)
            hh[4*i+2], hh[4*i+3]   = c0, c1
        return hh

    def _intt(fh):
        f = [x % Q for x in fh]
        k, length = 127, 2
        while length <= 128:
            for start in range(0, N, 2 * length):
                z = _ZETAS[k]; k -= 1
                for j in range(start, start + length):
                    t = f[j]
                    f[j]          = (t + f[j + length]) % Q
                    f[j + length] = z * (f[j + length] - t) % Q
            length <<= 1
        N_INV = 3303
        return [c * N_INV % Q for c in f]

    def poly_mul(f, g):
        return _intt(_mul_ntts(_ntt(f), _ntt(g)))

    def random_poly():
        return [random.randrange(Q) for _ in range(N)]

PROTO_MAGIC      = bytes([0xA5, 0x5A])
RESP_LEN         = N * 2 + 4 + 1

def _send_vector(ser: "serial.Serial", f_coeffs, g_coeffs) -> None:
    buf  = PROTO_MAGIC
    buf += struct.pack(f"<{N}H", *f_coeffs)
    buf += struct.pack(f"<{N}H", *g_coeffs)
    ser.write(buf)
    ser.flush()

def _recv_result(ser: "serial.Serial", timeout_s: float = 5.0):
    deadline = time.monotonic() + timeout_s
    buf = bytearray()
    while len(buf) < RESP_LEN:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError(
                f"Serial timeout after receiving {len(buf)}/{RESP_LEN} bytes"
            )
        ser.timeout = max(remaining, 0.05)
        chunk = ser.read(RESP_LEN - len(buf))
        if chunk:
            buf.extend(chunk)

    h_coeffs    = list(struct.unpack_from(f"<{N}H", buf, 0))
    cycle_count = struct.unpack_from("<I", buf, N * 2)[0]
    status      = buf[N * 2 + 4]
    return h_coeffs, cycle_count, status

def run_verification(port: str, baud: int, num_vectors: int, seed=None) -> bool:
    rng = random.Random(seed)

    banner = "=" * 72
    print(f"\n{banner}")
    print("  ML-KEM NTT Coprocessor — Hardware-in-the-Loop Verification")
    print(f"{banner}")
    print(f"  Port         : {port}")
    print(f"  Baud rate    : {baud}")
    print(f"  Vectors      : {num_vectors}")
    print(f"  Random seed  : {seed!r}")
    print(f"  Reference    : NIST FIPS 203 / mlkem_ntt_ref.py")
    print(f"{banner}\n")

    try:
        import serial.tools.list_ports
        available_ports = [p.device for p in serial.tools.list_ports.comports()]
    except Exception:
        available_ports = []

    try:
        ser = serial.Serial(port, baud, timeout=5)
    except serial.SerialException as e:
        print(f"\n[ERROR] Could not open port '{port}': {e}")
        if available_ports:
            print(f"[INFO] Available serial ports on this machine: {available_ports}")
            print(f"[TIP] Rerun with: python {sys.argv[0]} --port {available_ports[0]}")
        else:
            print("[INFO] No serial (COM) ports detected by Windows.")
            print("[TIP] Ensure your external USB-to-TTL adapter is plugged into your PC's USB port")
            print("      and connected to PMOD JC (Pin 1: V15=TX, Pin 2: W15=RX, GND: Pin 5/11).")
        return False

    with ser:
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(0.2)

        pass_count  = 0
        fail_count  = 0
        cycle_log   = []
        t0          = time.monotonic()

        col_hdr = (f"{'Vec':>5}  {'Result':>8}  {'Cycles':>8}  "
                   f"{'Latency(µs)':>12}  {'Max|err|':>10}")
        print(col_hdr)
        print("-" * len(col_hdr))

        for vec_idx in range(1, num_vectors + 1):
            f_coeffs = [rng.randrange(Q) for _ in range(N)]
            g_coeffs = [rng.randrange(Q) for _ in range(N)]

            ref_h = poly_mul(f_coeffs, g_coeffs)

            t_send = time.monotonic()
            _send_vector(ser, f_coeffs, g_coeffs)

            try:
                hw_h, cycles, status = _recv_result(ser, timeout_s=5.0)
            except RuntimeError as exc:
                latency_us = (time.monotonic() - t_send) * 1e6
                print(f"{vec_idx:>5}  {'TIMEOUT':>8}  {'---':>8}  "
                      f"{latency_us:>12.1f}  {exc}")
                fail_count += 1
                continue

            latency_us = (time.monotonic() - t_send) * 1e6

            if status != 0x00:
                result_str = f"ERR({status:#04x})"
                max_err_str = "N/A"
                fail_count += 1
            else:
                diffs = [abs(hw_h[i] - ref_h[i]) for i in range(N)]
                max_err = max(diffs)
                if max_err == 0:
                    result_str  = "PASS"
                    max_err_str = "0"
                    pass_count += 1
                else:
                    result_str  = "FAIL"
                    max_err_str = str(max_err)
                    fail_count += 1
                    idx_e = next(i for i, d in enumerate(diffs) if d > 0)
                    print(f"       mismatch @ coeff[{idx_e}]: "
                          f"hw={hw_h[idx_e]}  ref={ref_h[idx_e]}")

            cycle_log.append(cycles)
            print(f"{vec_idx:>5}  {result_str:>8}  {cycles:>8}  "
                  f"{latency_us:>12.1f}  {max_err_str:>10}")

    t_total = time.monotonic() - t0

    print(f"\n{banner}")
    print("  SUMMARY")
    print(f"{banner}")
    print(f"  Vectors       : {num_vectors}")
    print(f"  PASS          : {pass_count}")
    print(f"  FAIL          : {fail_count}")
    print(f"  Pass rate     : {100.0 * pass_count / num_vectors:.2f}%")
    if cycle_log:
        print(f"  Cycles (min)  : {min(cycle_log)}")
        print(f"  Cycles (max)  : {max(cycle_log)}")
        print(f"  Cycles (avg)  : {sum(cycle_log)/len(cycle_log):.1f}")
        thr = num_vectors / t_total
        print(f"  Throughput    : {thr:.2f} vectors/s")
    print(f"  Total time    : {t_total:.2f} s")
    print(f"{banner}\n")

    return fail_count == 0

def _parse_args():
    p = argparse.ArgumentParser(
        description=(
            "Hardware-in-the-Loop verification for the ML-KEM NTT Coprocessor "
            "running on the Zybo Z7-10 FPGA (PicoRV32 SoC)."
        )
    )
    p.add_argument(
        "--port", required=True,
        help="Serial port for PMOD JC USB-TTL adapter (e.g. COM3 or /dev/ttyUSB0)"
    )
    p.add_argument(
        "--baud", type=int, default=115200,
        help="UART baud rate (default: 115200)"
    )
    p.add_argument(
        "--vectors", type=int, default=100,
        help="Number of random polynomial pairs to verify (default: 100)"
    )
    p.add_argument(
        "--seed", type=int, default=None,
        help="PRNG seed for reproducible test vectors (default: system random)"
    )
    return p.parse_args()

if __name__ == "__main__":
    args    = _parse_args()
    success = run_verification(
        port=args.port,
        baud=args.baud,
        num_vectors=args.vectors,
        seed=args.seed,
    )
    sys.exit(0 if success else 1)
