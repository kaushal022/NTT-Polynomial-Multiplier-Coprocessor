set_param general.maxThreads 8

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR   [file normalize "$SCRIPT_DIR/.."]
cd $PROJ_DIR

set PART "xc7z010clg400-1"
set TOP  "mlkem_coprocessor_top"

puts "=========================================================="
puts "Starting Out-of-Context Synthesis for ML-KEM NTT Coprocessor"
puts "Target Device: $PART"
puts "Top Module:    $TOP"
puts "Project Root:  $PROJ_DIR"
puts "=========================================================="

file mkdir "results/synthesis"
file mkdir "results/timing"

read_verilog -sv [list \
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
    "rtl/axi/axi_lite_coprocessor.v" \
    "rtl/dma/ntt_dma.v" \
    "rtl/interrupt/interrupt_ctrl.v" \
    "rtl/mlkem_coprocessor_top.v" \
]

read_xdc [list "constraints/mlkem_coprocessor.xdc"]

synth_design -top $TOP -part $PART -mode out_of_context

report_utilization -file "results/synthesis/utilization_synth.rpt" -pb "results/synthesis/utilization_synth.pb"
report_timing_summary -file "results/timing/timing_summary.rpt" -max_paths 10
report_drc -file "results/synthesis/drc.rpt"

write_checkpoint -force "results/synthesis/mlkem_coprocessor_synth.dcp"

puts "=========================================================="
puts "Synthesis Finished Successfully!"
puts "Reports generated in results/synthesis/ and results/timing/"
puts "=========================================================="
