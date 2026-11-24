set_param general.maxThreads 8

# Directory Resolution
set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR   [file normalize "$SCRIPT_DIR/.."]
cd $PROJ_DIR

# Configuration Parameters
set PART       "xc7z010clg400-1"
set TOP_MODULE "poly_multiplier"
set CLK_PERIOD 10.000 ;# 100 MHz target constraint (10.0 ns)
set OUT_DIR    "results/fsm_exploration"

file mkdir $OUT_DIR

# RTL Source Files
set RTL_FILES [list \
    "rtl/arithmetic/mod_add.v" \
    "rtl/arithmetic/mod_sub.v" \
    "rtl/arithmetic/mod_mul.v" \
    "rtl/arithmetic/basemul.v" \
    "rtl/butterfly/butterfly.v" \
    "rtl/memory/poly_bram.v" \
    "rtl/memory/twiddle_rom.v" \
    "rtl/ntt/ntt_addr_gen.v" \
    "rtl/ntt/ntt_engine.v" \
    "rtl/ntt/poly_multiplier.v" \
]

# Supported FSM Encoding Styles in AMD Vivado Synthesis:
# 1. sequential : Standard binary sequential encoding (0, 1, 2, ...)
# 2. one_hot    : 1 flip-flop per state (minimal decode logic, high Fmax)
# 3. gray       : Minimum bit change between consecutive states
# 4. johnson    : Johnson counter encoding
# 5. auto       : Vivado default heuristic selection
# 6. none       : Preserves the exact state encoding written in RTL source
set ENCODINGS [list "sequential" "one_hot" "gray" "johnson" "auto" "none"]

puts "================================================================="
puts " STARTING AUTOMATED FSM ENCODING BENCHMARK"
puts " Target Device : $PART"
puts " Top Module    : $TOP_MODULE"
puts " Clock Period  : ${CLK_PERIOD} ns (100.0 MHz)"
puts " Encodings     : $ENCODINGS"
puts " Output Dir    : $OUT_DIR"
puts "================================================================="

foreach enc $ENCODINGS {
    puts "\n>>> Processing FSM Encoding: \[$enc\] ..."
    
    # In-memory clean project per iteration
    create_project -in_memory -part $PART
    read_verilog -sv $RTL_FILES
    
    # Run Synthesis with explicit FSM extraction setting
    if {$enc == "none"} {
        synth_design -top $TOP_MODULE -part $PART -mode out_of_context -fsm_extraction off
    } else {
        synth_design -top $TOP_MODULE -part $PART -mode out_of_context -fsm_extraction $enc
    }
    
    # Apply 100 MHz clock constraint for out-of-context timing closure
    create_clock -period $CLK_PERIOD -name clk [get_ports clk]
    
    # Run Physical Implementation Steps
    opt_design
    place_design
    route_design
    
    # Generate Output Reports
    set util_rpt     "$OUT_DIR/util_${enc}.rpt"
    set util_hier    "$OUT_DIR/util_hier_${enc}.rpt"
    set timing_rpt   "$OUT_DIR/timing_${enc}.rpt"
    
    report_utilization -file $util_rpt
    report_utilization -hierarchical -file $util_hier
    report_timing_summary -file $timing_rpt -max_paths 10
    
    puts ">>> Finished: $enc -> Generated $util_rpt, $timing_rpt"
    close_project
}

puts "\n================================================================="
puts " ALL FSM ENCODING SYNTHESIS RUNS COMPLETED SUCCESSFULLY!"
puts " Reports are available in: $OUT_DIR"
puts "================================================================="
exit
