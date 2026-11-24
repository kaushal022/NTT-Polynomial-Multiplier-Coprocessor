# Automated FSM State Encoding Exploration & Benchmarking Suite

This directory contains the synthesis and implementation results for the polynomial multiplier FSM orchestrator (`poly_multiplier.v`) across all standard encoding styles supported by AMD Vivado:

- **`sequential`**: Standard binary encoding ($0, 1, 2, \dots$).
- **`one_hot`**: 1 flip-flop per state (minimal decode logic, higher clock frequency).
- **`gray`**: Minimum Hamming distance between successive state transitions.
- **`johnson`**: Johnson counter encoding.
- **`auto`**: Vivado default synthesis heuristic.
- **`none`**: Preserves original state parameter encoding without extraction.

---

## Benchmark Scripts

1. **`scripts/run_fsm_synthesis.tcl`**:
   The Vivado TCL script that runs automated out-of-context synthesis, logic optimization, placement, routing, and timing sign-off for each encoding on the `xc7z010clg400-1` (Digilent Zybo Z7-10).

2. **`scripts/run_fsm_exploration.py`**:
   The Python driver that automatically invokes Vivado in batch mode, harvests all `.rpt` files, parses LUTs, FFs, DSPs, BRAMs, WNS, and computes $F_{\max}$, and exports:
   - `fsm_encoding_summary.csv`
   - `fsm_encoding_summary.md`
   - `fsm_encoding_summary.rpt`

3. **`scripts/run_fsm_benchmarks.bat`**:
   One-click Windows launcher for easy execution from command prompt or terminal.

---

## How to Run

### Run Full Synthesis & Implementation:
```cmd
python scripts/run_fsm_exploration.py
```
*(or run `scripts\run_fsm_benchmarks.bat`)*

### Re-harvest & Parse Existing Reports (Instant Summary):
```cmd
python scripts/run_fsm_exploration.py --parse-only
```

---

## Generated Report Files in `results/fsm_exploration/`:

- `util_<encoding>.rpt`: Post-route slice utilization report for `<encoding>`.
- `util_hier_<encoding>.rpt`: Hierarchical utilization report showing exact standalone top-level FSM utilization.
- `timing_<encoding>.rpt`: Post-route timing summary with WNS, WHS, and path delays.
- `fsm_encoding_summary.csv`: Machine-readable CSV data table.
- `fsm_encoding_summary.md`: Formatted Markdown table with engineering analysis.
- `fsm_encoding_summary.rpt`: Formatted plain-text summary report.
