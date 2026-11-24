#!/usr/bin/env python3

import argparse
import hashlib
import os
import shutil
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
FW_DIR = os.path.join(REPO_ROOT, "software", "firmware")
VEC_DIR = os.path.join(REPO_ROOT, "tb", "vectors")

sys.path.insert(0, os.path.join(REPO_ROOT, "reference"))
import mlkem_ntt_ref as ref  # noqa: E402

N_COEFF = 256
BRAM_WORDS = 8192
CODE_LIMIT_WORDS = 2048  # 0x0000_0000..0x0000_1FFF reserved for ELF sections + BSS
TV_SLOT_WORD = 2048      # 0x0000_2000: dynamic vector slot in BRAM
TV_MAGIC = 0x54563031    # 'TV01'
TV_FLAG_VERIFY = 1

DEFAULT_TOOLCHAIN_DIRS = [
    r"C:\riscv-toolchain\xpack-riscv-none-elf-gcc-15.2.0-1\bin",
]

FIRMWARE_TARGETS = [
    os.path.join(FW_DIR, "firmware.hex"),
    os.path.join(REPO_ROOT, "rtl", "firmware.hex"),
    os.path.join(REPO_ROOT, "rtl", "soc", "firmware.hex"),
    os.path.join(REPO_ROOT, "tb", "firmware.hex"),
    os.path.join(REPO_ROOT, "tb", "integration", "firmware.hex"),
]


def resolve_hex_file(spec):
    for cand in (spec, os.path.join(REPO_ROOT, spec), os.path.join(VEC_DIR, spec)):
        if os.path.isfile(cand):
            return os.path.abspath(cand)
    raise FileNotFoundError(f"Vector file not found: {spec}")


def load_poly_hex(path):
    vals = []
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            tok = line.strip()
            if tok and not tok.startswith("//"):
                vals.append(int(tok, 16) % ref.Q)
    if len(vals) != N_COEFF:
        raise ValueError(f"{path}: expected {N_COEFF} coefficients, got {len(vals)}")
    return vals


def find_toolchain(prefix=None):
    prefixes = [prefix] if prefix else ["riscv-none-elf-", "riscv32-unknown-elf-"]
    for pfx in prefixes:
        gcc = shutil.which(pfx + "gcc")
        objcopy = shutil.which(pfx + "objcopy")
        size = shutil.which(pfx + "size")
        if gcc and objcopy:
            return gcc, objcopy, size
    for bindir in DEFAULT_TOOLCHAIN_DIRS:
        if not os.path.isdir(bindir):
            continue
        for pfx in prefixes:
            gcc = os.path.join(bindir, pfx + "gcc.exe")
            objcopy = os.path.join(bindir, pfx + "objcopy.exe")
            size = os.path.join(bindir, pfx + "size.exe")
            if os.path.isfile(gcc) and os.path.isfile(objcopy):
                return gcc, objcopy, size if os.path.isfile(size) else None
    raise RuntimeError("RISC-V GCC toolchain not found (checked PATH and C:\\riscv-toolchain).")


def compile_base_words(toolchain_prefix=None):
    gcc, objcopy, size = find_toolchain(toolchain_prefix)
    elf_path = os.path.join(FW_DIR, "firmware.elf")
    bin_path = os.path.join(FW_DIR, "firmware.bin")

    cmd_cc = [
        gcc,
        "-march=rv32i",
        "-mabi=ilp32",
        "-O2",
        "-nostdlib",
        "-Wall",
        "-Wextra",
        "-Werror",
        "-T",
        "firmware.lds",
        "-o",
        elf_path,
        "firmware_start.s",
        "firmware.c",
    ]
    subprocess.run(cmd_cc, cwd=FW_DIR, check=True)
    if size:
        subprocess.run([size, elf_path], cwd=FW_DIR, check=True)
    subprocess.run([objcopy, "-O", "binary", elf_path, bin_path], cwd=FW_DIR, check=True)

    with open(bin_path, "rb") as fh:
        raw = fh.read()
    while len(raw) % 4:
        raw += b"\x00"

    if len(raw) > CODE_LIMIT_WORDS * 4:
        raise RuntimeError(f"firmware.bin ({len(raw)} B) exceeds {CODE_LIMIT_WORDS * 4} B code slot")

    words = [int.from_bytes(raw[i : i + 4], "little") for i in range(0, len(raw), 4)]
    words.extend([0] * (BRAM_WORDS - len(words)))
    return words


def load_existing_hex_words(path, force=False):
    if not os.path.isfile(path):
        raise FileNotFoundError(f"Base firmware hex not found: {path}")
    words = []
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            tok = line.strip()
            if tok:
                words.append(int(tok, 16) & 0xFFFFFFFF)
    if len(words) < BRAM_WORDS:
        words.extend([0] * (BRAM_WORDS - len(words)))
    elif len(words) > BRAM_WORDS:
        raise ValueError(f"{path}: expected <= {BRAM_WORDS} words, got {len(words)}")
    if not force and words[TV_SLOT_WORD] != TV_MAGIC:
        raise RuntimeError(
            f"{path} lacks TV01 dynamic header at 0x{TV_SLOT_WORD * 4:04X}; "
            "run without --patch-only first to recompile firmware.c"
        )
    return words


def patch_vector_slot(words, f_coeffs, g_coeffs, h_coeffs, verify=True):
    out = list(words)
    slot = [
        TV_MAGIC,
        N_COEFF,
        TV_FLAG_VERIFY if verify else 0,
        0,
        *(c & 0x0FFF for c in f_coeffs),
        *(c & 0x0FFF for c in g_coeffs),
        *(c & 0x0FFF for c in h_coeffs),
    ]
    end = TV_SLOT_WORD + len(slot)
    if end > BRAM_WORDS:
        raise RuntimeError("Vector slot overflows 32 KB BRAM")
    out[TV_SLOT_WORD:end] = slot
    return out


def write_hex_words(path, words):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        for w in words:
            fh.write(f"{w & 0xFFFFFFFF:08x}\n")


def main():
    parser = argparse.ArgumentParser(description="Build/patch non-hardcoded firmware.hex")
    parser.add_argument("--f-file", default="tv4_input.hex", help="F polynomial hex file")
    parser.add_argument("--g-file", default="tv5_input.hex", help="G polynomial hex file")
    parser.add_argument("--h-file", default=None, help="Optional expected H hex file")
    parser.add_argument("--patch-only", action="store_true", help="Patch existing firmware.hex without recompiling")
    parser.add_argument("--input-hex", default=os.path.join(FW_DIR, "firmware.hex"), help="Input hex for --patch-only")
    parser.add_argument("--force", action="store_true", help="Allow --patch-only on uninitialized firmware.hex")
    parser.add_argument("--no-verify", action="store_true", help="Disable on-chip H comparison flag")
    parser.add_argument("--toolchain", default=None, help="RISC-V GCC prefix override")
    parser.add_argument("--no-propagate", action="store_true", help="Write only software/firmware/firmware.hex")
    args = parser.parse_args()

    f_path = resolve_hex_file(args.f_file)
    g_path = resolve_hex_file(args.g_file)
    f_coeffs = load_poly_hex(f_path)
    g_coeffs = load_poly_hex(g_path)

    if args.h_file:
        h_path = resolve_hex_file(args.h_file)
        h_coeffs = load_poly_hex(h_path)
    else:
        h_coeffs = ref.poly_mul(f_coeffs, g_coeffs)
        default_res = os.path.join(VEC_DIR, "tv_polymul_result.hex")
        if (
            os.path.basename(f_path) == "tv4_input.hex"
            and os.path.basename(g_path) == "tv5_input.hex"
            and os.path.isfile(default_res)
        ):
            expected_res = load_poly_hex(default_res)
            if h_coeffs != expected_res:
                raise RuntimeError("Computed tv4*tv5 mismatches tb/vectors/tv_polymul_result.hex")

    if args.patch_only:
        words = load_existing_hex_words(args.input_hex, force=args.force)
        mode = "PATCH-ONLY"
    else:
        words = compile_base_words(args.toolchain)
        mode = "COMPILE+PATCH"

    words = patch_vector_slot(words, f_coeffs, g_coeffs, h_coeffs, verify=not args.no_verify)

    targets = [FIRMWARE_TARGETS[0]] if args.no_propagate else FIRMWARE_TARGETS
    for dst in targets:
        write_hex_words(dst, words)

    with open(targets[0], "rb") as fh:
        digest = hashlib.sha256(fh.read()).hexdigest()[:12]

    print(f"[{mode}] F={os.path.relpath(f_path, REPO_ROOT)} ({' '.join(f'{c:03X}' for c in f_coeffs[:4])} ...)")
    print(f"[{mode}] G={os.path.relpath(g_path, REPO_ROOT)} ({' '.join(f'{c:03X}' for c in g_coeffs[:4])} ...)")
    print(f"[{mode}] H={'computed(FIPS203)' if not args.h_file else os.path.relpath(args.h_file, REPO_ROOT)} ({' '.join(f'{c:03X}' for c in h_coeffs[:4])} ...)")
    print(f"[{mode}] sha256={digest} -> updated {len(targets)} firmware.hex file(s):")
    for dst in targets:
        print(f"  - {os.path.relpath(dst, REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
