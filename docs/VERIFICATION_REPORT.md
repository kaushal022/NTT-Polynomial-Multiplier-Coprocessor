# ML-KEM NTT Coprocessor — Verification & Synthesis Report

**Date:** 2026-11-23 (Regenerated and verified with Vivado 2024.2 batch synthesis, implementation, and simulation suite)  
**Target Device:** Digilent Zybo Z7-10 (`xc7z010clg400-1`)  
**Target Clock:** 100 MHz (Clock Period: 10.000 ns)  
**Standard:** NIST FIPS 203 (ML-KEM / Kyber, $q = 3329, n = 256$)

---

## 1. Executive Summary

The ML-KEM polynomial multiplier coprocessor has been fully designed, simulated, verified, formally proven, synthesized, and implemented (placed and routed) for the Digilent Zybo Z7-10 FPGA.
- **Timing Closure Achieved:** Timing is closed at **100 MHz** with **WNS = +0.822 ns**, **WHS = +0.015 ns**, and **WPWS = +4.020 ns** (0 failing setup/hold/pulse-width endpoints; maximum operating frequency: **108.96 MHz** on core intra-clock paths). In the full `soc_top` SoC (including PicoRV32, UART, BRAM, and ILA debug cores), timing is closed at **100 MHz** with **WNS = +0.537 ns** ($F_{\max} = 105.67\text{ MHz}$). In the Zynq-7000 Hybrid SoC (`zynq_hybrid_bd_wrapper`), timing is closed with **WNS = +0.576 ns** ($F_{\max} = 106.11\text{ MHz}$).
- **Resource Optimization:** Pipelining Barrett modular multiplication with shift-add reduction kept DSP slice count down to **18 DSP48E1** (22.50% of Zybo Z7-10 capacity — +2 DSPs added for embedded INTT scaling), with only **1,105 LUTs** (6.28%), **961 Registers** (2.73%), and **6 RAMB18E1** (5.00% — utilizing ping-pong scratch memory for collision-free single-cycle butterfly throughput).
- **Cycle-Count Requirement Met:** **Both** NTT cycle targets are satisfied: Forward NTT completes in **940 cycles** and Inverse NTT (with embedded modular scaling) completes in **943 cycles** — both well within the ≤1,000 cycle project requirement. The previous sequential scaling pass (256 extra cycles) was eliminated by folding the $n^{-1} = 3303$ multiplication into the last INTT layer's write-back pipeline. Full negacyclic polynomial multiplication completes in **6,677 clock cycles** (66.77 µs @ 100 MHz).
- **Verification Coverage:** 100% pass rate across unit testbenches (30,014 arithmetic vectors), 7-layer CT forward / GS inverse NTT round-trip, full polynomial multiplication against NIST FIPS 203 TV4 * TV5, **100/100 random input polynomial pairs (25,600 coefficients bit-exact)** in regression (`tb_regression_100.v`), complete 8-step Zynq Hybrid SoC simulation with DMA x6 and IRQ x2 (`tb_hybrid_soc_top.v`, 512/512 coefficients bit-exact), bitstream generation for both Standalone SoC (`soc_top.bit`, `soc_top.ltx`) and Zynq Hybrid (`zynq_hybrid_soc.bit`, `zynq_hybrid_soc.xsa`), AXI4-Lite MMIO register operations with interrupt generation, NuSMV CTL/LTL model checking, SymbiYosys BMC depth-30 proofs, and Vitis HLS C-simulation.

---

## 2. Verification Evidence Matrix

| Component / Testbench | Verification Type | Tool & Flow | Test Vectors / Properties | Status | Artifact / Report Path |
|---|---|---|---|---|---|
| `tb_arithmetic` | Unit RTL Simulation | Vivado XSIM 2024.2 | 30,014 tests (random + corners) | **PASS** | [`rtl/arithmetic/`](../rtl/arithmetic/), [`tb/unit/tb_arithmetic.v`](../tb/unit/tb_arithmetic.v) |
| `tb_butterfly` | Unit RTL Simulation | Vivado XSIM 2024.2 | 2,005 tests (CT forward & GS inverse) | **PASS** | [`rtl/butterfly/butterfly.v`](../rtl/butterfly/butterfly.v), [`tb/unit/tb_butterfly.v`](../tb/unit/tb_butterfly.v) |
| `tb_ntt_engine` | Integration Simulation | Vivado XSIM 2024.2 | 256/256 coefficient round-trip | **PASS** | [`rtl/ntt/ntt_engine.v`](../rtl/ntt/ntt_engine.v), [`tb/integration/tb_ntt_engine.v`](../tb/integration/tb_ntt_engine.v) |
| `tb_poly_multiplier` | Top Datapath Sim | Vivado XSIM 2024.2 | NIST FIPS 203 TV4 * TV5 bit-exact match | **PASS** | [`rtl/ntt/poly_multiplier.v`](../rtl/ntt/poly_multiplier.v), [`tb/integration/tb_poly_multiplier.v`](../tb/integration/tb_poly_multiplier.v) |
| `tb_regression_100` | 100-Vector Regression | Vivado XSIM 2024.2 | 100 random polynomial pairs (25,600 words) | **PASS** | [`tb/regression/tb_regression_100.v`](../tb/regression/tb_regression_100.v), [`tb/vectors/random_100/`](../tb/vectors/random_100/) |
| `tb_hybrid_soc_top` | Full Hybrid SoC Sim | Vivado XSIM 2024.2 | Zynq PS7 GP0 -> Mailbox -> DMA x6 -> Coproc -> IRQ x2 | **PASS** | [`tb/integration/tb_hybrid_soc_top.v`](../tb/integration/tb_hybrid_soc_top.v), [`scripts/run_hybrid_sim.bat`](../scripts/run_hybrid_sim.bat) |
| `tb_mlkem_coprocessor_top` | AXI-Lite MMIO & IRQ | Vivado XSIM 2024.2 | Pipelined top-level verification, IRQ assertion | **PASS** | [`rtl/axi/axi_lite_coprocessor.v`](../rtl/axi/axi_lite_coprocessor.v), [`tb/integration/tb_mlkem_coprocessor_top.v`](../tb/integration/tb_mlkem_coprocessor_top.v) |
| BRAM No-Collision BMC & Induction | Formal Proof (BMC + Prove) | SymbiYosys + Z3 SMT | Depth 30 & $k$-induction, address disjointness | **PASS** | [`formal/symbiyosys/bram_no_collision.v`](../formal/symbiyosys/bram_no_collision.v), [`.sby`](../formal/symbiyosys/bram_no_collision.sby) |
| Injected Fault Detection | BMC Counterexample | SymbiYosys + Z3 SMT | Injected layer-0 address collision | **PASS (Step 5)** | [`formal/symbiyosys/`](../formal/symbiyosys/) |
| NTT Address Safety & Liveness | Unbounded Model Checking | NuSMV 2.6.0 | 5 CTL & LTL properties (all reachable states) | **PASS** | [`formal/nusmv/ntt_addr_gen.smv`](../formal/nusmv/ntt_addr_gen.smv) |
| HLS Butterfly C-Sim & Synth | High-Level Synthesis | Vitis HLS 2024.2 | 1-DSP vs 2-DSP resource variants | **PASS** | [`hls/butterfly.cpp`](../hls/butterfly.cpp), [`hls/run_hls.tcl`](../hls/run_hls.tcl) |
| Place & Route Implementation | FPGA Timing Closure | Vivado 2024.2 Impl | 100 MHz target, Zybo Z7-10 | **PASS (WNS +0.822 ns)** | [`results/synthesis/mlkem_coprocessor_routed.dcp`](../results/synthesis/mlkem_coprocessor_routed.dcp) |
| Standalone SoC Bitstream | Full FPGA Bitstream + ILA | Vivado 2024.2 Batch | 100 MHz clk_100m, PicoRV32 + Coprocessor + UART + ILA | **PASS (WNS +0.537 ns)** | [`bitstream/soc_top.bit`](../bitstream/soc_top.bit), [`bitstream/soc_top.ltx`](../bitstream/soc_top.ltx) |
| Zynq Hybrid Bitstream & XSA | PS7 + PL Block Design | Vivado 2024.2 Batch | ARM Cortex-A9 PS7 + Mailbox + DMA + Coprocessor | **PASS (WNS +0.576 ns)** | [`bitstream/zynq_hybrid_soc.bit`](../bitstream/zynq_hybrid_soc.bit), [`.xsa`](../bitstream/zynq_hybrid_soc.xsa) |

---

## 3. FPGA Resource Utilization (Post-Implementation / Routed)

Target device: **Digilent Zybo Z7-10 (`xc7z010clg400-1`)**  

Because this repository contains both out-of-context IP cores and full system-on-chip bitstream builds for on-board testing, utilization is presented for all three distinct scopes:
1. **Target 1:** Pure Coprocessor IP Core (`mlkem_coprocessor_top`) — standard metric for IP benchmarking.
2. **Target 2:** Standalone PL SoC (`soc_top`) — includes PicoRV32 RISC-V CPU, 32 KB BRAM, UART, and Vivado ILA debug probes.
3. **Target 3:** Zynq Hybrid Architecture (`pl_hybrid_soc` / `zynq_hybrid_bd_wrapper`) — includes PS7 ARM Cortex-A9 interconnect, DMA, mailbox, and PicoRV32.

---

### 3.1 Scope 1: Out-of-Context Coprocessor Core (`mlkem_coprocessor_top`)

* Implementation checkpoint: [`results/synthesis/mlkem_coprocessor_routed.dcp`](../results/synthesis/mlkem_coprocessor_routed.dcp)  
* Utilization report: [`results/synthesis/impl_utilization.rpt`](../results/synthesis/impl_utilization.rpt)

| Resource | Used | Available | Utilization (%) | Margin / Headroom |
|---|---|---|---|---|
| **Slice LUTs** | **1,105** | 17,600 | **6.28%** | 16,495 LUTs (93.72% free) |
| - *LUT as Logic* | 1,077 | 17,600 | 6.12% | — |
| - *LUT as Memory (SRL)* | 28 | 6,000 | 0.47% | — |
| **Slice Registers (FF)** | **961** | 35,200 | **2.73%** | 34,239 FFs (97.27% free) |
| **Block RAM (RAMB18E1)** | **6** | 120 | **5.00%** | 114 RAMB18E1 (95.00% free) |
| **DSPs (DSP48E1)** | **18** | 80 | **22.50%** | 62 DSP48E1 (77.50% free) |
| **Occupied Slices** | **387** | 4,400 | **8.80%** | 4,013 Slices (91.20% free) |

#### Component-Wise (Hierarchical) Breakdown — Coprocessor IP

Generated from routed checkpoint: [`results/synthesis/impl_utilization_hierarchical.rpt`](../results/synthesis/impl_utilization_hierarchical.rpt)

| Instance | Module | Total LUTs | Logic LUTs | SRLs | FFs | RAMB18E1 | DSP48E1 | Description |
|---|---|---|---|---|---|---|---|---|
| `mlkem_coprocessor_top` | *top* | **1,105** | 1,077 | 28 | **961** | **6** | **18** | Full Coprocessor Top |
| ├── `u_axi_slave` | `axi_lite_coprocessor` | 59 | 59 | 0 | 95 | 0 | 0 | AXI4-Lite MMIO & Registers |
| └── `u_poly_mul_core` | `poly_multiplier` | 1,047 | 1,019 | 28 | 848 | 6 | 18 | Polynomial Multiplier Core |
| &nbsp;&nbsp;&nbsp;&nbsp;├── *(control / glue logic)* | *fsm* | 93 | 93 | 0 | 233 | 0 | 0 | Top Core FSM & Registers |
| &nbsp;&nbsp;&nbsp;&nbsp;├── `u_bram_f` | `poly_bram` | 12 | 12 | 0 | 0 | 1 | 0 | Input $f$ BRAM (256x12) |
| &nbsp;&nbsp;&nbsp;&nbsp;├── `u_bram_g` | `poly_bram` | 0 | 0 | 0 | 0 | 1 | 0 | Input $g$ BRAM (256x12) |
| &nbsp;&nbsp;&nbsp;&nbsp;├── `u_bram_temp` | `poly_bram` | 0 | 0 | 0 | 0 | 1 | 0 | Temp BRAM for $\hat{f}$ (256x12) |
| &nbsp;&nbsp;&nbsp;&nbsp;├── `u_bram_work` | `poly_bram` | 0 | 0 | 0 | 0 | 1 | 0 | Working / Output BRAM (256x12) |
| &nbsp;&nbsp;&nbsp;&nbsp;├── `u_neg_gamma` | `mod_sub` | 13 | 13 | 0 | 0 | 0 | 0 | Gamma negation mod $q$ |
| &nbsp;&nbsp;&nbsp;&nbsp;├── `u_basemul` | `basemul` | **346** | 329 | 17 | **217** | **0** | **10** | 128 Base Multipliers |
| &nbsp;&nbsp;&nbsp;&nbsp;│&nbsp;&nbsp;&nbsp;&nbsp;├── `u_a0b0` | `mod_mul` | 50 | 50 | 0 | 13 | 0 | 2 | $a_0 \cdot b_0 \pmod q$ |
| &nbsp;&nbsp;&nbsp;&nbsp;│&nbsp;&nbsp;&nbsp;&nbsp;├── `u_a0b1` | `mod_mul` | 72 | 72 | 0 | 25 | 0 | 2 | $a_0 \cdot b_1 \pmod q$ |
| &nbsp;&nbsp;&nbsp;&nbsp;│&nbsp;&nbsp;&nbsp;&nbsp;├── `u_a1b0` | `mod_mul` | 63 | 63 | 0 | 25 | 0 | 2 | $a_1 \cdot b_0 \pmod q$ |
| &nbsp;&nbsp;&nbsp;&nbsp;│&nbsp;&nbsp;&nbsp;&nbsp;├── `u_a1b1` | `mod_mul` | 50 | 50 | 0 | 25 | 0 | 2 | $a_1 \cdot b_1 \pmod q$ |
| &nbsp;&nbsp;&nbsp;&nbsp;│&nbsp;&nbsp;&nbsp;&nbsp;├── `u_a1b1g` | `mod_mul` | 75 | 75 | 0 | 25 | 0 | 2 | $(a_1 b_1) \cdot \gamma \pmod q$ |
| &nbsp;&nbsp;&nbsp;&nbsp;│&nbsp;&nbsp;&nbsp;&nbsp;├── `u_c0`, `u_c1` | `mod_add` | 12 | 12 | 0 | 0 | 0 | 0 | Modular adders for $c_0, c_1$ |
| &nbsp;&nbsp;&nbsp;&nbsp;│&nbsp;&nbsp;&nbsp;&nbsp;└── *(pipeline registers)* | *regs* | 34 | 17 | 17 | 104 | 0 | 0 | Basemul pipeline stages |
| &nbsp;&nbsp;&nbsp;&nbsp;└── `u_ntt` | `ntt_engine` | **584** | 573 | 11 | **398** | **2** | **8** | Pipelined NTT Engine |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├── *(engine fsm / shift)* | *fsm* | 51 | 41 | 10 | 144 | 0 | 0 | WB address pipe & control |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├── `u_scratch` | `poly_bram` | 29 | 29 | 0 | 0 | 1 | 0 | Ping-pong scratch BRAM |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├── `u_tw_rom` | `twiddle_rom` | 4 | 4 | 0 | 2 | 1 | 0 | 128x12 Twiddle ROM |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├── `u_addr_gen` | `ntt_addr_gen` | 131 | 131 | 0 | 50 | 0 | 0 | 7-layer Address Generator |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├── `u_scale_lo_mul` | `mod_mul` | 50 | 50 | 0 | 25 | 0 | 2 | Embedded $n^{-1} = 3303$ Scale Lo Multiplier |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├── `u_scale_hi_mul` | `mod_mul` | 50 | 50 | 0 | 25 | 0 | 2 | Embedded $n^{-1} = 3303$ Scale Hi Multiplier |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;└── `u_butterfly` | `butterfly` | **269** | 268 | 1 | **152** | **0** | **4** | CT / GS Butterfly Unit |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├── `u_mul_fw` | `mod_mul` | 87 | 87 | 0 | 25 | 0 | 2 | CT Forward Multiplier |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├── `u_mul_gs` | `mod_mul` | 63 | 63 | 0 | 25 | 0 | 2 | GS Inverse Multiplier |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├── `u_add/sub_gs/fw` | `mod_add/sub` | 34 | 34 | 0 | 0 | 0 | 0 | Butterfly add/sub units |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;└── *(stage registers)* | *regs* | 85 | 84 | 1 | 102 | 0 | 0 | Butterfly pipeline alignment |

---

### 3.2 Scope 2: Standalone PL SoC (`soc_top` — FPGA Hardware & ILA Capture Top)

* Implementation checkpoint: [`results/implementation/soc_top_routed.dcp`](../results/implementation/soc_top_routed.dcp)  
* Utilization reports: [`results/implementation/soc_top_impl_utilization.rpt`](../results/implementation/soc_top_impl_utilization.rpt), [`results/implementation/soc_top_impl_utilization_hierarchical.rpt`](../results/implementation/soc_top_impl_utilization_hierarchical.rpt)  
* Synthesis report (pre-ILA insertion): [`results/synthesis/soc_top_utilization.rpt`](../results/synthesis/soc_top_utilization.rpt) (2,656 LUTs, 1,857 FFs, 8 RAMB36, 6 RAMB18)

> **Understanding the Higher Numbers in Vivado for `soc_top`:**  
> When `soc_top` is implemented with the Zybo Z7-10 constraints ([`constraints/zybo_z7_10.xdc`](../constraints/zybo_z7_10.xdc)), Vivado inserts an **Integrated Logic Analyzer (`u_ila_0`)** and **JTAG Debug Hub (`dbg_hub`)** for real-time waveform capture. Non-functional debug logic accounts for **1,583 LUTs and 2,459 Flip-Flops**.

| System Component | Slice LUTs | Logic LUTs | LUTRAM / SRL | FFs | RAMB36 | RAMB18 | DSP48E1 | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| **`u_mlkem` (Coprocessor Core)** | **1,101** | 1,073 | 0 / 28 | **955** | 0 | **6** | **18** | Matches OOC core (Target 1) |
| **`u_cpu` (`picorv32_axi`)** | **1,132** | 1,044 | 88 / 0 | **624** | 0 | 0 | 0 | RV32I soft processor core |
| **`u_uart` (`simpleuart`)** | **93** | 93 | 0 / 0 | **131** | 0 | 0 | 0 | 115200 baud UART transceiver |
| **`u_demux` (`axi_demux`)** | **68** | 68 | 0 / 0 | **7** | 0 | 0 | 0 | AXI4-Lite crossbar demux |
| **SoC Top Glue & 32 KB BRAM** | **111** | 111 | 0 / 0 | **140** | **8** | 0 | 0 | CPU instruction/data memory |
| **Functional SoC Total (No ILA)** | **2,504** | 2,389 | 88 / 28 | **1,857** | **8** | **6** | **18** | **Actual application hardware** |
| `u_ila_0` (Vivado ILA Core) | 1,135 | 984 | 0 / 151 | 1,718 | 1 | 1 | 0 | Real-time debug probe capture |
| `dbg_hub` (JTAG Debug Hub) | 448 | 424 | 24 / 0 | 741 | 0 | 0 | 0 | Vivado Hardware Manager link |
| **Total Routed `soc_top` (w/ ILA)** | **4,087** | **3,796** | **112 / 179** | **4,316** | **9** | **7** | **18** | **Total seen in Vivado Hardware build** |

---

### 3.3 Scope 3: Zynq Hybrid Architecture (`pl_hybrid_soc` / `zynq_hybrid_bd_wrapper`)

* Implementation checkpoint: [`results/synthesis/zynq_hybrid_utilization.rpt`](../results/synthesis/zynq_hybrid_utilization.rpt)  
* Hierarchical report: [`results/synthesis/zynq_hybrid_utilization_hier.rpt`](../results/synthesis/zynq_hybrid_utilization_hier.rpt)  
* Bitstream & Platform: [`bitstream/zynq_hybrid_soc.bit`](../bitstream/zynq_hybrid_soc.bit), [`bitstream/zynq_hybrid_soc.xsa`](../bitstream/zynq_hybrid_soc.xsa)

> **Zynq Architecture Features:**  
> This top connects the Coprocessor to the onboard dual-core ARM Cortex-A9 via an AXI Mailbox and DMA engine, while PicoRV32 manages local accelerator orchestration.

| Instance | Module | Total LUTs | Logic LUTs | LUTRAM / SRL | FFs | RAMB36 | RAMB18 | DSP48E1 |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `zynq_hybrid_bd_wrapper` | *(top block design)* | **3,491** | **3,317** | **88 / 86** | **2,803** | **9** | **6** | **18** |
| ├── `inst` (`pl_hybrid_soc`) | *hybrid pl soc* | 3,104 | 2,988 | 88 / 28 | 2,298 | 9 | 6 | 18 |
| │&nbsp;&nbsp;&nbsp;├── `u_mlkem` | `mlkem_dma_coproc_top` | **1,319** | 1,291 | 0 / 28 | **1,202** | 0 | 6 | 18 |
| │&nbsp;&nbsp;&nbsp;│&nbsp;&nbsp;&nbsp;├── `u_poly_mul_core` | `poly_multiplier` | 1,040 | 1,012 | 0 / 28 | 846 | 0 | 6 | 18 |
| │&nbsp;&nbsp;&nbsp;│&nbsp;&nbsp;&nbsp;├── `u_dma` | `ntt_dma` | 129 | 129 | 0 / 0 | 142 | 0 | 0 | 0 |
| │&nbsp;&nbsp;&nbsp;│&nbsp;&nbsp;&nbsp;├── `u_axi_slave` | `axi_lite_coprocessor` | 105 | 105 | 0 / 0 | 95 | 0 | 0 | 0 |
| │&nbsp;&nbsp;&nbsp;│&nbsp;&nbsp;&nbsp;└── `u_int_ctrl` | `interrupt_ctrl` | 6 | 6 | 0 / 0 | 2 | 0 | 0 | 0 |
| │&nbsp;&nbsp;&nbsp;├── `u_cpu` | `picorv32_axi` | 1,020 | 932 | 88 / 0 | 526 | 0 | 0 | 0 |
| │&nbsp;&nbsp;&nbsp;├── `u_arbiter` | `axi_arbiter_2m` | 370 | 370 | 0 / 0 | 8 | 0 | 0 | 0 |
| │&nbsp;&nbsp;&nbsp;├── `u_mailbox` | `axi_mailbox` | 189 | 189 | 0 / 0 | 281 | 1 | 0 | 0 |
| │&nbsp;&nbsp;&nbsp;├── `u_demux` | `axi_demux_4s` | 108 | 108 | 0 / 0 | 9 | 0 | 0 | 0 |
| │&nbsp;&nbsp;&nbsp;└── Glue & CPU BRAM | *(soc logic)* | 5 | 5 | 0 / 0 | 141 | 8 | 0 | 0 |
| └── Interconnect & BD logic | *axi_interconnect* | 387 | 329 | 0 / 58 | 505 | 0 | 0 | 0 |

---

## 4. Timing Closure & Slack Summary (Post-Route)

Timing analysis is verified across all three post-route design checkpoints at the **100.0 MHz** target clock constraint ($T_{\text{clk}} = 10.000\text{ ns}$):

| Design Checkpoint | Clock Domain | Setup WNS | Hold WHS | Pulse WPWS | $T_{\min}$ | Achieved $F_{\max}$ | Failing Endpoints | Status | Report Reference |
|---|---|---:|---:|---:|---:|---:|:---:|:---:|---|
| **Coprocessor OOC (`mlkem_coprocessor_top`)** | `s_axi_aclk` | **+0.822 ns** | **+0.015 ns** | **+4.020 ns** | 9.178 ns | **108.96 MHz** | 0 / 1,915 | **MET** | [`impl_timing_summary.rpt`](../results/timing/impl_timing_summary.rpt) |
| **Standalone PL SoC (`soc_top` w/ ILA)** | `clk_100m` | **+0.537 ns** | **+0.010 ns** | **+3.750 ns** | 9.463 ns | **105.67 MHz** | 0 / 10,661 | **MET** | [`soc_top_timing.rpt`](../results/timing/soc_top_timing.rpt) |
| **Zynq Hybrid SoC (`zynq_hybrid_soc`)** | `clk_fpga_0` | **+0.576 ns** | **+0.031 ns** | **+3.750 ns** | 9.424 ns | **106.11 MHz** | 0 / 8,461 | **MET** | [`zynq_hybrid_timing.rpt`](../results/timing/zynq_hybrid_timing.rpt) |

---

## 5. Execution Cycles & RISC-V Hardware Speedup

### 5.1 Cycle Count Breakdown for Complete Polynomial Multiplication ($f \cdot g$)

The complete hardware polynomial multiplication sequence takes **6,677 clock cycles** (66.77 µs @ 100 MHz). The table below breaks down the exact cycle count by FSM state from [`rtl/ntt/poly_multiplier.v`](../rtl/ntt/poly_multiplier.v):

| Phase / FSM State | Submodule / Operation | Hardware Cycles | Cumulative Cycles | Latency @ 100 MHz | Details |
|---|---|---:|---:|---:|---|
| `PM_COPY_F` | BRAM Load $f \to \text{work\_bram}$ | **768** | 768 | 7.68 µs | 256 words × 3-cycle read/write handshake |
| `PM_NTT_F` | 7-layer CT Forward NTT on $f$ | **940** | 1,708 | 9.40 µs | `1 + 7×128 + 6×6 + 6 + 1` cycles |
| `PM_SAVE_TF` | BRAM Copy $\hat{f} \to \text{temp\_bram}$ | **768** | 2,476 | 7.68 µs | 256 words × 3-cycle transfer |
| `PM_COPY_G` | BRAM Load $g \to \text{work\_bram}$ | **768** | 3,244 | 7.68 µs | 256 words × 3-cycle transfer |
| `PM_NTT_G` | 7-layer CT Forward NTT on $g$ | **940** | 4,184 | 9.40 µs | `1 + 7×128 + 6×6 + 6 + 1` cycles |
| `PM_BASEMUL` | Pointwise Base Multiplication | **1,536** | 5,720 | 15.36 µs | 128 degree-1 multiplications (12 cycles/pair) |
| `PM_INTT` | 7-layer GS Inverse NTT + Scaling | **943** | 6,663 | 9.43 µs | `1 + 7×128 + 6×6 + 9 + 1` (embedded scale) |
| FSM Handshake | Drain & `core_done` assertion | **14** | **6,677** | 0.14 µs | State transitions & latching |
| **Total Sequence** | **`poly_multiplier` datapath** | **6,677** | **6,677** | **66.77 µs** | **Bit-exact match against NIST FIPS 203** |

### 5.2 Performance vs. Pure Software Baseline

| Operation | HW Cycles (100 MHz) | HW Latency | RISC-V RV32 SW Baseline | Speedup |
|---|---|---|---|---|
| **Forward NTT (7 layers)** | **940 cycles** ($\le 1,000$ req. ✅) | **$9.40\ \mu\text{s}$** | ~95,000 cycles | **101.1x** |
| **Inverse NTT + Scaling** | **943 cycles** ($\le 1,000$ req. ✅) | **$9.43\ \mu\text{s}$** | ~110,000 cycles | **116.7x** |
| **Base Multiplication (128 pairs)** | **1,536 cycles** | **$15.36\ \mu\text{s}$** | ~45,000 cycles | **29.3x** |
| **Full Polynomial Multiplication (End-to-End)** | **6,677 cycles** | **$66.77\ \mu\text{s}$** | **~280,000 cycles** | **~41.9x** |

*Embedded Scaling Architecture:* The $n^{-1} = 3303$ multiplication is folded directly into the last INTT layer's write-back pipeline using two additional `mod_mul` units (`u_scale_lo_mul`, `u_scale_hi_mul`). A 3-stage scale write-back shift register (`sc_wb_pipe`) gates the scaled coefficients into the scratch BRAM exactly 3 cycles after the last butterfly fires. This eliminates the former sequential 256-cycle scaling pass (S_SCALE + S_SCALE_DRAIN states), reducing INTT from 1,207 cycles to 943 cycles — a **264-cycle saving** with no correctness trade-off (all 256 NIST reference coefficients match bit-exactly).

---

## 6. Formal Verification Properties & Results

### NuSMV 2.6.0 Model Checking

File: [`formal/nusmv/ntt_addr_gen.smv`](../formal/nusmv/ntt_addr_gen.smv)

| Property Specification | Formal Logic | Target Requirement | NuSMV Result |
|---|---|---|---|
| `AG (state = ACTIVE -> !(addr_lo = addr_hi))` | CTL Safety | Dual-port RAM write address collision freedom | **TRUE** |
| `AG (layer_idx <= 6)` | CTL Invariant | Layer index strictly bounded in $[0, 6]$ | **TRUE** |
| `AG (tw_addr >= 1 & tw_addr <= 127)` | CTL Invariant | Twiddle ROM index strictly bounded in $[1, 127]$ | **TRUE** |
| `AG (state = ACTIVE -> AF (state = DONE))` | CTL Liveness | Active NTT transform always terminates in DONE | **TRUE** |
| `G (state = ACTIVE -> !(addr_lo = addr_hi))` | LTL Safety | Linear temporal address disjointness | **TRUE** |

### SymbiYosys Formal Proofs

Files: [`formal/symbiyosys/bram_no_collision.sby`](../formal/symbiyosys/bram_no_collision.sby), [`formal/symbiyosys/bram_no_collision.v`](../formal/symbiyosys/bram_no_collision.v)

- **`bmc` Task:** Proved up to depth 30 using Z3 SMT engine that $addra \ne addrb$ holds unconditionally whenever $wea \land web = 1$. Result: **PASS** (`rc=0`, 0 assertion failures).
- **`prove` Task (Temporal $k$-Induction):** Unbounded proof across all steps via $k$-induction in Z3. Result: **PASS** (`rc=0`, successful proof by $k$-induction).
- **`bug_inject` Task:** Evaluated with an intentionally injected address collision on layer 0 (`addr_hi <= addr_lo`). The formal engine detected the violation at **step 5** and dumped a counterexample VCD trace (`trace.vcd`) and Verilog testbench (`trace_tb.v`). Result: **PASS (FAIL as expected)**.

---

## 7. Vitis HLS High-Level Synthesis Trade-off Study

Target device: `xc7z010clg400-1`  
Clock: 10.0 ns (100 MHz)  
Tool: Vitis HLS 2024.2  
Files: [`hls/butterfly.cpp`](../hls/butterfly.cpp), [`hls/run_hls.tcl`](../hls/run_hls.tcl)

| Design Metric | HLS Variant 1 (Area-Optimized) | HLS Variant 2 (Latency-Optimized) | Hand-Written RTL (`butterfly.v` Routed OOC) | Hand-Written RTL (Inside `u_ntt` Routed) |
|---|---|---|---|---|
| **Allocation Pragma** | `mod_mul limit=1` | `mod_mul limit=2` | Dual-mode CT/GS with Chiu & Parhi | Unified in-core datapath |
| **DSP48E1 Count** | **3** | **6** | **4** (2 FW + 2 GS lanes) | **4** |
| **Slice LUTs** | 167 (142 Logic / 25 SRL) | 179 (146 Logic / 33 SRL) | **209** (209 Logic / 0 SRL) | **269** (268 Logic / 1 SRL) |
| **Slice Registers (FF)** | 96 | 71 | **154** | **152** |
| **Latency (Cycles)** | 8 cycles | 7 cycles | **4 cycles** | **4 cycles** |
| **Initiation Interval (II)** | 1 | 1 | **1** | **1** |
| **Achieved $F_{\max}$** | 182.92 MHz (5.467 ns) | 181.39 MHz (5.513 ns) | **148.65 MHz** (6.727 ns) | **108.96 MHz** (in core) |
| **ATP Metric ($\text{ATP}_{\text{PE}}$)** | 37.36 | 54.53 | **24.36** *(Pareto Best)* | 26.76 |

**Key Takeaway:** The hand-written RTL achieves the lowest latency (4 cycles vs 7–8 cycles in HLS) and the best Area-Time Product ($\text{ATP}_{\text{PE}} = 24.36$ vs 37.36 / 54.53 in HLS). Chiu & Parhi shift-add constant reduction computes $t \cdot q$ directly in FPGA slice carry logic (`t*3329 = (t<<11)+(t<<10)+(t<<8)+t`), saving 1 DSP per multiplier lane (2 DSPs/mul vs 3 DSPs in HLS). Detailed Pareto curve plots are available in [`docs/comparison.md`](comparison.md) and [`docs/area_latency_plot.png`](area_latency_plot.png).
