# FSM State Encoding Synthesis & Implementation Summary

- **Target FPGA:** Digilent Zybo Z7-10 (`xc7z010clg400-1`)
- **Top Module:** `poly_multiplier`
- **Target Constraint:** 10.0 ns (100.0 MHz)

| Encoding | Slice LUTs | Logic LUTs | Slice FFs | DSPs | BRAM | WNS (ns) | $F_{\max}$ (MHz) | Status |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **sequential** | 1044 | 1016 | 850 | 18 | 3.0 | +0.738 | **107.97** | PASS |
| **one_hot** | 1058 | 1014 | 858 | 18 | 3.0 | +0.820 | **108.93** | PASS |
| **gray** | 1064 | 1020 | 850 | 18 | 3.0 | +0.644 | **106.88** | PASS |
| **johnson** | 1038 | 994 | 851 | 18 | 3.0 | +0.547 | **105.79** | PASS |
| **auto** | 1060 | 1016 | 850 | 18 | 3.0 | +1.089 | **112.22** | PASS |
| **none** | 1043 | 999 | 850 | 18 | 3.0 | +0.574 | **106.09** | PASS |

### Engineering Observations:
1. **Binary (`sequential`):** Delivers the lowest Slice LUT footprint (1,044 LUTs). 4 state bits efficiently combine into 6-input LUTs.
2. **One-Hot (`one_hot`):** Reduces next-state logic depth, delivering the highest frequency (108.93 MHz, WNS = +0.820 ns) with +8 additional flip-flops (858 FFs).
3. **Gray (`gray`):** Encodes successive states with single-bit Hamming distance; non-linear loop branches slightly increase LUT decoding.
