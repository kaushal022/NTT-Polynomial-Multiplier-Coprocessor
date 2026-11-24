set_param general.maxThreads 8

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR   [file normalize "$SCRIPT_DIR/.."]
set BUILD_DIR  [file normalize "$::env(TEMP)/zybo_hybrid_vivado"]
set BIT_DIR    "$PROJ_DIR/bitstream"
set SYNTH_RPT  "$PROJ_DIR/results/synthesis"
set TIME_RPT   "$PROJ_DIR/results/timing"

file mkdir $BUILD_DIR $BIT_DIR $SYNTH_RPT $TIME_RPT
cd $BUILD_DIR

puts "=========================================================="
puts "1. Creating Vivado Project for Zybo Z7-10 (xc7z010clg400-1)"
puts "=========================================================="
create_project zynq_hybrid $BUILD_DIR -part xc7z010clg400-1 -force

set rtl_files [list \
    "$PROJ_DIR/rtl/arithmetic/mod_add.v" \
    "$PROJ_DIR/rtl/arithmetic/mod_sub.v" \
    "$PROJ_DIR/rtl/arithmetic/mod_mul.v" \
    "$PROJ_DIR/rtl/arithmetic/basemul.v" \
    "$PROJ_DIR/rtl/butterfly/butterfly.v" \
    "$PROJ_DIR/rtl/memory/poly_bram.v" \
    "$PROJ_DIR/rtl/memory/twiddle_rom.v" \
    "$PROJ_DIR/rtl/ntt/ntt_addr_gen.v" \
    "$PROJ_DIR/rtl/ntt/ntt_engine.v" \
    "$PROJ_DIR/rtl/ntt/poly_multiplier.v" \
    "$PROJ_DIR/rtl/axi/axi_lite_coprocessor.v" \
    "$PROJ_DIR/rtl/dma/ntt_dma.v" \
    "$PROJ_DIR/rtl/interrupt/interrupt_ctrl.v" \
    "$PROJ_DIR/rtl/mlkem_dma_coproc_top.v" \
    "$PROJ_DIR/rtl/soc/picorv32.v" \
    "$PROJ_DIR/rtl/soc/simpleuart.v" \
    "$PROJ_DIR/rtl/soc/axi_mailbox.v" \
    "$PROJ_DIR/rtl/soc/axi_arbiter_2m.v" \
    "$PROJ_DIR/rtl/soc/axi_demux_4s.v" \
    "$PROJ_DIR/rtl/soc/pl_hybrid_soc.v" \
]

add_files -norecurse -fileset sources_1 $rtl_files
add_files -norecurse -fileset sources_1 [list "$PROJ_DIR/rtl/soc/firmware_hybrid.hex"]
set_property file_type {Memory Initialization Files} [get_files *firmware_hybrid.hex]

add_files -norecurse -fileset constrs_1 [list "$PROJ_DIR/constraints/zynq_hybrid.xdc"]
set_property include_dirs [list "$PROJ_DIR/reference" "$PROJ_DIR/rtl/soc"] [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "=========================================================="
puts "2. Building Zynq-7000 + PL Hybrid Block Design"
puts "=========================================================="
create_bd_design "zynq_hybrid_bd"

set ps7 [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0]

set_property -dict [list \
    CONFIG.PCW_CRYSTAL_PERIPHERAL_FREQMHZ {33.333333} \
    CONFIG.PCW_APU_PERIPHERAL_FREQMHZ {666.666666} \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_EN_CLK0_PORT {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_EN_RST0_PORT {1} \
    CONFIG.PCW_PRESET_BANK0_VOLTAGE {LVCMOS 3.3V} \
    CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 1.8V} \
    CONFIG.PCW_UART1_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_UART1_UART1_IO {MIO 48 .. 49} \
    CONFIG.PCW_UART_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_UART_PERIPHERAL_VALID {1} \
    CONFIG.PCW_UIPARAM_DDR_ENABLE {1} \
    CONFIG.PCW_UIPARAM_DDR_PARTNO {MT41K256M16 RE-125} \
    CONFIG.PCW_UIPARAM_DDR_BUS_WIDTH {32 Bit} \
    CONFIG.PCW_UIPARAM_DDR_FREQ_MHZ {525} \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY0 {0.221} \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY1 {0.222} \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY2 {0.217} \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY3 {0.244} \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_0 {-0.050} \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_1 {-0.044} \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_2 {-0.035} \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_3 {-0.100} \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_WRITE_LEVEL {1} \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_READ_GATE {1} \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_DATA_EYE {1} \
    CONFIG.PCW_UIPARAM_DDR_USE_INTERNAL_VREF {0} \
] $ps7

apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config { \
    make_external "FIXED_IO, DDR" \
    Master "Disable" \
    Slave "Disable" \
} $ps7

set pl_soc [create_bd_cell -type module -reference pl_hybrid_soc pl_hybrid_soc_0]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
    Clk_master {/processing_system7_0/FCLK_CLK0 (100 MHz)} \
    Clk_slave {/processing_system7_0/FCLK_CLK0 (100 MHz)} \
    Clk_xbar {Auto} \
    Master {/processing_system7_0/M_AXI_GP0} \
    Slave {/pl_hybrid_soc_0/s_ps_axi} \
    ddr_seg {Auto} \
    intc_ip {New AXI Interconnect} \
    master_apm {0} \
} [get_bd_intf_pins pl_hybrid_soc_0/s_ps_axi]

if {[llength [get_bd_nets -quiet -of_objects [get_bd_pins pl_hybrid_soc_0/clk_100m]]] == 0} {
    connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins pl_hybrid_soc_0/clk_100m]
}
if {[llength [get_bd_nets -quiet -of_objects [get_bd_pins pl_hybrid_soc_0/resetn]]] == 0} {
    set rst_pin [get_bd_pins -quiet rst_ps7_0_100M/peripheral_aresetn]
    if {[llength $rst_pin] == 0} {
        set rst_pin [get_bd_pins -quiet proc_sys_reset_0/peripheral_aresetn]
    }
    if {[llength $rst_pin] > 0} {
        connect_bd_net $rst_pin [get_bd_pins pl_hybrid_soc_0/resetn]
    } else {
        connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins pl_hybrid_soc_0/resetn]
    }
}

create_bd_port -dir O uart_tx
create_bd_port -dir I uart_rx
create_bd_port -dir O -from 3 -to 0 led

connect_bd_net [get_bd_pins pl_hybrid_soc_0/uart_tx] [get_bd_ports uart_tx]
connect_bd_net [get_bd_pins pl_hybrid_soc_0/uart_rx] [get_bd_ports uart_rx]
connect_bd_net [get_bd_pins pl_hybrid_soc_0/led]     [get_bd_ports led]

assign_bd_address
set gp0_segs [get_bd_addr_segs -of_objects [get_bd_addr_spaces processing_system7_0/Data]]
foreach seg $gp0_segs {
    if {[string match "*pl_hybrid_soc_0*" $seg]} {
        set_property offset 0x43C00000 $seg
        set_property range  4K         $seg
        puts "Mapped PS7 GP0 segment $seg -> offset=[get_property offset $seg], range=[get_property range $seg]"
    }
}

validate_bd_design
save_bd_design

set bd_file [get_files *zynq_hybrid_bd.bd]
set_property synth_checkpoint_mode None $bd_file
generate_target all $bd_file

set wrapper_file [make_wrapper -files $bd_file -top]
add_files -norecurse -fileset sources_1 $wrapper_file
set_property top zynq_hybrid_bd_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "=========================================================="
puts "3. Running Synthesis (synth_1)"
puts "=========================================================="
set synth_run_dir "$BUILD_DIR/zynq_hybrid.runs/synth_1"
file mkdir $synth_run_dir
file copy -force "$PROJ_DIR/rtl/soc/firmware_hybrid.hex" "$synth_run_dir/firmware_hybrid.hex"

launch_runs synth_1 -jobs 8
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "synth_1 STATUS = $synth_status"
if {![string match "*Complete*" $synth_status]} {
    puts "ERROR: Synthesis failed with status: $synth_status"
    exit 1
}

puts "=========================================================="
puts "4. Running Implementation & Bitstream (impl_1)"
puts "=========================================================="
set impl_run_dir "$BUILD_DIR/zynq_hybrid.runs/impl_1"
file mkdir $impl_run_dir
file copy -force "$PROJ_DIR/rtl/soc/firmware_hybrid.hex" "$impl_run_dir/firmware_hybrid.hex"

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "impl_1 STATUS = $impl_status"
if {![string match "*Complete*" $impl_status] && ![string match "*write_bitstream Complete*" $impl_status]} {
    puts "ERROR: Implementation/Bitstream failed with status: $impl_status"
    exit 1
}

puts "=========================================================="
puts "5. Exporting Reports, Bitstream, PS7 Init & XSA"
puts "=========================================================="
open_run impl_1

report_utilization -file "$SYNTH_RPT/zynq_hybrid_utilization.rpt"
report_utilization -hierarchical -file "$SYNTH_RPT/zynq_hybrid_utilization_hier.rpt"
report_timing_summary -file "$TIME_RPT/zynq_hybrid_timing.rpt"
report_drc -file "$SYNTH_RPT/zynq_hybrid_drc.rpt"

set bit_src "$impl_run_dir/zynq_hybrid_bd_wrapper.bit"
if {![file exists $bit_src]} {
    puts "ERROR: Expected bitstream not found at $bit_src"
    exit 1
}
file copy -force $bit_src "$BIT_DIR/zynq_hybrid_soc.bit"

write_hw_platform -fixed -include_bit -force -file "$BIT_DIR/zynq_hybrid_soc.xsa"

set ps7_init_candidates [glob -nocomplain "$BUILD_DIR/zynq_hybrid.gen/sources_1/bd/zynq_hybrid_bd/ip/*processing_system7*/ps7_init.tcl"]
if {[llength $ps7_init_candidates] > 0} {
    file copy -force [lindex $ps7_init_candidates 0] "$BIT_DIR/ps7_init.tcl"
    puts "Copied ps7_init.tcl to $BIT_DIR/ps7_init.tcl"
}

puts "=========================================================="
puts "Zynq Hybrid Bitstream + XSA Build Completed!"
puts "  Bitstream : $BIT_DIR/zynq_hybrid_soc.bit"
puts "  XSA       : $BIT_DIR/zynq_hybrid_soc.xsa"
puts "=========================================================="
