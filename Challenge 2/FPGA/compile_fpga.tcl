# compile_fpga.tcl  –  Compile accel_cube2 in Quartus 17.1
# Usage: cd to fpga folder, then: quartus_sh -t compile_fpga.tcl
load_package flow
set script_dir [file dirname [info script]]
project_open [file join $script_dir accel_cube2]
execute_flow -compile
project_close
