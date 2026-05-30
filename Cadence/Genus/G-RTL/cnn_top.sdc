# ####################################################################

#  Created by Genus(TM) Synthesis Solution 23.11-s100_1 on Tue Apr 28 20:20:53 CEST 2026

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design cnn_top

create_clock -name "clk" -period 10.0 -waveform {0.0 5.0} [get_ports clk]
set_false_path -from [get_ports rst_n]
set_clock_gating_check -setup 0.0 
set_input_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports rst_n]
set_input_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports start]
set_input_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports rst_n]
set_input_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports start]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports done]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_a_rdata[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_a_rdata[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_a_rdata[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_a_rdata[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_a_rdata[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_a_rdata[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_a_rdata[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_a_rdata[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_b_rdata[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_b_rdata[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_b_rdata[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_b_rdata[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_b_rdata[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_b_rdata[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_b_rdata[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_sram_b_rdata[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_conv_out_data[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_conv_out_data[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_conv_out_data[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_conv_out_data[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_conv_out_data[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_conv_out_data[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_conv_out_data[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {debug_conv_out_data[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports done]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_a_rdata[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_a_rdata[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_a_rdata[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_a_rdata[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_a_rdata[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_a_rdata[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_a_rdata[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_a_rdata[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_b_rdata[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_b_rdata[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_b_rdata[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_b_rdata[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_b_rdata[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_b_rdata[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_b_rdata[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_sram_b_rdata[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_conv_out_data[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_conv_out_data[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_conv_out_data[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_conv_out_data[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_conv_out_data[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_conv_out_data[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_conv_out_data[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.5 [get_ports {debug_conv_out_data[0]}]
set_ideal_network [get_ports clk]
set_wire_load_mode "top"
set_clock_uncertainty -setup 0.1 [get_clocks clk]
set_clock_uncertainty -hold 0.05 [get_clocks clk]
