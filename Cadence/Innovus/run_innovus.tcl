##############################################################################
#  Innovus Place & Route Script — CNN Accelerator ASIC
#  Technology  : IHP SG13G2 130 nm
#  Top module  : cnn_top
#  Clock       : 100 MHz (10 ns)
#  Corner      : Typical — 1.20 V, 25 °C
#  Author      : Hamed Ramezanzadeh (OTH Regensburg MSc Project Thesis 2026)
##############################################################################

##############################################################################
# 0. PATHS — adjust if your directory layout changes
##############################################################################

set DESIGN       cnn_top
set RESULTS_DIR  /home/rah47472/asic_project/innovus_out

set LIB_ROOT     /home/rah47472/asic_project/libs/OpenFPGA/Fabric/ihp-sg13g2/libs.ref

# Liberty files
set STD_LIB      $LIB_ROOT/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib
set SRAM_LIB     $LIB_ROOT/sg13g2_sram/lib/RM_IHPSG13_1P_4096x8_c3_bm_bist_typ_1p20V_25C.lib

# LEF files — tech LEF must be first, then standard cells, then macros
set TECH_LEF     $LIB_ROOT/sg13g2_stdcell/lef/sg13g2_tech.lef
set STD_LEF      $LIB_ROOT/sg13g2_stdcell/lef/sg13g2_stdcell.lef
set SRAM_LEF     $LIB_ROOT/sg13g2_sram/lef/RM_IHPSG13_1P_4096x8_c3_bm_bist.lef

# Design inputs from Genus
set NETLIST      /home/rah47472/asic_project/genus_out/netlist/cnn_top_netlist.v
set SDC          /home/rah47472/asic_project/genus_out/sdc/cnn_top.sdc

##############################################################################
# 1. CREATE OUTPUT DIRECTORIES
##############################################################################

file mkdir $RESULTS_DIR
file mkdir $RESULTS_DIR/reports
file mkdir $RESULTS_DIR/gds
file mkdir $RESULTS_DIR/netlist
file mkdir $RESULTS_DIR/sdc

##############################################################################
# 2. INITIALISE DESIGN
#
# This step loads all libraries and the gate-level netlist, creates the
# internal database, and prepares the tool for floorplanning.
##############################################################################

# Read LEF files (tech LEF must be first)
read_physical -lef [list $TECH_LEF $STD_LEF $SRAM_LEF]

# Read gate-level netlist
read_netlist $NETLIST -top $DESIGN

# Source the MMMC configuration file
source /home/rah47472/asic_project/mmmc.tcl

# Commit the initialisation — pass analysis views directly
init_design -setup view_typ -hold view_typ

##############################################################################
# 3. FLOORPLAN
#
# Die area is sized to fit:
#   - 4 SRAM macros: each 236.8 × 618.3 µm
#     Arranged as 2 pairs (SRAM-A: u_lower + u_upper, SRAM-B: u_lower + u_upper)
#     Side by side horizontally → 4 × 236.8 = 947.2 µm wide, 618.3 µm tall
#   - Standard cell logic: ~73,000 µm² (Genus area report)
#   - 20% margin for routing and power grid
#
# Core utilisation: 0.60 (60% of core area used by cells + macros)
# Die: 1200 × 900 µm  (1.08 mm²)
# Core offset from die boundary: 10 µm on all sides
##############################################################################

# Create die and core area
# Units are µm as defined by tech LEF (DATABASE MICRONS 1000)
floorplan \
    -die_size_by_io_height max \
    -site CoreSite \
    -core_margins_by_ratio 0.05

# Override with explicit die size for reproducibility
create_floorplan \
    -die_size  { 1200 900 } \
    -core_size { 1180 880 } \
    -site CoreSite

##############################################################################
# 4. PLACE SRAM MACROS (hard macro placement)
#
# SRAM macro size: 236.8 × 618.3 µm
# Placement strategy:
#   Left side:  SRAM-A (u_sram_a) — u_lower at (10, 140), u_upper at (247, 140)
#   Right side: SRAM-B (u_sram_b) — u_lower at (500, 140), u_upper at (737, 140)
# All macros oriented N (default).
# 10 µm halo around each macro to prevent standard cells being placed too close.
##############################################################################

# Place SRAM-A lower macro
place_inst u_sram_a/u_lower  10.0  140.0  N
# Place SRAM-A upper macro (beside lower: 10 + 236.8 = 246.8, round to grid)
place_inst u_sram_a/u_upper  247.0 140.0  N

# Place SRAM-B lower macro
place_inst u_sram_b/u_lower  500.0 140.0  N
# Place SRAM-B upper macro
place_inst u_sram_b/u_upper  737.0 140.0  N

# Add placement blockage halos around macros (10 µm each side)
add_halo -all_blocks \
    -halo_deltas {10 10 10 10} \
    -snap_to_site true

# Lock all macros so placement optimisation does not move them
set_db [get_db insts u_sram_a/u_lower] .place_status fixed
set_db [get_db insts u_sram_a/u_upper] .place_status fixed
set_db [get_db insts u_sram_b/u_lower] .place_status fixed
set_db [get_db insts u_sram_b/u_upper] .place_status fixed

##############################################################################
# 5. POWER PLANNING
#
# IHP SG13G2 uses VDD / VSS power nets.
# Strategy:
#   - Core ring on Metal4 (wide ring around the full core area)
#   - Horizontal stripes on Metal3 every 50 µm
#   - Standard cell rails on Metal1 (connected to rows automatically)
##############################################################################

# Define global power nets
set_db add_stripes_ignore_block_check false

# Add core power ring on Metal4
add_rings \
    -nets  {VDD VSS} \
    -type  core_rings \
    -layer {top Metal4 bottom Metal4 left Metal3 right Metal3} \
    -width 2.0 \
    -spacing 1.0 \
    -offset 2.0

# Add power stripes on Metal3 (horizontal, every 50 µm)
add_stripes \
    -nets  {VDD VSS} \
    -layer Metal3 \
    -direction horizontal \
    -width 1.6 \
    -spacing 1.0 \
    -set_to_set_distance 50 \
    -start_offset 10 \
    -stop_offset 10

# Connect standard cell power rails on Metal1
sroute \
    -connect { corePin } \
    -nets {VDD VSS}

##############################################################################
# 6. PLACE STANDARD CELLS
##############################################################################

# Global placement — coarse placement using analytical engine
place_design

# Verify legality before optimisation
check_place

# Post-placement optimisation — fix timing violations where possible
# Note: WNS = −45.5 ns is architectural (non-pipelined MAC).
# opt_design will improve marginal paths but cannot fix deep structural violations.
opt_design -pre_cts

##############################################################################
# 7. CLOCK TREE SYNTHESIS (CTS)
#
# CTS builds a balanced clock distribution network from the clock port
# to all flip-flop clock pins, minimising skew and insertion delay.
##############################################################################

create_clock_tree_spec \
    -file $RESULTS_DIR/cts.spec \
    -net_name clk \
    -target_skew 0.05 \
    -buf_cells {sg13g2_buf_1 sg13g2_buf_2 sg13g2_buf_4}

ccopt_design

# Report CTS results
report_clock_timing -type skew \
    > $RESULTS_DIR/reports/cts_skew.rpt

##############################################################################
# 8. POST-CTS OPTIMISATION
##############################################################################

opt_design -post_cts_hold
opt_design -post_cts

##############################################################################
# 9. ROUTING
#
# NanoRoute performs global and detailed routing across all metal layers.
# SRAM macros are treated as blockages on all routing layers.
##############################################################################

route_design

# Post-route optimisation (fix DRC violations, improve timing)
opt_design -post_route

##############################################################################
# 10. REPORTS — timing, area, power, DRC
##############################################################################

# Setup timing
report_timing -max_paths 10 -path_type full \
    > $RESULTS_DIR/reports/timing_setup_postroute.rpt

# Hold timing
report_timing -max_paths 10 -early \
    > $RESULTS_DIR/reports/timing_hold_postroute.rpt

# Area
report_area \
    > $RESULTS_DIR/reports/area_postroute.rpt

# Power
report_power \
    > $RESULTS_DIR/reports/power_postroute.rpt

# DRC check
check_drc \
    > $RESULTS_DIR/reports/drc.rpt

# Connectivity check (no open or short nets)
check_connectivity -type all \
    > $RESULTS_DIR/reports/connectivity.rpt

# Density check
check_metal_density \
    > $RESULTS_DIR/reports/density.rpt

##############################################################################
# 11. WRITE OUTPUTS
##############################################################################

# Final gate-level netlist (with filler cells, clock buffers inserted)
write_netlist \
    $RESULTS_DIR/netlist/cnn_top_final.v \
    -top_module_first

# Final SDC (with CTS-updated clock constraints)
write_sdc \
    $RESULTS_DIR/sdc/cnn_top_final.sdc

# DEF (Design Exchange Format — full physical layout, used for verification)
write_def \
    $RESULTS_DIR/cnn_top_final.def

# GDSII (final layout for tape-out)
write_gds \
    -layer_map $LIB_ROOT/sg13g2_stdcell/lef/sg13g2_tech.lef \
    $RESULTS_DIR/gds/cnn_top_final.gds

# Innovus design database (allows re-opening without re-running)
write_db $RESULTS_DIR/cnn_top_innovus.db

##############################################################################
# 12. DONE
##############################################################################

puts ""
puts "============================================================"
puts "  Innovus P&R complete."
puts "  GDSII  : $RESULTS_DIR/gds/cnn_top_final.gds"
puts "  Netlist: $RESULTS_DIR/netlist/cnn_top_final.v"
puts "  Reports: $RESULTS_DIR/reports/"
puts "============================================================"
puts ""