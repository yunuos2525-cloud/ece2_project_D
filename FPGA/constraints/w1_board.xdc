# COMBO II-DLD S75 / xc7s75fgga484-1 mappings reviewed from existing local LAB material.
set_property PACKAGE_PIN B6 [get_ports clk_50mhz]
set_property PACKAGE_PIN K4 [get_ports rst_p]
set_property PACKAGE_PIN U4 [get_ports {adc_channel[0]}]
set_property PACKAGE_PIN V4 [get_ports {adc_channel[1]}]
set_property PACKAGE_PIN W1 [get_ports {adc_channel[2]}]

set_property PACKAGE_PIN H3 [get_ports adc_ncs]
set_property PACKAGE_PIN H5 [get_ports adc_din]
set_property PACKAGE_PIN J6 [get_ports adc_dout]
set_property PACKAGE_PIN H7 [get_ports adc_sclk]

set_property PACKAGE_PIN G2 [get_ports dac_a_b]
set_property PACKAGE_PIN E1 [get_ports dac_csn]
set_property PACKAGE_PIN F4 [get_ports dac_ldacn]
set_property PACKAGE_PIN G4 [get_ports dac_wen]
set_property PACKAGE_PIN E3 [get_ports {dac_d[0]}]
set_property PACKAGE_PIN E5 [get_ports {dac_d[1]}]
set_property PACKAGE_PIN D2 [get_ports {dac_d[2]}]
set_property PACKAGE_PIN D5 [get_ports {dac_d[3]}]
set_property PACKAGE_PIN C2 [get_ports {dac_d[4]}]
set_property PACKAGE_PIN C4 [get_ports {dac_d[5]}]
set_property PACKAGE_PIN B1 [get_ports {dac_d[6]}]
set_property PACKAGE_PIN B3 [get_ports {dac_d[7]}]

set_property PACKAGE_PIN F8 [get_ports spi_sck]
set_property PACKAGE_PIN E8 [get_ports spi_mosi]
set_property PACKAGE_PIN A7 [get_ports spi_cs_n]
set_property PACKAGE_PIN G8 [get_ports spi_miso]

set_property PACKAGE_PIN N5 [get_ports {led_out[0]}]
set_property PACKAGE_PIN M1 [get_ports {led_out[1]}]
set_property PACKAGE_PIN M3 [get_ports {led_out[2]}]
set_property PACKAGE_PIN M7 [get_ports {led_out[3]}]
set_property PACKAGE_PIN N7 [get_ports {led_out[4]}]
set_property PACKAGE_PIN M2 [get_ports {led_out[5]}]
set_property PACKAGE_PIN M4 [get_ports {led_out[6]}]
set_property PACKAGE_PIN L4 [get_ports {led_out[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports *]
create_clock -name clk_50mhz -period 20.000 [get_ports clk_50mhz]

# Asynchronous boundaries only. Reset assertion reaches only the three marked
# conditioner stages; reset release is synchronous before downstream fanout.
set_false_path -from [get_ports rst_p] -to \
    [get_cells -hier -regexp {.*u_reset_conditioner/sync_ff_reg\[[0-9]+\]}]

# SPI is deliberately oversampled in the 50 MHz domain. Cut only the first
# ASYNC_REG stage rather than hiding all paths originating at each port.
set_false_path -from [get_ports spi_sck] -to \
    [get_cells -hier -regexp {.*u_spi/sck_sync_reg\[0\]}]
set_false_path -from [get_ports spi_mosi] -to \
    [get_cells -hier -regexp {.*u_spi/mosi_sync_reg\[0\]}]
set_false_path -from [get_ports spi_cs_n] -to \
    [get_cells -hier -regexp {.*u_spi/cs_sync_reg\[0\]}]

# These board inputs remain externally timed/unverified in W1. Do not infer
# datasheet or board delays that have not been confirmed.
set_false_path -from [get_ports {adc_channel[*] adc_dout}]

# Physical J10/BD_SEL1 route, voltage and contention remain mandatory board checks.
