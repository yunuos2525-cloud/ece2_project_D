set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir .. .. .. ..]]
set checkpoint [file join $root_dir FPGA build w1 post_route.dcp]

puts "REVIEW_CHECKPOINT=$checkpoint"
open_checkpoint $checkpoint

set clocks [get_clocks -quiet]
puts "REVIEW_CLOCK_COUNT=[llength $clocks]"
foreach clk $clocks {
    puts "REVIEW_CLOCK name=$clk period=[get_property PERIOD $clk]"
}

set async_cells [get_cells -hier -quiet -filter {ASYNC_REG == TRUE}]
puts "REVIEW_ASYNC_REG_CELL_COUNT=[llength $async_cells]"
foreach cell $async_cells {
    puts "REVIEW_ASYNC_REG_CELL=$cell"
}

if {[catch {check_timing -verbose -file [file join $script_dir check_timing.rpt]} message]} {
    puts "REVIEW_CHECK_TIMING_ERROR=$message"
} else {
    puts "REVIEW_CHECK_TIMING_COMPLETE"
}

if {[catch {report_timing_summary -delay_type min_max -report_unconstrained -file [file join $script_dir timing_unconstrained.rpt]} message]} {
    puts "REVIEW_TIMING_SUMMARY_ERROR=$message"
} else {
    puts "REVIEW_TIMING_SUMMARY_COMPLETE"
}

if {[catch {report_cdc -details -file [file join $script_dir cdc.rpt]} message]} {
    puts "REVIEW_CDC_ERROR=$message"
} else {
    puts "REVIEW_CDC_COMPLETE"
}

if {[catch {report_exceptions -file [file join $script_dir timing_exceptions.rpt]} message]} {
    puts "REVIEW_EXCEPTIONS_ERROR=$message"
} else {
    puts "REVIEW_EXCEPTIONS_COMPLETE"
}

puts "REVIEW_DONE"
