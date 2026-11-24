set script_dir [file normalize [file dirname [info script]]]
set proj_dir   [file normalize "$script_dir/.."]

set bit_file "$proj_dir/bitstream/zynq_hybrid_soc.bit"
set xsa_file "$proj_dir/bitstream/zynq_hybrid_soc.xsa"
set ps7_tcl  "$proj_dir/bitstream/ps7_init.tcl"
set elf_file "$proj_dir/software/ps_bridge/ps_bridge.elf"

foreach req [list $bit_file $xsa_file $elf_file] {
    if {![file exists $req]} {
        puts "ERROR: Required file missing: $req"
        puts "       Run Vivado build_zynq_hybrid.tcl and build_ps_bridge.ps1 first."
        exit 1
    }
}

puts "Connecting to hardware server / Zybo Z7-10 JTAG..."
connect

puts "Selecting APU target and issuing system reset..."
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 500

puts "Programming PL bitstream: $bit_file"
fpga -file $bit_file

puts "Loading XSA hardware definition: $xsa_file"
targets -set -nocase -filter {name =~ "APU*"}
loadhw -hw $xsa_file

if {![file exists $ps7_tcl]} {
    set gen_candidates [glob -nocomplain "$proj_dir/build_zynq_hybrid/zynq_hybrid.gen/sources_1/bd/zynq_hybrid_bd/ip/*processing_system7*/ps7_init.tcl"]
    if {[llength $gen_candidates] > 0} {
        set ps7_tcl [lindex $gen_candidates 0]
    } else {
        puts "ERROR: ps7_init.tcl not found."
        exit 1
    }
}

puts "Initializing PS7 (clocks, MIO48/49 UART1 @ 100MHz, M_AXI_GP0)..."
source $ps7_tcl
ps7_init
ps7_post_config

puts "Selecting ARM Cortex-A9 Core #0..."
targets -set -nocase -filter {name =~ "ARM Cortex-A9 MPCore #0" || name =~ "*A9*#0"}
stop

puts "Downloading PS bridge firmware: $elf_file"
dow $elf_file

puts "Starting ARM Cortex-A9 PS UART1 <-> AXI Mailbox bridge..."
con

puts "=========================================================="
puts "Zybo Z7-10 programmed and running!"
puts "Next step: python scripts/live_demo.py --port auto"
puts "=========================================================="
exit 0
