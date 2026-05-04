##############################################################################
#  Genus Synthesis Script — CNN Accelerator on ASIC
#  Target Process : IHP SG13G2 130nm
#  Top Module     : cnn_top
#  Clock Target   : 100 MHz (10 ns period)
#  Corner         : Typical — 1.20V, 25°C
#  Author         : Hamed Ramezanzadeh  (OTH Regensburg MSc Project Thesis 2025-2026)
##############################################################################

##############################################################################
# 0. PATHS — adjust if your directory layout changes
##############################################################################

# Root of the cloned IHP OpenFPGA repo
set LIB_ROOT /home/rah47472/asic_project/libs/OpenFPGA/Fabric/ihp-sg13g2/libs.ref

# Standard cell Liberty file (typical corner)
set STD_LIB  $LIB_ROOT/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib

# RTL source directory (all 7 files must be here)
set RTL_DIR  /home/rah47472/asic_project/rtl

# Output directory (created automatically below)
set OUT_DIR  /home/rah47472/asic_project/genus_out

##############################################################################
# 1. TOOL SETUP
##############################################################################

# Create output directory if it does not exist
file mkdir $OUT_DIR
file mkdir $OUT_DIR/reports
file mkdir $OUT_DIR/netlist
file mkdir $OUT_DIR/sdc

##############################################################################
# 2. TECHNOLOGY LIBRARIES
##############################################################################

# Liberty timing library — standard cells only
# (behavioral feature_sram.sv is synthesized as register array; no SRAM macro lib needed)
set_db / .lib_search_path [list [file dirname $STD_LIB]]
set_db / .library         [list [file tail    $STD_LIB]]

# Synthesis effort: medium gives good QoR without excessive runtime
set_db / .syn_generic_effort  medium
set_db / .syn_map_effort      medium
set_db / .syn_opt_effort      medium

##############################################################################
# 3. READ RTL
##############################################################################

# Order matters: dependencies before dependents
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

# Confirm hierarchy is intact
check_design -unresolved

##############################################################################
# 5. TIMING CONSTRAINTS (SDC)
##############################################################################

# Primary clock: 100 MHz = 10 ns period
# 40/60 split: rise 0→4ns, fall 5→10ns (standard convention)
create_clock -name clk -period 10.0 -waveform {0 5} [get_ports clk]

# Clock uncertainty: 100 ps setup, 50 ps hold (conservative for 130nm)
set_clock_uncertainty -setup 0.1 [get_clocks clk]
set_clock_uncertainty -hold  0.05 [get_clocks clk]

# Input delays (assume inputs arrive 2 ns after clock edge)
set_input_delay  -max 2.0 -clock clk [get_ports {rst_n start}]
set_input_delay  -min 0.5 -clock clk [get_ports {rst_n start}]

# Output delays (assume outputs must be stable 2 ns before next clock edge)
set_output_delay -max 2.0 -clock clk [get_ports done]
set_output_delay -min 0.5 -clock clk [get_ports done]

# Clock port is ideal — do not apply input delay to it
set_ideal_network [get_ports clk]

# False paths: async reset does not need timing closure
set_false_path -from [get_ports rst_n]

##############################################################################
# 6. SYNTHESIS
##############################################################################

# Step 1 — Generic: technology-independent optimisation (GTECH)
syn_generic

# Step 2 — Map: map GTECH to SG13G2 standard cells
syn_map

# Step 3 — Incremental optimisation: fix setup/hold violations, reduce area
syn_opt

##############################################################################
# 7. REPORTS
##############################################################################

# Timing — setup (worst 10 paths)
report_timing -max_paths 10 \
    > $OUT_DIR/reports/timing_setup.rpt

# Timing — hold
report_timing -max_paths 10 -path_type full \
    > $OUT_DIR/reports/timing_hold.rpt

# Area
report_area \
    > $OUT_DIR/reports/area.rpt

# Power (switching activity estimated at 20% toggle rate) ---
report_power \
    > $OUT_DIR/reports/power.rpt

# Cell usage (Shows which cells Genus picked)
# report_cell \
#   > $OUT_DIR/reports/cell_usage.rpt

# QoR Summary
report_qor \
    > $OUT_DIR/reports/qor.rpt

# --- Warnings and messages ---
report_messages \
    > $OUT_DIR/reports/messages.rpt  

##############################################################################
# 8. WRITE OUTPUTS
##############################################################################

# Gate-level netlist ((Verilog — for post-synthesis simulation or Innovus))
write_hdl \
    > $OUT_DIR/netlist/cnn_top_netlist.v

# SDC (constraints (for handoff to Innovus P&R))
write_sdc \
    > $OUT_DIR/sdc/cnn_top.sdc

# Genus DB (Design database (Genus internal — allows re-loading without re-running))
write_db $OUT_DIR/cnn_top_genus.db

##############################################################################
# 9. DONE
##############################################################################

puts ""
puts "============================================================"
puts "  Genus synthesis complete."
puts "  Netlist : $OUT_DIR/netlist/cnn_top_netlist.v"
puts "  SDC     : $OUT_DIR/sdc/cnn_top.sdc"
puts "  Reports : $OUT_DIR/reports/"
puts "============================================================"
puts ""