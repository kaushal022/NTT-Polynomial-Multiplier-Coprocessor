set_param general.maxThreads 8

proc run_test {top_mod file_path rpt_prefix} {
    create_project -in_memory -part xc7z010clg400-1
    read_verilog -sv $file_path
    synth_design -top $top_mod -part xc7z010clg400-1 -mode out_of_context
    create_clock -period 10.000 -name clk [get_ports clk]
    opt_design
    place_design
    route_design
    report_utilization -file "${rpt_prefix}_util.rpt"
    report_timing_summary -file "${rpt_prefix}_timing.rpt"
    close_project
}

run_test "mod_mul" "rtl/arithmetic/mod_mul.v" "results/bdd_xq_correction/baseline"
run_test "mod_mul_bdd" "rtl/arithmetic/mod_mul_bdd.v" "results/bdd_xq_correction/bdd_variant"
