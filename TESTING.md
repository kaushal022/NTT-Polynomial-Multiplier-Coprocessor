# Testing & Verification Guide

This document describes the complete verification workflow for the **ML-KEM NTT Polynomial-Multiplier Coprocessor** on **Digilent Zybo Z7-10** (`xc7z010clg400-1`) — from the Python FIPS 203 mathematical reference through RTL simulation, formal checks, and live FPGA hardware testing.

---

## Verification Flow Overview

```text
1. Python Mathematical Model (reference/mlkem_ntt_ref.py)
        │  Generates canonical vectors in tb/vectors/ & tb/vectors/random_100/
        ▼
2. Vivado XSim RTL Verification
        ├── Unit tests        (scripts/run_tb_arithmetic.bat, tb/unit/*)
        ├── 100-vec regression(scripts/run_regression_100.bat)
        └── Full Hybrid SoC   (scripts/run_hybrid_sim.bat -> tb_hybrid_soc_top)
        │
        ▼
3. Formal Verification (formal/nusmv/, formal/symbiyosys/)
        │
        ▼
4. Zybo Z7-10 FPGA Hardware Testing
        ├── Zynq Hybrid Flow  (xsdb scripts/launch_zybo_demo.tcl -> live_demo.py / live_demo_100.py)
        └── PL-Only SoC Flow  (bitstream/soc_top.bit -> ILA / scripts/verify_hardware.py)
```

---

## Stage 1: Mathematical Reference & Golden Vectors

All RTL testbenches and host hardware scripts validate against the NIST FIPS 203 reference implementation in `reference/mlkem_ntt_ref.py` over $R_q = \mathbb{Z}_{3329}[X] / (X^{256} + 1)$ ($\zeta = 17$, $128^{-1} \bmod 3329 = 3303$).

### 1.1 Run Reference Model Self-Tests
Verifies primitive root properties, modular arithmetic, NTT/INTT roundtrip, NTT linearity, base-case multiplication, and `poly_mul` against schoolbook negacyclic multiplication:

```powershell
python reference/mlkem_ntt_ref.py
```

### 1.2 Generate Canonical Test Vectors
Writes single test vectors (`tv1`–`tv5` and `tv_polymul_result.hex`) into `tb/vectors/`:

```powershell
python reference/gen_test_vectors.py
```

Key files produced in `tb/vectors/`:
- `tv1_input.hex`, `tv3_input.hex` — simple deterministic test polynomials
- `tv4_input.hex`, `tv5_input.hex` — full-width pseudo-random polynomial pair
- `tv_polymul_result.hex` — expected product $F \cdot G \bmod (X^{256}+1, 3329)$ for `tv4_input.hex * tv5_input.hex`

### 1.3 Generate 100 Random Test Vectors
Generates 100 random polynomial pairs (`25,600` output coefficients) in `tb/vectors/random_100/`:

```powershell
python reference/gen_100_random_vectors.py
```

Produces:
- `tb/vectors/random_100/test_vectors_100.json`
- Flat concatenated hex files (`inputs_f.hex`, `inputs_g.hex`, `expected_f_hat.hex`, `expected_g_hat.hex`, `expected_h_hat.hex`, `expected_h.hex`) and per-vector hex files (`f_000.hex`..`f_099.hex`, `g_*`, `h_*`).

> **Note:** Scripts and `xsim` runners resolve test vectors strictly from `tb/vectors/` (and `tb/vectors/random_100/`).

---

## Stage 2: RTL Simulation (Vivado `xsim`)

All `.bat` runners invoke Vivado 2024.2 (`C:\Xilinx\Vivado\2024.2\bin`) and work from any working directory.

### 2.1 Arithmetic Unit Simulation
Tests `mod_add`, `mod_sub`, and `mod_mul` via `tb/unit/tb_arithmetic.v`:

```cmd
scripts\run_tb_arithmetic.bat
```

### 2.2 100-Vector Polynomial Multiplier Regression
Runs `tb/regression/tb_regression_100.v` against `tb/vectors/random_100/{inputs_f,inputs_g,expected_h}.hex` (`poly_multiplier` core + arithmetic/butterfly/BRAM/ROM modules):

```cmd
scripts\run_regression_100.bat
```

Checks all 100 vector pairs (`25,600` coefficients) bit-for-bit against the saved golden outputs.

### 2.3 Full 8-Step Hybrid SoC Simulation
Simulates the complete Zynq-side AXI interface + PicoRV32 + DMA + Coprocessor + Interrupt flow (`tb/integration/tb_hybrid_soc_top.v` running `rtl/soc/firmware_hybrid.hex` in an isolated `%TEMP%\mlkem_hybrid_xsim` run directory):

```cmd
scripts\run_hybrid_sim.bat
```

What it exercises:
1. Emulated Zynq PS7 GP0 writes `tv4_input.hex` and `tv5_input.hex` into `axi_mailbox` and rings the doorbell.
2. `ntt_dma` loads `F` and `G` into the coprocessor BRAMs.
3. PicoRV32 triggers computation; `interrupt_ctrl` raises IRQ upon completion (`6677` hardware cycles).
4. PicoRV32 ISR & DMA store `H` back to `axi_mailbox` and update status flags (`0x3F`).
5. **Test 1** checks all 256 NIST coefficients against `tb/vectors/tv_polymul_result.hex`; **Test 2** runs a consecutive identity test (`512/512 OK`, `DMA x6`, `IRQ x2`).

### 2.4 Additional Vivado Testbenches
Available for GUI/CLI simulation in Vivado:
- **Unit (`tb/unit/`):** `tb_butterfly.v`, `tb_ntt_debug.v`, `tb_ntt_layer_debug.v`
- **Integration (`tb/integration/`):** `tb_ntt_engine.v`, `tb_poly_multiplier.v`, `tb_mlkem_coprocessor_top.v`, `tb_soc_top.v`

---

## Stage 3: Formal Verification

Formal models in `formal/` prove control and addressing properties independent of simulation stimuli:

- **NuSMV (`formal/nusmv/ntt_addr_gen.smv`):** Model-checks safety and liveness of the 7-layer NTT address generator/controller — no dual-port BRAM address collision (`addr_lo != addr_hi`), `layer_idx <= 6`, `tw_addr <= 127`, and guaranteed termination (`start -> AF ntt_done`).
- **SymbiYosys (`formal/symbiyosys/bram_no_collision.sby`):** Runs `bmc`, `prove` (depth 30 with `smtbmc z3`), and `bug_inject` (`expect fail` negative check) directly on `rtl/ntt/ntt_addr_gen.v` via `bram_no_collision.v`.

---

## Stage 4: Zybo Z7-10 Live Hardware Testing

The project supports two hardware deployment architectures on Zybo Z7-10. Both use the pre-built artifacts in `bitstream/`, or can be rebuilt from source.

### Option A: Zynq Hybrid Architecture (Onboard Micro-USB UART — Primary Live Demo)

In this flow, the onboard Zynq ARM Cortex-A9 bridges UART1 (`MIO 48/49`, USB-UART) to `pl_hybrid_soc` over `M_AXI_GP0` (`0x43C0_0000`).

#### 1. Rebuild Hardware / Firmware (Only If Source Changed)
- **FPGA bitstream & XSA** (`bitstream/zynq_hybrid_soc.bit`, `zynq_hybrid_soc.xsa`):
  ```cmd
  vivado -mode batch -source scripts/build_zynq_hybrid.tcl
  ```
- **ARM PS7 bridge ELF** (`software/ps_bridge/ps_bridge.elf`):
  ```powershell
  powershell -ExecutionPolicy Bypass -File software/ps_bridge/build_ps_bridge.ps1
  ```
- **PicoRV32 hybrid firmware** (`rtl/soc/firmware_hybrid.hex`):
  ```cmd
  make -C software/firmware hybrid
  ```

#### 2. Program & Boot the Board via JTAG (`xsdb`)
Connect the Zybo Z7-10 over USB (J12 / PROG UART) and run:

```cmd
C:\Xilinx\Vivado\2024.2\bin\xsdb.bat scripts/launch_zybo_demo.tcl
```

This resets the APU, flashes `bitstream/zynq_hybrid_soc.bit`, initializes PS7 clocks/UART1/GP0 using `bitstream/zynq_hybrid_soc.xsa` and `bitstream/ps7_init.tcl`, and starts `software/ps_bridge/ps_bridge.elf` on ARM Cortex-A9 Core #0.

#### 3. UART Binary Protocol (`115200` baud, 8N1)
- **Host → FPGA (`1,026` bytes):** `[0xA5, 0x5A]` + `256 × uint16 LE` ($F$) + `256 × uint16 LE` ($G$)
- **FPGA → Host (`517` bytes):** `256 × uint16 LE` ($H$) + `uint32 LE` (`cycle_count`) + `uint8` status flags (`0x3F` = `[UART_OK|RV32_RUN|DMA_DONE|COPROC_DONE|IRQ_RECV|RESP_READY]`)

#### 4. Live Interactive / Custom / Vector Testing (`scripts/live_demo.py`)

Requires `pyserial` (`pip install pyserial`).

```powershell
# 1 fresh OS-entropy random pair (auto-detects COM port)
python scripts/live_demo.py --port auto

# Multiple random pairs on explicit COM port
python scripts/live_demo.py --port COM7 --vectors 5

# Reproducible random run using decimal or hex seed printed in banner
python scripts/live_demo.py --port auto --seed 0xA979A8A8 --vectors 5

# Custom dense polynomials: (1 + 2x)(3 + 4x) -> 3 + 10x + 8x^2
python scripts/live_demo.py --port auto -f "1,2" -g "3,4"

# Values larger than 3328 are automatically reduced mod 3329
python scripts/live_demo.py --port auto -f "1,2,8939,88828" -g "3,4,2828,2727,290"

# Sparse index:value syntax (negacyclic wrap check: x * x^255 = -1 = 3328 mod 3329)
python scripts/live_demo.py --port auto -f "1:1" -g "255:1"

# Supply one custom polynomial and randomize the other
python scripts/live_demo.py --port auto -f "0:5,10:100,200:3000"

# Fixed deterministic vector pair from tb/vectors/ (tv4 * tv5)
python scripts/live_demo.py --port auto --nist

# Specific hex vector files (resolved directly or from tb/vectors/)
python scripts/live_demo.py --port auto --f-file tv1_input.hex --g-file tv3_input.hex
python scripts/live_demo.py --port auto --f-file tb/vectors/tv4_input.hex --g-file tb/vectors/tv5_input.hex

# Interactive prompt loop (random, nist, custom polynomials)
python scripts/live_demo.py --port auto -i

# Adjust coefficient preview count or dump all 256 coefficients
python scripts/live_demo.py --port auto --coeffs 16
python scripts/live_demo.py --port auto --show-all
```

#### 5. 100-Vector Hardware Batch Verification (`scripts/live_demo_100.py`)
Streams all 100 saved polynomial pairs across the live Zybo Z7-10 pipeline and verifies each result against both the saved golden output and `reference/mlkem_ntt_ref.py`:

```powershell
# Run all 100 vectors from tb/vectors/random_100/test_vectors_100.json
python scripts/live_demo_100.py --port auto

# Regenerate the 100-vector dataset via reference/gen_100_random_vectors.py first, then test on hardware
python scripts/live_demo_100.py --port auto --regen

# Load directly from flat hex directory (inputs_f.hex / inputs_g.hex / expected_h.hex)
python scripts/live_demo_100.py --port auto --dataset tb/vectors/random_100

# Run a slice (vectors 10..19) with detailed coefficient tables for every vector
python scripts/live_demo_100.py --port auto --start 10 --count 10 --verbose

# Adjust detailed table preview / print all 256 rows / save JSON hardware report
python scripts/live_demo_100.py --port auto --coeffs 8 --show-all --save results/zybo_100_vec_log.json
```

Each vector prints compact 12-bit hex previews (`[c0,c1,c2,..]`) for `F`, `G`, `H_fpga`, `H_ref`, cycle count (`6677` cycles = `66.77 us` @ `100 MHz`), status flags (`0x3F`), and final pass summary (`100/100 vectors PASSED`, `25,600/25,600 coefficients OK`).

---

### Option B: Standalone PL-Only SoC (`soc_top` + PMOD JC UART + Vivado ILA)

Uses `bitstream/soc_top.bit` and `bitstream/soc_top.ltx` (clocked from the 125 MHz board oscillator on `K17` via `PLLE2_BASE`, reset `BTN0` on `K18`, PMOD JC `V15`/`W15` external 3.3 V USB-TTL adapter).

1. **Rebuild (optional):**
   ```cmd
   vivado -mode batch -source scripts/build_bitstream.tcl
   ```
2. **Program & Inspect Status LEDs / ILA:**
   - Program `bitstream/soc_top.bit` + `bitstream/soc_top.ltx` in Vivado Hardware Manager.
   - Check LEDs: `LD0` (`M14`) = Ready, `LD1` (`M15`) = Busy, `LD2` (`G14`) = Done/Verified, `LD3` (`D18`) = CPU Trap (must stay OFF).
   - For ILA capture, trigger on `core_start_w == 1` with capture filter `dbg_result_ren == 1` and press `BTN0` (`K18`).
3. **Run PMOD JC UART Hardware Verification (`scripts/verify_hardware.py`):**
   ```powershell
   python scripts/verify_hardware.py --port COM3 --baud 115200 --vectors 100
   ```
   (Supports `--seed` for reproducible runs; expects `status == 0x00` from `software/firmware/firmware.c`.)

---

## Vivado Project Note (`UART_Testing/UART_Testing.xpr`)

`UART_Testing/UART_Testing.xpr` is configured for `tb_hybrid_soc_top` simulation (`sim_1`), while `sources_1` lists `pl_hybrid_soc` as top with `constraints/zynq_hybrid.xdc`. Running Vivado **Implementation** (`place_design`) directly on `pl_hybrid_soc` fails with `[Place 30-58]` / `[Place 30-374]` because the internal `s_ps_axi_*` and `resetn` Block-Design ports are unconstrained (`LVCMOS18`) on a chip whose PL banks are already locked to `3.30 V` (`LVCMOS33`).
- To implement the **Zynq Hybrid** design, run `scripts/build_zynq_hybrid.tcl` (which wraps `pl_hybrid_soc` in `zynq_hybrid_bd_wrapper`).
- To implement the **standalone PL UART SoC** inside `UART_Testing`, change `TopModule` to `soc_top` and enable `constraints/zybo_z7_10.xdc` (instead of `zynq_hybrid.xdc`).
