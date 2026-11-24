#!/usr/bin/env python3

import argparse
import json
import os
import sys
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import live_demo

try:
    import serial
except ImportError:
    serial = None

DEFAULT_DATASET = os.path.join(
    REPO_ROOT, "tb", "vectors", "random_100", "test_vectors_100.json"
)

def load_hex_chunks(hex_path, count):
    vals = []
    with open(hex_path, "r", encoding="utf-8") as fh:
        for line in fh:
            tok = line.strip()
            if tok and not tok.startswith("//"):
                vals.append(int(tok, 16) % live_demo.ref.Q)
    n_avail = len(vals) // live_demo.N_COEFF
    if n_avail == 0 or len(vals) % live_demo.N_COEFF != 0:
        raise ValueError(f"{hex_path}: line count {len(vals)} is not a multiple of {live_demo.N_COEFF}")
    limit = min(count, n_avail) if count is not None else n_avail
    return [
        vals[i * live_demo.N_COEFF : (i + 1) * live_demo.N_COEFF]
        for i in range(limit)
    ]

def load_dataset(dataset_path, start=0, count=100):
    if os.path.isdir(dataset_path):
        f_list = load_hex_chunks(os.path.join(dataset_path, "inputs_f.hex"), None)
        g_list = load_hex_chunks(os.path.join(dataset_path, "inputs_g.hex"), None)
        h_path = os.path.join(dataset_path, "expected_h.hex")
        h_list = load_hex_chunks(h_path, None) if os.path.exists(h_path) else [None] * len(f_list)
        records = [
            {"index": i, "f": f, "g": g, "h": h}
            for i, (f, g, h) in enumerate(zip(f_list, g_list, h_list))
        ]
    else:
        with open(dataset_path, "r", encoding="utf-8") as jf:
            payload = json.load(jf)
        records = payload["vectors"]

    end = len(records) if count is None else min(len(records), start + count)
    if start < 0 or start >= len(records):
        raise ValueError(f"Start index {start} out of range 0..{len(records) - 1}")
    return records[start:end], len(records)

def ensure_dataset(dataset_path, regen=False):
    if regen or not os.path.exists(dataset_path):
        ref_dir = os.path.join(REPO_ROOT, "reference")
        if ref_dir not in sys.path:
            sys.path.insert(0, ref_dir)
        import gen_100_random_vectors

        print("[Setup] Running reference/gen_100_random_vectors.py to generate dataset...")
        gen_100_random_vectors.main()
    if not os.path.exists(dataset_path):
        raise FileNotFoundError(f"Dataset not found: {dataset_path}")

def exchange_packet(ser, f_poly, g_poly):
    pkt = live_demo.pack_request(f_poly, g_poly)
    t0 = time.perf_counter()
    ser.write(pkt)
    ser.flush()

    deadline = time.monotonic() + 5.0
    rx = bytearray()
    while len(rx) < live_demo.RESP_LEN:
        if time.monotonic() > deadline:
            raise TimeoutError(f"UART timeout ({len(rx)}/{live_demo.RESP_LEN} bytes received)")
        chunk = ser.read(live_demo.RESP_LEN - len(rx))
        if chunk:
            rx.extend(chunk)
    rtt_ms = (time.perf_counter() - t0) * 1000.0

    h_hw, cycles, status = live_demo.unpack_response(rx)
    return h_hw, cycles, status, pkt, rtt_ms

def format_vec_preview(coeffs):
    return f"[{coeffs[0]:03X},{coeffs[1]:03X},{coeffs[2]:03X},..]"

def run_batch(
    port,
    baud,
    dataset_path,
    start=0,
    count=100,
    regen=False,
    verbose=False,
    coeffs=6,
    show_all=False,
    save_path=None,
):
    if serial is None:
        print("[ERROR] pyserial is not installed. Run: pip install pyserial")
        return False

    ensure_dataset(dataset_path, regen=regen)
    subset, total_avail = load_dataset(dataset_path, start=start, count=count)
    n_run = len(subset)

    port = live_demo._resolve_port(port)
    if port is None:
        return False

    rel_ds = os.path.relpath(dataset_path, REPO_ROOT)
    print("========================================================================")
    print("   ML-KEM ZYBO Z7-10 HARDWARE BATCH BENCHMARK (100-VECTOR DATASET)")
    print("========================================================================")
    print(f"Dataset file  : {rel_ds} ({n_run}/{total_avail} vectors queued)")
    print(f"Serial link   : {port} @ {baud} bps")
    print(f"Total payload : {n_run * 1026:,} B TX -> Zybo PS -> {n_run * 517:,} B RX")
    print("Batch format  : 12-bit uppercase hex [c0,c1,c2,..] matching inputs_f/g.hex & expected_h.hex")
    print("------------------------------------------------------------------------")

    passed = 0
    total_coeff_matches = 0
    cycle_samples = []
    rtt_samples = []
    saved_records = []
    last_vec = None
    first_fail = None

    batch_t0 = time.perf_counter()
    with serial.Serial(port, baud, timeout=5.0) as ser:
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(0.15)

        for pos, rec in enumerate(subset):
            vec_idx = rec["index"]
            f_poly = [c % live_demo.ref.Q for c in rec["f"]]
            g_poly = [c % live_demo.ref.Q for c in rec["g"]]
            h_ref = live_demo.ref.poly_mul(f_poly, g_poly)
            if rec.get("h") is not None and rec["h"] != h_ref:
                raise ValueError(f"Dataset vector #{vec_idx} stored 'h' disagrees with mlkem_ntt_ref.poly_mul!")

            h_hw, cycles, status, pkt, rtt_ms = exchange_packet(ser, f_poly, g_poly)
            mismatches = sum(1 for a, b in zip(h_hw, h_ref) if a != b)
            vec_ok = (mismatches == 0) and ((status & 0x3F) == 0x3F)

            if vec_ok:
                passed += 1
            elif first_fail is None:
                first_fail = (h_hw, h_ref, cycles, status)
            total_coeff_matches += (live_demo.N_COEFF - mismatches)
            cycle_samples.append(cycles)
            rtt_samples.append(rtt_ms)
            last_vec = (h_hw, h_ref, cycles, status)

            if save_path:
                saved_records.append({
                    "index": vec_idx,
                    "cycles": cycles,
                    "status": f"0x{status:02X}",
                    "rtt_ms": round(rtt_ms, 2),
                    "mismatches": mismatches,
                    "f_sha256": live_demo.poly_sha256_short(f_poly),
                    "g_sha256": live_demo.poly_sha256_short(g_poly),
                    "h_fpga_sha256": live_demo.poly_sha256_short(h_hw),
                    "h_fpga_hex": [f"{c:03X}" for c in h_hw],
                    "h_fpga": h_hw,
                })

            tag = "PASS" if vec_ok else f"FAIL({mismatches})"
            print(
                f"[{pos + 1:3d}/{n_run:3d} idx={vec_idx:02d}] "
                f"F={format_vec_preview(f_poly)} * G={format_vec_preview(g_poly)} "
                f"-> H_fpga={format_vec_preview(h_hw)} H_ref={format_vec_preview(h_ref)} | "
                f"{live_demo.N_COEFF - mismatches:3d}/256 {tag:4s} | "
                f"{cycles} cyc | {rtt_ms:5.1f} ms | 0x{status:02X}"
            )

            if verbose or pos == 0 or not vec_ok:
                live_demo.print_vector_trace(
                    vec_idx=vec_idx,
                    vec_total=total_avail,
                    source_desc=f"{rel_ds} (vector index #{vec_idx})",
                    port=port,
                    baud=baud,
                    f_poly=f_poly,
                    g_poly=g_poly,
                    pkt=pkt,
                    h_hw=h_hw,
                    h_ref=h_ref,
                    cycles=cycles,
                    status=status,
                    rtt_ms=rtt_ms,
                    head_count=coeffs,
                    show_all=show_all,
                )

    total_wall_s = time.perf_counter() - batch_t0

    if save_path:
        out_dir = os.path.dirname(os.path.abspath(save_path))
        os.makedirs(out_dir, exist_ok=True)
        with open(save_path, "w", encoding="utf-8") as sf:
            json.dump({
                "dataset": rel_ds,
                "port": port,
                "baud": baud,
                "vectors_run": n_run,
                "vectors_passed": passed,
                "total_coefficients_matched": total_coeff_matches,
                "total_coefficients": n_run * live_demo.N_COEFF,
                "wall_time_s": round(total_wall_s, 3),
                "results": saved_records,
            }, sf, indent=2)
        print(f"[Saved] Hardware results written to: {save_path}")

    avg_cyc = sum(cycle_samples) / len(cycle_samples)
    avg_rtt = sum(rtt_samples) / len(rtt_samples)

    print("------------------------------------------------------------------------")
    print(f"Batch Result      : {passed}/{n_run} vectors PASSED ({total_coeff_matches:,}/{n_run * live_demo.N_COEFF:,} coefficients OK)")
    print(f"Total Elapsed     : {total_wall_s:.2f} s  ({avg_rtt:.1f} ms/vector avg incl. UART 115200)")
    print(
        f"Hardware Cycles   : min={min(cycle_samples)}, avg={avg_cyc:.1f}, max={max(cycle_samples)} "
        f"({avg_cyc * 10.0 / 1000.0:.2f} us @ 100 MHz)"
    )
    print()

    if first_fail is not None:
        live_demo.print_demo_report(*first_fail)
        return False

    if last_vec is not None:
        h_hw_last, h_ref_last, _, st_last = last_vec
        return live_demo.print_demo_report(h_hw_last, h_ref_last, int(round(avg_cyc)), st_last)

    return False

def main():
    parser = argparse.ArgumentParser(
        description="Live Zybo Z7-10 ML-KEM FPGA Batch Demo over 100 Saved Random Vectors"
    )
    parser.add_argument("--port", default="auto", help="Serial COM port (e.g. COM7 or auto)")
    parser.add_argument("--baud", type=int, default=115200, help="UART baud rate (default 115200)")
    parser.add_argument(
        "--dataset",
        default=DEFAULT_DATASET,
        help="Path to test_vectors_100.json or directory with inputs_f.hex/inputs_g.hex",
    )
    parser.add_argument("--start", type=int, default=0, help="Starting vector index (default 0)")
    parser.add_argument("--count", type=int, default=100, help="Number of dataset vectors to test (default 100)")
    parser.add_argument(
        "--regen",
        action="store_true",
        help="Re-run reference/gen_100_random_vectors.py before executing hardware tests",
    )
    parser.add_argument("--coeffs", type=int, default=6, help="Table preview rows when showing detailed traces (default 6)")
    parser.add_argument("--show-all", action="store_true", help="Print all 256 rows in detailed coefficient tables")
    parser.add_argument("--verbose", action="store_true", help="Print full coefficient table for every vector")
    parser.add_argument("--save", default=None, help="Optional JSON output path to log all 100 hardware results")
    args = parser.parse_args()

    try:
        ok = run_batch(
            port=args.port,
            baud=args.baud,
            dataset_path=args.dataset,
            start=args.start,
            count=args.count,
            regen=args.regen,
            verbose=args.verbose,
            coeffs=args.coeffs,
            show_all=args.show_all,
            save_path=args.save,
        )
    except PermissionError as exc:
        print(f"[ERROR] {exc}")
        print("  Hint: Close any serial terminal (PuTTY, Tera Term, Vivado Serial Terminal, etc.) using this COM port.")
        sys.exit(1)
    except Exception as exc:
        print(f"[ERROR] {exc}")
        sys.exit(1)

    sys.exit(0 if ok else 2)

if __name__ == "__main__":
    main()
