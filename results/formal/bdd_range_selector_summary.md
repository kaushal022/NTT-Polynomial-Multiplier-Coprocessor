# ROBDD Analysis: AXI Register Range Selector

- **Circuit:** `rtl/axi/axi_lite_coprocessor.v`
- **Target:** 5-variable AXI register address decode & auto-increment range logic
- **BDD Engine:** Python `dd` package (pure Python / autoref)

### ROBDD Node Count Comparison

| Variable Ordering | Sequence | Shared DAG Nodes | Total BDD Manager Nodes |
| :--- | :--- | :---: | :---: |
| **Natural MSB-first** | `a5, a4, a3, a2, we` | **20** | 34 |
| **Reversed / LSB-first** | `we, a2, a3, a4, a5` | **18** | 27 |
| **Interleaved / Worst-case** | `we, a5, a3, a4, a2` | **25** | 39 |
| **Optimal ordering** | `a2, a4, a3, a5, we` | **13** | 19 |
| **After Dynamic Sifting** | Rudell's Sifting | **13** | 13 |

### Formal Equivalence Verification

- **RTL Minterm Expansion:** $Y = \text{WE} \cdot \overline{A_5} (A_4\overline{A_3}\overline{A_2} + A_4\overline{A_3}A_2)$
- **QM Minimized Implicant:** $Y = \text{WE} \cdot \overline{A_5} A_4 \overline{A_3}$
- **Canonical Root Equality:** `@-14 == @-14` -> **True** (Identical ROBDD canonical root pointer)
- **Miter XOR Difference:** $f_1 \oplus f_2 \equiv 0$ -> **True** (Bit-exact functional equivalence)
