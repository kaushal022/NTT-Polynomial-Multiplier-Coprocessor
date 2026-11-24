# ML-KEM NTT Coprocessor — Metrics, Area–Latency Plot, Performance, Energy & Literature Comparison

**Target Device:** Digilent Zybo Z7-10 (`xc7z010clg400-1`)  
**Clock Constraint:** 100.0 MHz ($T_{\text{clk}} = 10.000\text{ ns}$)  
**Standard:** NIST FIPS 203 (ML-KEM / Kyber, $q = 3329$, $n = 256$)  
**Tooling:** AMD/Xilinx Vivado 2024.2 (Post-Route Checkpoints), Vitis HLS 2024.2, Vivado XSim 2024.2, SymbiYosys + Z3, NuSMV 2.6.0  
**Deliverable Plot:** [`area_latency_plot.png`](area_latency_plot.png) · [Vector SVG](area_latency_plot.svg) · Regenerated via [`plot_area_latency.py`](../scripts/plot_area_latency.py)

---

## 1. Execution Cycles & Latency Summary

| Operation | Hardware Scope | Clock Cycles | Latency @ 100 MHz | Latency @ Core $F_{\max}$ (108.96 MHz) | Verification Source |
|---|---|---:|---:|---:|---|
| **Forward NTT (7 layers)** | `ntt_engine` | **940** | **9.400 µs** | **8.627 µs** | [`ntt_engine.v`](../rtl/ntt/ntt_engine.v) FSM (`1 + 7×128 + 6×6 + 6 + 1`) |
| **Inverse NTT + Embedded Scale** | `ntt_engine` | **943** | **9.430 µs** | **8.655 µs** | [`ntt_engine.v`](../rtl/ntt/ntt_engine.v) FSM (`1 + 7×128 + 6×6 + 9 + 1`) |
| **Full Polynomial Multiplication ($f \cdot g$)** | `poly_multiplier` | **6,677** | **66.770 µs** | **61.282 µs** | Live XSim (`tb_poly_multiplier_sim`, bit-exact) |
| **Full PolyMul @ SoC $F_{\max}$** | `soc_top` (`clk_100m`) | **6,677** | 66.770 µs | **63.187 µs** (@ 105.67 MHz) | `soc_top_timing.rpt` + `tb_poly_multiplier` |
| **Full PolyMul @ Hybrid $F_{\max}$** | `zynq_hybrid_soc` (`clk_fpga_0`) | **6,677** | 66.770 µs | **62.924 µs** (@ 106.11 MHz) | `zynq_hybrid_timing.rpt` + `tb_poly_multiplier` |

*Software Baseline Reference:* Pure RV32 C reference estimates `~280,000` cycles for full polynomial multiplication ([`VERIFICATION_REPORT.md`](VERIFICATION_REPORT.md), [`sw_ntt_benchmark.c`](../software/software_benchmark/sw_ntt_benchmark.c)), yielding a core hardware speedup of **~41.9×** (`~280,000 / 6,677`) over pure software (`~101×` Fwd NTT, `~117×` INTT per `VERIFICATION_REPORT.md`). *(Note: Pure C execution inside `soc_top` was not separately benchmarked over UART here.)*

---

## 2. Post-Route FPGA Resource Utilization & Area Overhead

### 2.1 Routed Hierarchy Breakdown (`results/synthesis/impl_utilization_hierarchical.rpt` & `soc_top`)

> **Important Exclusion of Debug Probes:** The bitstream build of `soc_top` includes Vivado's Integrated Logic Analyzer (`u_ila_0`: 1,135 LUTs, 1,718 FFs, 1 RAMB36, 1 RAMB18) and JTAG hub (`dbg_hub`: 448 LUTs, 741 FFs, 24 LUTRAMs), totaling **1,583 LUTs, 2,459 FFs, and 2 BRAMs** of non-functional debug logic. True **Functional SoC** overhead excludes `u_ila_0` and `dbg_hub`.

| Module / Scope | Slice LUTs | Logic LUTs | LUTRAM / SRL | Flip-Flops (FF) | RAMB36 | RAMB18 | 36Kb BRAM Eq. | DSP48E1 | Occupied Slices |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **`mlkem_coprocessor_top` (OOC Routed)** | **1,105** | 1,077 | 0 / 28 | **961** | 0 | **6** | **3.0** | **18** | **387** (8.80%) |
| ├── `u_axi_slave` (`axi_lite_coprocessor`) | 59 | 59 | 0 / 0 | 95 | 0 | 0 | 0.0 | 0 | — |
| └── `u_poly_mul_core` (`poly_multiplier`) | 1,047 | 1,019 | 0 / 28 | 848 | 0 | 6 | 3.0 | 18 | — |
| &nbsp;&nbsp;&nbsp;&nbsp;├── `u_ntt` (`ntt_engine`) | 584 | 573 | 0 / 11 | 398 | 0 | 2 | 1.0 | 8 | — |
| &nbsp;&nbsp;&nbsp;&nbsp;│&nbsp;&nbsp;&nbsp;└── `u_butterfly` (`butterfly`) | 269 | 268 | 0 / 1 | 152 | 0 | 0 | 0.0 | 4 | — |
| &nbsp;&nbsp;&nbsp;&nbsp;└── `u_basemul` (`basemul`) | 346 | 329 | 0 / 17 | 217 | 0 | 0 | 0.0 | 10 | — |
| **`u_mlkem` (Inside Routed `soc_top`)** | **1,101** | 1,073 | 0 / 28 | **955** | 0 | **6** | **3.0** | **18** | — |
| `u_cpu` (`picorv32_axi`) | 1,132 | 1,044 | 88 / 0 | 624 | 0 | 0 | 0.0 | 0 | — |
| `u_demux` (`axi_demux`) | 68 | 68 | 0 / 0 | 7 | 0 | 0 | 0.0 | 0 | — |
| `u_uart` (`simpleuart`) | 93 | 93 | 0 / 0 | 131 | 0 | 0 | 0.0 | 0 | — |
| `(soc_top)` glue + 32 KB BRAM | 111 | 111 | 0 / 0 | 140 | 8 | 0 | 8.0 | 0 | — |
| **Baseline SoC (No Coprocessor, No ILA)** | **1,404** | — | — | **902** | 8 | 0 | **8.0** | **0** | — |
| **Functional SoC Total (No ILA)** | **2,504** | 2,389 | 88 / 28 | **1,857** | 8 | 6 | **11.0** | **18** | — |
| **Debug Probes (`u_ila_0` + `dbg_hub`)** | 1,583 | 1,408 | 24 / 151 | 2,459 | 1 | 1 | 1.5 | 0 | — |
| **Full Debug `soc_top` (Routed w/ ILA)** | **4,087** | 3,796 | 112 / 179 | **4,316** | 9 | 7 | **12.5** | **18** | — |

*(Note: Cross-hierarchy LUT combining causes sub-module sums to differ slightly from top totals; FFs inside `soc_top` match identically: `140 + 624 + 7 + 131 + 955 = 1,857`.)*

### 2.2 Area Overhead Formulas & Results

$$\text{Incremental Overhead (\%)} = \frac{\text{Area}_{\text{accel}}}{\text{Area}_{\text{SoC\_baseline}}} \times 100 \qquad\qquad \text{SoC Area Share (\%)} = \frac{\text{Area}_{\text{accel}}}{\text{Area}_{\text{SoC\_func}}} \times 100$$

| Resource Metric | Incremental Overhead vs Baseline SoC (`u_mlkem / 1,404 LUTs ...`) | Functional SoC Share (`u_mlkem / 2,504 LUTs ...`) | Zynq-7010 (`xc7z010`) Device Utilization (OOC) |
|---|---:|---:|---:|
| **Slice LUTs** | **+78.35%** (`1,100 / 1,404`) | **43.93%** (`1,100 / 2,504`) | **6.28%** (`1,105 / 17,600`) |
| **Flip-Flops (FF)** | **+105.88%** (`955 / 902`) | **51.43%** (`955 / 1,857`) | **2.73%** (`961 / 35,200`) |
| **BRAM (36Kb tiles)** | **+37.50%** (`3.0 / 8.0`) | **27.27%** (`3.0 / 11.0`) | **5.00%** (`6 / 120` RAMB18) |
| **DSP48E1** | N/A (`0 → 18`) | **100.00%** (`18 / 18`) | **22.50%** (`18 / 80`) |

---

## 3. Maximum Operating Frequency ($F_{\max}$)

$$T_{\min}\ [\text{ns}] = T_{\text{clk}} - \text{WNS}, \qquad F_{\max}\ [\text{MHz}] = \frac{1000}{T_{\min}\ [\text{ns}]}$$

| Design Scope | Clock Domain | Target Period $T_{\text{clk}}$ | Setup WNS | Hold WHS | Pulse WPWS | $T_{\min}$ | Achieved $F_{\max}$ | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| **Coprocessor OOC (`mlkem_coprocessor_top`)** | `s_axi_aclk` | 10.000 ns | **+0.822 ns** | **+0.015 ns** | +4.020 ns | 9.178 ns | **108.96 MHz** | **0 failing endpoints** across all 1,915 setup & 1,915 hold checks |
| **Full SoC (`soc_top`, w/ ILA)** | `clk_100m` | 10.000 ns | **+0.537 ns** | **+0.010 ns** | +3.750 ns | 9.463 ns | **105.67 MHz** | **0 failing endpoints** across all 10,661 setup & 10,645 hold checks |
| **Zynq Hybrid SoC (`zynq_hybrid_soc`)** | `clk_fpga_0` | 10.000 ns | **+0.576 ns** | **+0.031 ns** | +3.750 ns | 9.424 ns | **106.11 MHz** | **0 failing endpoints** across all 8,461 setup & 8,461 hold checks |
| **HLS FSMD Var 1 (`mod_mul limit=1`, OOC)** | `ap_clk` | 10.000 ns | **+4.533 ns** | **+0.029 ns** | +4.020 ns | 5.467 ns | **182.92 MHz** | Vivado 2024.2 post-route OOC (`8` cyc, II=1; Vitis `csynth` est. 6.540 ns / 152.91 MHz) |
| **HLS FSMD Var 2 (`mod_mul limit=2`, OOC)** | `ap_clk` | 10.000 ns | **+4.487 ns** | **+0.083 ns** | +4.020 ns | 5.513 ns | **181.39 MHz** | Vivado 2024.2 post-route OOC (`7` cyc, II=1; Vitis `csynth` est. 6.540 ns / 152.91 MHz) |
| **Paper-Enhanced RTL Butterfly (`butterfly.v`, OOC)** | `clk` | 10.000 ns | **+3.273 ns** | **+0.014 ns** | +4.500 ns | 6.727 ns | **148.65 MHz** | Vivado 2024.2 post-route OOC (`4` cyc, II=1; Chiu & Parhi shift-add Barrett) |

---

## 4. Area–Time (AT / ADP) & Area–Latency Design Space Deliverables

### 4.1 Definitions

$$T_{\text{exec}}\ [\mu\text{s}] = \frac{\text{Cycles}}{f_{\text{clk}}\ [\text{MHz}]}, \qquad \text{AT (or ADP)} = \text{Area} \times T_{\text{exec}}\ [\mu\text{s}]$$

Following **Liu et al. (IEEE TVLSI 2024)** Table I, FPGA Weighted Area ($W_{\text{area}}$) and Weighted Area–Time Product ($\text{ATP}_{wei}$) combine LUTs, DSPs, and 36Kb BRAMs:

$$W_{\text{area}} = \text{LUT} + 100 \times \text{DSP} + 300 \times \text{BRAM}_{36}, \qquad \text{ATP}_{wei} = \frac{W_{\text{area}} \times T_{\text{exec}}\ [\mu\text{s}]}{1000}$$

*(For single butterfly units in [`area_latency_plot.png`](area_latency_plot.png) Panels (a) and (c), where latency is measured in ns, $\text{ATP}_{\text{PE}} = W_{\text{area}} \times T_{\text{exec}}[\text{ns}] / 1000 = W_{\text{area}} \times T_{\text{exec}}[\mu\text{s}]$.)*

### 4.2 Area–Latency Plot: Two FSMD Points + Paper-Enhanced Design

![Area–Latency Design Space: Two HLS FSMD Points vs. Paper-Enhanced RTL](area_latency_plot.png)

*Regenerate anytime from the repository root with `python scripts/plot_area_latency.py` (outputs [`area_latency_plot.png`](area_latency_plot.png) and [`area_latency_plot.svg`](area_latency_plot.svg)).*

### 4.3 Butterfly Processing Element (PE): HLS FSMD Schedule/Binding vs. Paper-Enhanced RTL

Every row below compares the two Vitis HLS 2024.2 FSMD butterfly schedules (`VARIANT=1` sharing 1 `mod_mul`, `VARIANT=2` binding 2 `mod_mul` instances in [`butterfly.cpp`](../hls/butterfly.cpp)) against our hand-written RTL [`butterfly.v`](../rtl/butterfly/butterfly.v) under identical **Vivado 2024.2 Out-of-Context (OOC) Place-and-Route (`xc7z010clg400-1`, `100.0 MHz`)**:

| Butterfly Point | Source / Methodology | Slice LUTs (Logic / SRL) | FFs | Slices | DSP48E1 | $W_{\text{area}}$ | Cycles ($II$) | Latency @ 100 MHz | $F_{\max}$ (MHz) | Min Lat. @ $F_{\max}$ | Dyn. Power (@100M) | $\text{ATP}_{\text{PE}}$ (@100M / @$F_{\max}$) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **HLS FSMD Var 1** (`limit=1`) | Vitis HLS `csynth` Est. | 428 | 521 | — | **3** | 728 | 8 (1) | 80.0 ns | 152.91 | 52.32 ns | — | 58.24 / 38.09 |
| **HLS FSMD Var 1** (`limit=1`) | **Vivado OOC Routed** | **167** (142 / 25) | **96** | **58** | **3** | **467** | **8** (1) | **80.0 ns** | **182.92** | **43.74 ns** | **8 mW** | **37.36** / **20.42** *(Pareto)* |
| **HLS FSMD Var 2** (`limit=2`) | Vitis HLS `csynth` Est. | 538 | 563 | — | **6** | 1,138 | 7 (1) | 70.0 ns | 152.91 | 45.78 ns | — | 79.66 / 52.10 |
| **HLS FSMD Var 2** (`limit=2`) | **Vivado OOC Routed** | **179** (146 / 33) | **71** | **58** | **6** | **779** | **7** (1) | **70.0 ns** | **181.39** | **38.59 ns** | **11 mW** | **54.53** / **30.06** *(Dominated)* |
| **Paper-Enhanced RTL** | **Vivado OOC Routed** (`butterfly.v`) | **209** (209 / 0) | **154** | **71** | **4** | **609** | **4** (1) | **40.0 ns** | **148.65** | **26.91 ns** | **10 mW** | **24.36** / **16.39** *(Pareto Best)* |
| **Paper-Enhanced RTL (in Core)** | `u_butterfly` inside `u_ntt` | 269 (268 / 1) | 152 | — | 4 | 669 | 4 (1) | 40.0 ns | 108.96 | 36.71 ns | — | 26.76 / 24.56 |

**Key Engineering Takeaways from OOC Measurements:**
1. **Chiu & Parhi Shift-Add Barrett Beats Dual-Multiplier HLS Var 2 on Every Primary Objective:** Replacing the generic 3-DSP `mod_mul` in `butterfly.cpp` with shift-add constant reduction (`t * 3329 = (t<<11)+(t<<10)+(t<<8)+t`) in [`mod_mul.v`](../rtl/arithmetic/mod_mul.v) cuts butterfly pipeline depth from **7–8 cycles to 4 cycles** (`-42.9%` vs Var 2, `-50.0%` vs Var 1), reduces dual-lane DSP count from **6 DSPs → 4 DSPs (`-33.3%`)**, shrinks weighted area by **`-21.8%`** (`609` vs `779`), and lowers Weighted $\text{ATP}_{\text{PE}}$ by **`-55.3%` @ 100 MHz (`24.36` vs `54.53`)** and **`-45.5%` @ $F_{\max}$ (`16.39` vs `30.06`)**.
2. **Shift-Add LUT Trade-Off & True Pareto Frontier:** Because Chiu & Parhi computes $t \cdot q$ in slice carry chains instead of a 3rd DSP48E1 per lane, OOC slice LUTs rise modestly (`209` vs `167`/`179`) and $F_{\max}$ is `148.65 MHz` vs `181.39–182.92 MHz`. Yet even at peak achievable clock frequency, `4 × 6.727 ns = 26.91 ns` still beats HLS Var 1 (`43.74 ns`, `-38.5%`) and Var 2 (`38.59 ns`, `-30.3%`), leaving **HLS Var 1** (`467` weighted area, `80 ns`) and **Paper-Enhanced RTL** (`609` weighted area, `40 ns`) as the two Pareto-optimal points while **HLS Var 2** is strictly dominated.
3. **Why Vitis HLS `csynth` Estimates Differ from Vivado Post-Route:** Vivado packs HLS's 6–8 cycle delay lines (`mode_read`, `a_read`, `sum_1`) into **25–33 `SRL16E`** shift-register LUTs and absorbs operand pipeline registers into `DSP48E1` internal `AREG`/`BREG`/`MREG`/`PREG` stages, compressing `428/538` estimated LUTs down to `167/179` routed LUTs (`3/6` DSPs unchanged).

### 4.4 7-Layer NTT & Full Coprocessor Area–Time Results

| Configuration & Operation | Basis | LUT / DSP / BRAM36 | $W_{\text{area}}$ | Cycles | Latency ($\mu\text{s}$) | $\text{AT}_{\text{LUT}}$ ($\text{LUT}\cdot\mu\text{s}$) | $\text{ATP}_{wei}$ (36K-eq / 18K) |
|---|---|---|---:|---:|---:|---:|---:|
| **Initial Sequential FSM (`Progress 1.pdf`)** | Documented Baseline | — | — | **~7,200 / ~7,900** | 72.0 / 79.0 @ 100M | — | — |
| **Non-Pipelined FSMD Proj. (Var 1 / Var 2)** | Analytical $896\cdot(2+L_{\text{bfly}})$ | — | — | **8,960 / 8,064** | 89.60 / 80.64 @ 100M | — | — |
| **Pre-Scale Pipelined `v2` (Separate $/n$ Pass)** | Documented Pre-Opt | — | — | **947 Fwd / 1,207 INTT** | 9.47 / 12.07 @ 100M | — | — |
| **Analytical Pipelined `ntt` + FSMD Var 1** | `ntt_engine` ($912+7L$) + OOC Var 1 | `482 / 7 / 1.0` | **1,482** | **968 Fwd / 971 INTT** | 9.68 / 9.71 @ 100M | **4,665.8** | **14.35** / 17.25 |
| **Analytical Pipelined `ntt` + FSMD Var 2** | `ntt_engine` ($912+7L$) + OOC Var 2 | `494 / 10 / 1.0` | **1,794** | **961 Fwd / 964 INTT** | 9.61 / 9.64 @ 100M | **4,747.3** | **17.24** / 20.13 |
| **`u_ntt` Paper-Enhanced — Fwd NTT** | **Measured Routed** (@ 100 MHz) | `584 / 8 / 1.0` | **1,684** | **940** | **9.400** | **5,489.6** | **15.83** / 18.65 |
| **`u_ntt` Paper-Enhanced — Fwd NTT** | **Measured Routed** (@ 108.96 MHz) | `584 / 8 / 1.0` | **1,684** | **940** | **8.627** | **5,038.4** | **14.53** / 17.12 |
| **`u_ntt` Paper-Enhanced — INTT + Embed Scale** | **Measured Routed** (@ 100 MHz) | `584 / 8 / 1.0` | **1,684** | **943** (`-21.9%` vs v2) | **9.430** | **5,507.1** | **15.88** / 18.71 |
| **`u_ntt` Paper-Enhanced — INTT + Embed Scale** | **Measured Routed** (@ 108.96 MHz) | `584 / 8 / 1.0` | **1,684** | **943** | **8.655** | **5,054.4** | **14.57** / 17.17 |
| **Full Coprocessor (`mlkem_coprocessor_top`) — Fwd NTT** | **Measured Routed** (@ 100 / 108.96 MHz) | `1,105 / 18 / 3.0` | **3,805** | **940** | 9.400 / 8.627 | 10,387.0 / 9,533.2 | **35.77** / **32.83** (@Fmax 36K) |
| **Full Coprocessor — Complete PolyMul ($f\cdot g$)** | **Measured Routed** (@ 100.0 MHz) | `1,105 / 18 / 3.0` | **3,805** | **6,677** | **66.770** | **73,780.8** | **254.06** / 314.15 |
| **Full Coprocessor — Complete PolyMul ($f\cdot g$)** | **Measured Routed** (@ 108.96 MHz) | `1,105 / 18 / 3.0` | **3,805** | **6,677** | **61.282** | **67,716.1** | **233.18** / 288.33 |
| **Full SoC `u_mlkem` — Complete PolyMul** | **Measured Routed** (@ 105.67 MHz) | `1,100 / 18 / 3.0` | **3,800** | **6,677** | **63.187** | **69,505.7** | **240.11** / 297.02 |
| **Zynq Hybrid SoC — Complete PolyMul** | **Measured Routed** (@ 106.11 MHz) | `3,491 / 18 / 12.0` | **8,891** | **6,677** | **62.924** | **220,103.5** | **559.50** / 679.28 |

---

## 5. Power & Energy Analysis

$$E\ [\mu\text{J}] = P\ [\text{W}] \times T_{\text{exec}}\ [\mu\text{s}] = \frac{P\ [\text{W}]}{f\ [\text{MHz}]} \times \text{Cycles}, \qquad E_{\text{cyc}}\ [\text{nJ/cycle}] = \frac{P\ [\text{mW}]}{f\ [\text{MHz}]}$$

From Vivado `report_power` (2024.2 vectorless propagation @ 100.0 MHz, Medium confidence — default switching activity without `.saif`):
* **Coprocessor OOC (`mlkem_coprocessor_routed.dcp`):** Dynamic = **39 mW** (`u_poly_mul_core = 38 mW`, of which `DSPs = 14 mW`, `Slice Logic = 9 mW`, `Signals = 8 mW`, `Clocks = 7 mW`), Device Static = **90 mW**, Total = **129 mW**.
* **Full SoC (`soc_top_routed.dcp`):** Dynamic = **177 mW** (`PLLE2_ADV = 109 mW`, `u_mlkem = 31 mW`, `u_ila_0 = 20 mW`, `dbg_hub = 3 mW`, `u_cpu = 8 mW`, `u_uart = 1 mW`), Device Static = **98 mW**, Total = **274 mW**.
  * Excluding `u_ila_0 + dbg_hub` (`23 mW`): **Functional SoC Dynamic = 154 mW**, **Functional SoC Total = 251 mW**.

| Power Scope (@ 100 MHz) | Power (mW) | Energy / Cycle (nJ/cyc) | Fwd NTT (940 cyc) | INTT + Scale (943 cyc) | Full PolyMul (6,677 cyc) |
|---|---:|---:|---:|---:|---:|
| **`u_mlkem` Dynamic (inside SoC)** | 31 mW | **0.31 nJ/cyc** | **0.291 µJ** | **0.292 µJ** | **2.070 µJ** |
| **Coprocessor OOC Dynamic** | 39 mW | **0.39 nJ/cyc** | **0.367 µJ** | **0.368 µJ** | **2.604 µJ** |
| **Coprocessor OOC Total (incl. 90 mW chip static)** | 129 mW | **1.29 nJ/cyc** | **1.213 µJ** | **1.216 µJ** | **8.613 µJ** |
| **Functional SoC Dynamic (No ILA, incl. 109 mW PLL)** | 154 mW | **1.54 nJ/cyc** | **1.448 µJ** | **1.452 µJ** | **10.283 µJ** |
| **Functional SoC Total (No ILA)** | 251 mW | **2.51 nJ/cyc** | **2.359 µJ** | **2.367 µJ** | **16.759 µJ** |
| **Full Debug Build SoC Total (w/ ILA)** | 274 mW | **2.74 nJ/cyc** | **2.576 µJ** | **2.584 µJ** | **18.295 µJ** |

---

## 6. Comparison Against Parent-Folder Research Papers

### 6.1 Summary Matrix

| Reference Paper | What Matches / Core Idea Used | Where Applied in Our Design | What Does **Not** Match / Not Reproduced |
|---|---|---|---|
| **Chiu & Parhi** (`10481206.pdf`, IEEE) | Shift-and-add Barrett reduction replacing constant $t \cdot q$ multiply; separate LUT/DSP/FF ADP metrics. | [`mod_mul.v`](../rtl/arithmetic/mod_mul.v#L41-L44): `(t<<11)+(t<<10)+(t<<8)+t` saves 1 DSP/mul (**2 DSPs** vs **3 DSPs** in HLS). | Flexible $k$-width RNS-CRT base conversion, 360/1440-bit FHE moduli ($n = 2^{13}..2^{15}$), coprime search, VCU118 platform. |
| **Dam et al.** (*MDPI Electronics* 2026, `Accelerating_Post-Quantum_...pdf`) | FIPS 203 ML-KEM ($q=3329, n=256$), CT/GS unified NTT order, Barrett butterfly, RISC-V SoC offloading, Energy/Throughput equations. | [`soc_top.v`](../rtl/soc/soc_top.v), [`butterfly.v`](../rtl/butterfly/butterfly.v), [`ntt_engine.v`](../rtl/ntt/ntt_engine.v). | **No match on CPU/Bus/Datapath/Tech:** Rocket `RV64IMAC` + RoCC custom instructions vs PicoRV32 `RV32I` + AXI4-Lite; Dual-BU + shift-register RU/FIFO (`448` core / `1,514` SoC CCs) vs 1-BU ping-pong BRAM (`940` CCs); `/2` per INTT stage vs Layer-6 `×3303`; Dam omits HW `basemul` (`6,677` CCs here); 180 nm CMOS ASIC (`297 kGE`, `118 MHz`, `307.9 mW`) vs Zynq-7000 FPGA. |
| **Liu et al.** (*IEEE TVLSI* 2024, `An_Area-Efficient_Conflict-Free_...pdf`) | Dual-mode CT/GS PE with Barrett reduction & pipeline balancing; folded post-processing ($n^{-1}$) without separate scaling pass; $\text{ATP}_{wei}$ metric. | [`butterfly.v`](../rtl/butterfly/butterfly.v), [`ntt_engine.v`](../rtl/ntt/ntt_engine.v#L206-L258) (`sc_wb_pipe` eliminates 256-cycle scale pass). | Constant-Geometry (CG) topology, 4-bank **$1.5N$** single-port mapping, multi-PE scaling ($L=1..64$), runtime-configurable degree/modulus, dynamic INTT twiddle negation (`-\omega`). |
| **Takala et al.** (`IV_524.pdf`, Tampere Univ.) | Conflict-free butterfly operand access problem (`addr_lo != addr_hi`). | Formally verified disjoint port writes (`wea && web => addra != addrb`) in [`ntt_addr_gen.v`](../rtl/ntt/ntt_addr_gen.v) & [`bram_no_collision.v`](../formal/symbiyosys/bram_no_collision.v). | **Technique not used:** Takala eliminates double-buffering across $Q=2^q$ banks via XOR matrix $m=Ta$ + bit rotation for parallel CG FFTs; our RTL uses $2N$ dual-port ping-pong BRAMs for 1 PE with arithmetic counters. |

### 6.2 Quantitative Snapshot vs. Dam et al. (2026) & Liu et al. (2024)

| Metric | **This Work (Zynq-7010 FPGA)** | **Dam et al. (2026) (Artix-7 / 180 nm ASIC)** | **Liu et al. (TVLSI 2024, Virtex-7 PE=1)** |
|---|---|---|---|
| **CPU & Bus** | PicoRV32 (`RV32I`), AXI4-Lite MMIO (`0x4000_0000`) | Rocket (`RV64IMAC`), RoCC + D-Cache | Standalone PE=1 NTT Engine (`N=256`, `lgp=13`) |
| **Clock Frequency ($F_{\max}$)** | **100 MHz** target (**105.67 MHz** SoC / **106.11 MHz** Hybrid / **108.96 MHz** core) | **118 MHz** (180 nm ASIC @ 2.0 V) | **335 MHz** (Virtex-7 peak) |
| **NTT Engine / Core Area (FPGA)** | `u_ntt`: **584 LUTs**, 398 FFs, **1 BRAM36** (2 RAMB18), **8 DSPs** (`1,684` $W_{\text{area}}$); Full Coproc: **1,105 LUTs**, 387 Slices, **3 BRAM36**, **18 DSPs** | **1,314 LUTs**, 1,012 FFs, 548 Slices, **1 BRAM**, **2 DSPs** (`1,814` $W_{\text{area}}$, NTT/INTT only) | **632 LUTs**, 402 FFs, **2.5 BRAM36**, **3 DSPs** (`1,682` $W_{\text{area}}$) |
| **Latency (Cycles)** | **940** (NTT), **943** (INTT+Scale), **6,677** (Full PolyMul) | **448** (core NTT), **1,514** (SoC NTT), **1,413** (SoC INTT) | **1,033** (NTT, `3.1 µs` @ 335 MHz / `10.33 µs` @ 100 MHz) |
| **Weighted $\text{ATP}_{wei}$ (`u_ntt` @ 100 MHz)** | **15.83** Fwd / **15.88** INTT (`14.53` @ 108.96 MHz) | **8.13** Core / **27.46** SoC NTT (@ 100 MHz norm.) | **17.38** (@ 100 MHz norm.) / **5.2** (@ 335 MHz peak) |
| **Energy / NTT** | **0.291 µJ** (`u_mlkem` dyn) / **2.359 µJ** (Func SoC total @ 100 MHz) | **3.95 µJ** (180 nm ASIC @ 307.9 mW / 118 MHz) | Not reported |
