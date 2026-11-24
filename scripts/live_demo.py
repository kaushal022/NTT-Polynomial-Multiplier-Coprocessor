#!/usr/bin/env python3

import argparse
import hashlib
import os
import random
import secrets
import struct
import sys
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
REF_DIR = os.path.join(REPO_ROOT, "reference")
if REF_DIR not in sys.path:
    sys.path.insert(0, REF_DIR)

import mlkem_ntt_ref as ref

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    serial = None

PROTO_MAGIC = bytes([0xA5, 0x5A])
N_COEFF = 256
RESP_LEN = N_COEFF * 2 + 4 + 1

FLAG_RESP_READY  = 1 << 0
FLAG_RV_RUNNING  = 1 << 1
FLAG_DMA_DONE    = 1 << 2
FLAG_COPROC_DONE = 1 << 3
FLAG_IRQ_RECV    = 1 << 4
FLAG_UART_OK     = 1 << 5

def detect_zybo_port():
    if serial is None:
        return None
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        return None
    for p in ports:
        desc = f"{p.description} {p.manufacturer or ''}".lower()
        if any(k in desc for k in ("digilent", "ftdi", "usb serial", "uart", "cp210")):
            return p.device
    return ports[0].device

def pack_request(f_coeffs, g_coeffs):
    assert len(f_coeffs) == N_COEFF and len(g_coeffs) == N_COEFF
    return (
        PROTO_MAGIC
        + struct.pack(f"<{N_COEFF}H", *(c % ref.Q for c in f_coeffs))
        + struct.pack(f"<{N_COEFF}H", *(c % ref.Q for c in g_coeffs))
    )

def unpack_response(buf):
    if len(buf) != RESP_LEN:
        raise ValueError(f"Expected {RESP_LEN} bytes, got {len(buf)}")
    h_coeffs = list(struct.unpack_from(f"<{N_COEFF}H", buf, 0))
    cycles = struct.unpack_from("<I", buf, N_COEFF * 2)[0]
    status = buf[N_COEFF * 2 + 4]
    return h_coeffs, cycles, status

def print_demo_report(h_hw, h_ref, cycles, status):
    mismatches = sum(1 for a, b in zip(h_hw, h_ref) if a != b)

    uart_str   = "PASS"     if (status & FLAG_UART_OK)     else "FAIL"
    rv32_str   = "RUNNING"  if (status & FLAG_RV_RUNNING)  else "HALTED"
    dma_str    = "COMPLETE" if (status & FLAG_DMA_DONE)    else "INCOMPLETE"
    coproc_str = "DONE"     if (status & FLAG_COPROC_DONE) else "PENDING"
    irq_str    = "RECEIVED" if (status & FLAG_IRQ_RECV)    else "MISSED"
    poly_str   = "PASS"     if (mismatches == 0 and (status & FLAG_RESP_READY)) else f"FAIL ({mismatches} err)"

    print("==================================")
    print("       ML-KEM FPGA DEMONSTRATION")
    print("==================================")
    print()
    print(f"UART Communication       : {uart_str}")
    print(f"PicoRV32 CPU             : {rv32_str}")
    print(f"DMA Transfer             : {dma_str}")
    print(f"Coprocessor              : {coproc_str}")
    print(f"Interrupt                : {irq_str}")
    print()
    print(f"Polynomial Verification  : {poly_str}")
    print(f"Output Coefficients      : {len(h_hw)}")
    print(f"Hardware Cycle Count     : {cycles}")
    print()
    print("==================================")

    return mismatches == 0 and (status & 0x3F) == 0x3F

def load_hex_poly(path):
    vals = []
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            tok = line.strip()
            if tok and not tok.startswith("//"):
                vals.append(int(tok, 16) % ref.Q)
    if len(vals) != N_COEFF:
        raise ValueError(f"{path}: expected {N_COEFF} values, got {len(vals)}")
    return vals

def parse_poly_spec(spec):
    text = spec.strip()
    if not text:
        raise ValueError("Empty polynomial specification")

    entries = []
    if ":" in text:
        for item in text.split(","):
            tok = item.strip()
            if not tok:
                continue
            if ":" not in tok:
                raise ValueError(f"Expected 'idx:val' pair, got {tok!r}")
            idx_s, val_s = tok.split(":", 1)
            idx = int(idx_s.strip(), 0)
            if not 0 <= idx < N_COEFF:
                raise ValueError(f"Coefficient index {idx} out of range 0..{N_COEFF - 1}")
            entries.append((idx, int(val_s.strip(), 0)))
    else:
        tokens = [t for t in text.replace(",", " ").split() if t]
        if len(tokens) > N_COEFF:
            raise ValueError(f"Expected at most {N_COEFF} coefficients, got {len(tokens)}")
        entries = [(i, int(tok, 0)) for i, tok in enumerate(tokens)]

    coeffs = [0] * N_COEFF
    reduced = []
    for idx, raw_val in entries:
        mod_val = raw_val % ref.Q
        if raw_val != mod_val:
            reduced.append(f"[{idx}]={raw_val}->{mod_val}")
        coeffs[idx] = mod_val
    if reduced:
        shown = ", ".join(reduced[:4]) + (" ..." if len(reduced) > 4 else "")
        print(f"[Note] Reduced out-of-range input(s) mod q={ref.Q}: {shown}")
    return coeffs

def poly_sha256_short(coeffs):
    raw = struct.pack(f"<{N_COEFF}H", *(c % ref.Q for c in coeffs))
    return hashlib.sha256(raw).hexdigest()[:12]

def format_poly_expr(coeffs, max_terms=4):
    terms = []
    for deg, c in enumerate(coeffs):
        if c == 0:
            continue
        if deg == 0:
            terms.append(str(c))
        elif deg == 1:
            terms.append(f"{c}*x")
        else:
            terms.append(f"{c}*x^{deg}")
        if len(terms) >= max_terms:
            break
    if not terms:
        return "0"
    nz = sum(1 for c in coeffs if c != 0)
    suffix = f" + ... ({nz} nonzero terms)" if nz > max_terms else ""
    return " + ".join(terms) + suffix

def decode_status_flags(status):
    names = []
    if status & FLAG_UART_OK:
        names.append("UART_OK")
    if status & FLAG_RV_RUNNING:
        names.append("RV32_RUN")
    if status & FLAG_DMA_DONE:
        names.append("DMA_DONE")
    if status & FLAG_COPROC_DONE:
        names.append("COPROC_DONE")
    if status & FLAG_IRQ_RECV:
        names.append("IRQ_RECV")
    if status & FLAG_RESP_READY:
        names.append("RESP_READY")
    return "|".join(names) if names else "NONE"

def select_display_indices(head_count, mismatch_indices, show_all):
    if show_all or head_count <= 0:
        return list(range(N_COEFF))
    chosen = set(range(min(head_count, N_COEFF)))
    tail_start = max(0, N_COEFF - 4)
    chosen.update(range(tail_start, N_COEFF))
    for idx in mismatch_indices[:16]:
        chosen.add(idx)
    return sorted(chosen)

def print_vector_trace(
    vec_idx,
    vec_total,
    source_desc,
    port,
    baud,
    f_poly,
    g_poly,
    pkt,
    h_hw,
    h_ref,
    cycles,
    status,
    rtt_ms,
    head_count,
    show_all,
):
    mismatches = [i for i, (a, b) in enumerate(zip(h_hw, h_ref)) if a != b]
    f_nz = sum(1 for c in f_poly if c)
    g_nz = sum(1 for c in g_poly if c)
    h_nz = sum(1 for c in h_hw if c)

    label = f"Vector {vec_idx + 1}/{vec_total}" if vec_total else f"Interactive Vector #{vec_idx + 1}"
    print()
    print(f"------------------------------------------------------------------------")
    print(f"[{label}] {source_desc}")
    print(f"------------------------------------------------------------------------")
    print(f"F(x) [Z_3329] : nz={f_nz:3d}/256  range=[{min(f_poly):4d}..{max(f_poly):4d}]  sha256={poly_sha256_short(f_poly)}")
    print(f"                {format_poly_expr(f_poly)}")
    print(f"G(x) [Z_3329] : nz={g_nz:3d}/256  range=[{min(g_poly):4d}..{max(g_poly):4d}]  sha256={poly_sha256_short(g_poly)}")
    print(f"                {format_poly_expr(g_poly)}")
    print(
        f"TX -> {port:<6s}  : {len(pkt):,} bytes @ {baud} bps "
        f"[magic={pkt[0]:02X} {pkt[1]:02X} | F=512B LE | G=512B LE]"
    )
    print(
        f"RX <- Zybo PS : {RESP_LEN} bytes in {rtt_ms:.1f} ms | "
        f"FPGA={cycles} cycles ({cycles * 10.0 / 1000.0:.2f} us @ 100 MHz)"
    )
    print(f"Status Flags  : 0x{status:02X} [{decode_status_flags(status)}]")
    print()
    print("  idx |    F[i] (hex)   |    G[i] (hex)   |  H_fpga[i] (hex) |   H_ref[i] (hex) | Check")
    print("------+-----------------+-----------------+------------------+------------------+------")

    indices = select_display_indices(head_count, mismatches, show_all)
    prev_i = None
    for i in indices:
        if prev_i is not None and i > prev_i + 1:
            skipped = i - prev_i - 1
            print(f"  ... | ({skipped} coefficients omitted; use --show-all to print all 256)          |")
        ok_tag = "OK" if h_hw[i] == h_ref[i] else "DIFF!"
        print(
            f" {i:4d} | {f_poly[i]:4d} (0x{f_poly[i]:03X})    | {g_poly[i]:4d} (0x{g_poly[i]:03X})    | "
            f"{h_hw[i]:4d} (0x{h_hw[i]:03X})     | {h_ref[i]:4d} (0x{h_ref[i]:03X})     | {ok_tag}"
        )
        prev_i = i

    max_diff = max((abs(a - b) for a, b in zip(h_hw, h_ref)), default=0)
    print()
    print(f"H_fpga digest : sha256={poly_sha256_short(h_hw)}  nz={h_nz}/256  range=[{min(h_hw)}..{max(h_hw)}]")
    print(f"H_ref  digest : sha256={poly_sha256_short(h_ref)}  matched={N_COEFF - len(mismatches)}/{N_COEFF}  max|diff|={max_diff}")
    print()

def _resolve_port(port):
    if port.lower() == "comx":
        port = "auto"

    if port == "auto":
        port = detect_zybo_port()
        if port is None:
            print("[ERROR] No serial COM port detected by Windows / pyserial.")
            print("  If Zybo Z7-10 is plugged in via USB PROG/UART:")
            print("    1. Open Device Manager -> Universal Serial Bus controllers")
            print("    2. Right-click 'USB Serial Converter B' -> Properties -> Advanced")
            print("    3. Check 'Load VCP' (leave Converter A unchecked for JTAG) -> OK")
            print("    4. Unplug & replug the Zybo USB cable, then run:")
            print("         xsdb scripts/launch_zybo_demo.tcl")
            print("         python scripts/live_demo.py --port auto")
            return None
    return port

def _exchange_and_verify(
    ser,
    port,
    baud,
    vec_idx,
    vec_total,
    source_desc,
    f_poly,
    g_poly,
    head_count,
    show_all,
):
    h_ref = ref.poly_mul(f_poly, g_poly)
    pkt = pack_request(f_poly, g_poly)

    t0 = time.perf_counter()
    ser.write(pkt)
    ser.flush()

    deadline = time.monotonic() + 5.0
    rx = bytearray()
    while len(rx) < RESP_LEN:
        if time.monotonic() > deadline:
            raise TimeoutError(f"UART timeout ({len(rx)}/{RESP_LEN} bytes received)")
        chunk = ser.read(RESP_LEN - len(rx))
        if chunk:
            rx.extend(chunk)
    rtt_ms = (time.perf_counter() - t0) * 1000.0

    h_hw, cycles, status = unpack_response(rx)
    print_vector_trace(
        vec_idx=vec_idx,
        vec_total=vec_total,
        source_desc=source_desc,
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
        head_count=head_count,
        show_all=show_all,
    )
    ok = print_demo_report(h_hw, h_ref, cycles, status)
    if not ok:
        for i, (a, b) in enumerate(zip(h_hw, h_ref)):
            if a != b:
                print(f"  First mismatch at [{i}]: hw={a}, ref={b}")
                break
    return ok

def resolve_hex_file(spec):
    candidates = [
        spec,
        os.path.join(REPO_ROOT, spec),
        os.path.join(REPO_ROOT, "tb", "vectors", spec),
    ]
    for cand in candidates:
        if os.path.isfile(cand):
            return os.path.abspath(cand)
    raise FileNotFoundError(
        f"Hex vector file '{spec}' not found (checked direct path and tb/vectors/)"
    )

def _build_vector_inputs(idx, rng, active_seed, use_nist, f_custom, g_custom):
    if use_nist and f_custom is None and g_custom is None:
        f_path = resolve_hex_file("tv4_input.hex")
        g_path = resolve_hex_file("tv5_input.hex")
        return load_hex_poly(f_path), load_hex_poly(g_path), "NIST FIPS 203 test vector (tv4 * tv5)"

    if f_custom is not None or g_custom is not None:
        f_poly = list(f_custom) if f_custom is not None else [rng.randrange(ref.Q) for _ in range(N_COEFF)]
        g_poly = list(g_custom) if g_custom is not None else [rng.randrange(ref.Q) for _ in range(N_COEFF)]
        src = "User-supplied polynomial(s)" if (f_custom is not None and g_custom is not None) else f"Mixed custom + random (seed=0x{active_seed:08X})"
        return f_poly, g_poly, src

    f_poly = [rng.randrange(ref.Q) for _ in range(N_COEFF)]
    g_poly = [rng.randrange(ref.Q) for _ in range(N_COEFF)]
    return f_poly, g_poly, f"Fresh random polynomials (seed=0x{active_seed:08X}, draw #{idx + 1})"

def run_live(
    port,
    baud,
    vectors,
    seed,
    use_nist,
    coeffs=8,
    show_all=False,
    interactive=False,
    f_spec=None,
    g_spec=None,
    f_file=None,
    g_file=None,
):
    if serial is None:
        print("[ERROR] pyserial is not installed. Run: pip install pyserial")
        return False

    port = _resolve_port(port)
    if port is None:
        return False

    active_seed = secrets.randbits(32) if seed is None else seed
    rng = random.Random(active_seed)
    f_custom = load_hex_poly(resolve_hex_file(f_file)) if f_file else (parse_poly_spec(f_spec) if f_spec else None)
    g_custom = load_hex_poly(resolve_hex_file(g_file)) if g_file else (parse_poly_spec(g_spec) if g_spec else None)
    all_ok = True

    if interactive:
        mode_desc = f"interactive (session seed=0x{active_seed:08X})"
    elif use_nist and f_custom is None and g_custom is None:
        mode_desc = "NIST FIPS 203 deterministic vector (tv4 * tv5)"
    elif f_custom is not None and g_custom is not None:
        mode_desc = "deterministic user/file polynomials"
    else:
        mode_desc = f"session seed=0x{active_seed:08X}"

    print(f"Connecting to Zybo Z7-10 on {port} @ {baud} bps ({mode_desc})...")
    with serial.Serial(port, baud, timeout=5.0) as ser:
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(0.15)

        if interactive:
            vec_idx = 0
            while True:
                try:
                    cmd = input(
                        "\n[Demo Prompt] [Enter]=random | 'poly'=custom F,G | 'nist'=tv4*tv5 | 'q'=quit > "
                    ).strip().lower()
                except EOFError:
                    break
                if cmd in ("q", "quit", "exit"):
                    break
                if cmd in ("nist", "--nist"):
                    f_poly, g_poly, src = _build_vector_inputs(0, rng, active_seed, True, None, None)
                elif cmd == "poly":
                    f_raw = input("  Enter F(x) (e.g. '1,2,3' or '0:1,255:3328') : ")
                    g_raw = input("  Enter G(x) (e.g. '3,4'   or '1:1')          : ")
                    f_poly = parse_poly_spec(f_raw)
                    g_poly = parse_poly_spec(g_raw)
                    src = "Interactive user polynomial input"
                elif cmd in ("", "rand", "random"):
                    round_seed = secrets.randbits(32)
                    round_rng = random.Random(round_seed)
                    f_poly = [round_rng.randrange(ref.Q) for _ in range(N_COEFF)]
                    g_poly = [round_rng.randrange(ref.Q) for _ in range(N_COEFF)]
                    src = f"Fresh interactive random polynomials (seed=0x{round_seed:08X})"
                else:
                    print(f"[Warn] Unknown command {cmd!r}. Press Enter for random, or type 'nist', 'poly', 'q'.")
                    continue

                ok = _exchange_and_verify(
                    ser, port, baud, vec_idx, None, src, f_poly, g_poly, coeffs, show_all
                )
                all_ok = all_ok and ok
                vec_idx += 1
            return all_ok

        for idx in range(vectors):
            f_poly, g_poly, src = _build_vector_inputs(idx, rng, active_seed, use_nist, f_custom, g_custom)
            ok = _exchange_and_verify(
                ser, port, baud, idx, vectors, src, f_poly, g_poly, coeffs, show_all
            )
            if not ok:
                all_ok = False

    return all_ok

def main():
    parser = argparse.ArgumentParser(description="Live Zybo Z7-10 ML-KEM FPGA Demo")
    parser.add_argument("--port", default="auto", help="Serial COM port (e.g. COM7 or auto)")
    parser.add_argument("--baud", type=int, default=115200, help="UART baud rate (default 115200)")
    parser.add_argument("--vectors", type=int, default=1, help="Number of polynomial multiplications")
    parser.add_argument(
        "--seed",
        type=lambda s: int(s, 0),
        default=None,
        help="RNG seed (dec or 0x hex) for reproducible polynomials (default: fresh random)",
    )
    parser.add_argument("--nist", action="store_true", help="Use fixed NIST FIPS 203 tv4*tv5 instead of random F,G")
    parser.add_argument("--random-first", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--coeffs", type=int, default=8, help="Leading coefficients shown in table alongside last 4 (default 8)")
    parser.add_argument("--show-all", action="store_true", help="Print all 256 coefficients in the verification table")
    parser.add_argument("-f", "--f", dest="f_spec", default=None, help="Custom F(x), e.g. '1,2,3' or '0:1,255:3328'")
    parser.add_argument("-g", "--g", dest="g_spec", default=None, help="Custom G(x), e.g. '3,4' or '1:1'")
    parser.add_argument("--f-file", dest="f_file", default=None, help="Hex file for F(x), e.g. tv1_input.hex or path")
    parser.add_argument("--g-file", dest="g_file", default=None, help="Hex file for G(x), e.g. tv3_input.hex or path")
    parser.add_argument("-i", "--interactive", action="store_true", help="Interactive loop for live random or user-entered polynomials")
    args = parser.parse_args()

    try:
        use_nist = bool(args.nist and not args.random_first)
        ok = run_live(
            port=args.port,
            baud=args.baud,
            vectors=args.vectors,
            seed=args.seed,
            use_nist=use_nist,
            coeffs=args.coeffs,
            show_all=args.show_all,
            interactive=args.interactive,
            f_spec=args.f_spec,
            g_spec=args.g_spec,
            f_file=args.f_file,
            g_file=args.g_file,
        )
    except Exception as exc:
        print(f"[ERROR] {exc}")
        sys.exit(1)

    sys.exit(0 if ok else 2)

if __name__ == "__main__":
    main()
