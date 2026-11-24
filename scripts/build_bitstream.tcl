set_param general.maxThreads 8

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR   [file normalize "$SCRIPT_DIR/.."]
cd $PROJ_DIR

set PART "xc7z010clg400-1"
set TOP  "soc_top"

puts "=========================================================="
puts " Building Bitstream for $TOP on $PART"
puts " Project Root: $PROJ_DIR"
puts "=========================================================="

file mkdir "bitstream"
file mkdir "results/synthesis"
file mkdir "results/implementation"
file mkdir "results/timing"

read_verilog [list \
    "rtl/soc/soc_top.v" \
    "rtl/soc/axi_demux.v" \
    "rtl/mlkem_coprocessor_top.v" \
    "rtl/axi/axi_lite_coprocessor.v" \
    "rtl/ntt/poly_multiplier.v" \
    "rtl/ntt/ntt_engine.v" \
    "rtl/ntt/ntt_addr_gen.v" \
    "rtl/arithmetic/basemul.v" \
    "rtl/arithmetic/mod_add.v" \
    "rtl/arithmetic/mod_sub.v" \
    "rtl/arithmetic/mod_mul.v" \
    "rtl/butterfly/butterfly.v" \
    "rtl/memory/poly_bram.v" \
    "rtl/memory/twiddle_rom.v" \
    "rtl/dma/ntt_dma.v" \
    "rtl/interrupt/interrupt_ctrl.v" \
    "rtl/soc/picorv32.v" \
    "rtl/soc/simpleuart.v" \
]

read_xdc [list "constraints/zybo_z7_10.xdc"]

puts "--- Running Synthesis ---"
synth_design -top $TOP -part $PART
write_checkpoint -force "results/synthesis/soc_top_synth.dcp"
report_utilization -file "results/synthesis/soc_top_utilization.rpt"

puts "--- Running opt_design ---"
opt_design

puts "--- Running place_design ---"
place_design

puts "--- Running phys_opt_design ---"
phys_opt_design

puts "--- Running route_design ---"
route_design

write_checkpoint -force "results/implementation/soc_top_routed.dcp"
report_timing_summary -file "results/timing/soc_top_timing.rpt"
report_drc -file "results/implementation/soc_top_drc.rpt"

puts "--- Writing Bitstream and Debug Probes ---"
write_bitstream -force "bitstream/soc_top.bit"
write_debug_probes -force "bitstream/soc_top.ltx"

puts "=========================================================="
puts " SUCCESS! Bitstream generated:"
puts "   bitstream/soc_top.bit"
puts "   bitstream/soc_top.ltx"
puts "=========================================================="
