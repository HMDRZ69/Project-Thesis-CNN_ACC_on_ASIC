##############################################################################
#  Genus Synthesis Script — CNN Accelerator ASIC  (SRAM Macro version)
#  Target Process : IHP SG13G2 130nm
#  Top Module     : cnn_top
#  Clock Target   : 100 MHz (10 ns period)
#  Corner         : Typical — 1.20V, 25°C
#  SRAM Macro     : RM_IHPSG13_1P_4096x8_c3_bm_bist (×4 total, 2 per bank)
##############################################################################

##############################################################################
# 0. PATHS
##############################################################################

set LIB_ROOT /home/rah47472/asic_project/libs/OpenFPGA/Fabric/ihp-sg13g2/libs.ref

# Standard cell Liberty (typical corner)
set STD_LIB  $LIB_ROOT/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib

# SRAM macro Liberty (typical corner — same PVT as std cell)
set SRAM_LIB $LIB_ROOT/sg13g2_sram/lib/RM_IHPSG13_1P_4096x8_c3_bm_bist_typ_1p20V_25C.lib

# SRAM macro Verilog view (for elaboration)
set SRAM_V   $LIB_ROOT/sg13g2_sram/verilog/RM_IHPSG13_1P_4096x8_c3_bm_bist.v

# RTL source directory
set RTL_DIR  /home/rah47472/asic_project/rtl

# Output directory
set OUT_DIR  /home/rah47472/asic_project/genus_out

##############################################################################
# 1. TOOL SETUP
##############################################################################

file mkdir $OUT_DIR
file mkdir $OUT_DIR/reports
file mkdir $OUT_DIR/netlist
file mkdir $OUT_DIR/sdc

##############################################################################
# 2. TECHNOLOGY LIBRARIES
##############################################################################

# Both Liberty files — stdcell first, then SRAM macro
set_db / .lib_search_path [list \
    [file dirname $STD_LIB] \
    [file dirname $SRAM_LIB] \
]

set_db / .library [list \
    [file tail $STD_LIB]  \
    [file tail $SRAM_LIB] \
]

set_db / .syn_generic_effort  medium
set_db / .syn_map_effort      medium
set_db / .syn_opt_effort      medium

##############################################################################
# 3. READ RTL
##############################################################################

# SRAM macro Verilog view — must be read before feature_sram.sv wrapper
# read_hdl -sv $SRAM_V

# Let Genus resolve SRAM from Liberty, not from simulation Verilog
set_db / .hdl_resolve_instance_with_libcell true

# Design RTL — dependency order
read_hdl -sv $RTL_DIR/controller_fsm.sv
read_hdl -sv $RTL_DIR/addr_gen.sv
read_hdl -sv $RTL_DIR/weight_rom.sv
read_hdl -sv $RTL_DIR/feature_sram.sv
read_hdl -sv $RTL_DIR/conv_engine.sv
read_hdl -sv $RTL_DIR/pool_engine.sv
read_hdl -sv $RTL_DIR/cnn_top.sv

##############################################################################
# 4. ELABORATE
##############################################################################

elaborate cnn_top
check_design -unresolved

set_db [get_db hinsts *u_lower*] .dont_touch true
set_db [get_db hinsts *u_upper*] .dont_touch true

##############################################################################
# 5. TIMING CONSTRAINTS
##############################################################################

create_clock -name clk -period 10.0 -waveform {0 5} [get_ports clk]

set_clock_uncertainty -setup 0.1  [get_clocks clk]
set_clock_uncertainty -hold  0.05 [get_clocks clk]

set_input_delay  -max 2.0 -clock clk [get_ports {rst_n start}]
set_input_delay  -min 0.5 -clock clk [get_ports {rst_n start}]

set_output_delay -max 2.0 -clock clk [get_ports {done debug_sram_a_rdata debug_sram_b_rdata debug_conv_out_data}]
set_output_delay -min 0.5 -clock clk [get_ports {done debug_sram_a_rdata debug_sram_b_rdata debug_conv_out_data}]

set_ideal_network [get_ports clk]
set_false_path    -from [get_ports rst_n]

##############################################################################
# 6. PRESERVE SRAM INSTANCES — prevent Genus from removing as dead logic
#
# Two complementary mechanisms:
#   set_db .preserve true  — on the macro design (prevents internal opt)
#   set_dont_touch         — on each instance in cnn_top hierarchy
##############################################################################

# Do not delete unloaded hierarchy
set_db / .delete_unloaded_insts false

# Protect SRAM wrapper instances
set_db [get_db hinsts *u_sram_a*] .ungroup_ok false
set_db [get_db hinsts *u_sram_b*] .ungroup_ok false

# Protect SRAM macro instances inside wrappers
set_db [get_db hinsts *u_lower*] .preserve true
set_db [get_db hinsts *u_upper*] .preserve true
set_db [get_db hinsts *u_lower*] .ungroup_ok false
set_db [get_db hinsts *u_upper*] .ungroup_ok false

##############################################################################
# 7. SYNTHESIS
##############################################################################

puts "=== SRAM instances check ==="
puts [get_db hinsts *sram*]
puts [get_db hinsts *u_lower*]
puts [get_db hinsts *u_upper*]

syn_generic
syn_map
syn_opt

##############################################################################
# 8. REPORTS
##############################################################################

# Setup timing (worst 10 paths)
report_timing -max_paths 10 \
    > $OUT_DIR/reports/timing_setup.rpt

# Hold timing — use min_slack filter (Genus version has no -hold/-late flag)
report_timing -max_paths 10 -min_slack -1000000 \
    > $OUT_DIR/reports/timing_hold.rpt

# Area
report_area \
    > $OUT_DIR/reports/area.rpt

# Power
report_power \
    > $OUT_DIR/reports/power.rpt

# Qor
report_qor \
    > $OUT_DIR/reports/qor.rpt

##############################################################################
# 9. WRITE OUTPUTS
##############################################################################

write_hdl \
    > $OUT_DIR/netlist/cnn_top_netlist.v

write_sdc \
    > $OUT_DIR/sdc/cnn_top.sdc

write_db $OUT_DIR/cnn_top_genus.db

##############################################################################
# 10. DONE
##############################################################################

puts ""
puts "============================================================"
puts "  Genus synthesis complete (SRAM macro version)."
puts "  Netlist : $OUT_DIR/netlist/cnn_top_netlist.v"
puts "  SDC     : $OUT_DIR/sdc/cnn_top.sdc"
puts "  Reports : $OUT_DIR/reports/"
puts "============================================================"
puts ""