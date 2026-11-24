set SCRIPT_DIR [file normalize [file dirname [info script]]]
cd $SCRIPT_DIR

open_project -reset prj_butterfly_var1
set_top butterfly_hls
add_files butterfly.cpp -cflags "-DVARIANT=1"
add_files -tb butterfly_tb.cpp -cflags "-DVARIANT=1"
open_solution -reset "solution1" -flow_target vivado
set_part {xc7z010clg400-1}
create_clock -period 10 -name default
csim_design
csynth_design
close_project

open_project -reset prj_butterfly_var2
set_top butterfly_hls
add_files butterfly.cpp -cflags "-DVARIANT=2"
add_files -tb butterfly_tb.cpp -cflags "-DVARIANT=2"
open_solution -reset "solution1" -flow_target vivado
set_part {xc7z010clg400-1}
create_clock -period 10 -name default
csim_design
csynth_design
close_project
exit
