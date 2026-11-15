set script_dir [file dirname [file normalize [info script]]]
set fpga_dir [file normalize [file join $script_dir ..]]
set root_dir [file normalize [file join $fpga_dir ..]]
set build_dir [file join $fpga_dir build w2]
set evidence_dir [file join $root_dir project_evidence fpga W2 pre vivado]
file mkdir $build_dir
file mkdir $evidence_dir
set src_dir [file join $fpga_dir src]
read_verilog -sv [glob -directory $src_dir *.sv]
read_xdc [file join $fpga_dir constraints w2_board.xdc]
synth_design -top w2_board_top -part xc7s75fgga484-1
report_utilization -file [file join $evidence_dir post_synth_utilization.rpt]
report_timing_summary -file [file join $evidence_dir post_synth_timing.rpt]
write_checkpoint -force [file join $build_dir post_synth.dcp]
opt_design
place_design
phys_opt_design
route_design
report_drc -file [file join $evidence_dir post_route_drc.rpt]
check_timing -verbose -file [file join $evidence_dir post_route_check_timing.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $evidence_dir post_route_timing.rpt]
report_cdc -details -file [file join $evidence_dir post_route_cdc.rpt]
report_exceptions -file [file join $evidence_dir post_route_exceptions.rpt]
report_utilization -file [file join $evidence_dir post_route_utilization.rpt]
report_io -file [file join $evidence_dir post_route_io.rpt]
write_checkpoint -force [file join $build_dir post_route.dcp]
write_bitstream -force [file join $build_dir w2_board_top.bit]
puts "PASS VIVADO_W2_BUILD: [file join $build_dir w2_board_top.bit]"
