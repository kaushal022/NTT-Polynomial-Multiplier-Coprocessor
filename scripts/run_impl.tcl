set_param general.maxThreads 8

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR   [file normalize "$SCRIPT_DIR/.."]
cd $PROJ_DIR

puts "=========================================================="
puts "Opening Synthesis Checkpoint"
puts "=========================================================="
open_checkpoint "results/synthesis/mlkem_coprocessor_synth.dcp"

puts "=========================================================="
puts "Running Logic Optimization (opt_design)"
puts "=========================================================="
opt_design

puts "=========================================================="
puts "Running Placement (place_design)"
puts "=========================================================="
place_design

puts "=========================================================="
puts "Running Physical Optimization (phys_opt_design)"
puts "=========================================================="
phys_opt_design

puts "=========================================================="
puts "Running Routing (route_design)"
puts "=========================================================="
route_design

puts "=========================================================="
puts "Generating Implementation Reports"
puts "=========================================================="
report_timing_summary -file "results/timing/impl_timing_summary.rpt"
report_utilization -file "results/synthesis/impl_utilization.rpt"
report_utilization -hierarchical -file "results/synthesis/impl_utilization_hierarchical.rpt"
report_drc -file "results/synthesis/impl_drc.rpt"

puts "=========================================================="
puts "Saving Routed Checkpoint"
puts "=========================================================="
write_checkpoint -force "results/synthesis/mlkem_coprocessor_routed.dcp"

puts "=========================================================="
puts "Implementation Completed Successfully!"
puts "=========================================================="
