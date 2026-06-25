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
# Uses the legacy init_design flow with init_mmmc_file.
#
# Why: The read_physical + source mmmc.tcl + read_netlist split approach
# fails in Innovus 23.31 because:
#   - source mmmc.tcl before setDesignMode: MMMC views created in MMMC-1
#     context are not picked up by read_netlist's auto-init (physical-only mode)
#   - source mmmc.tcl after setDesignMode: all create_* commands rejected
#     with TCLCMD-1763 (MMMC-1 options in MMMC-2 mode)
#
# Solution: set init_* variables and call init_design once. Innovus handles
# LEF, netlist, and MMMC file internally in the correct sequence, ensuring
# timing libraries are properly associated with the design at init time.
# This matches the documented working approach in the project notes.
##############################################################################

set init_lef_file         [list $TECH_LEF $STD_LEF $SRAM_LEF]
set init_mmmc_file        /home/rah47472/asic_project/mmmc.tcl
set init_verilog          $NETLIST
set init_top_cell         $DESIGN
set init_design_netlisttype Verilog

init_design -setup view_typ -hold view_typ

# Set process node after init_design (must not precede it — setDesignMode
# activates MMMC-2 and breaks the init_mmmc_file mechanism if called first)
setDesignMode -process 130

# Activate analysis views
set_analysis_view \
    -setup {view_typ} \
    -hold  {view_typ}

# Sanity check timing configuration before floorplanning
report_analysis_view
check_timing

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
# Units: µm (DATABASE MICRONS 1000 as per tech LEF)
# Die  : 1200 × 900 µm
# Core : 10 µm margin on all four sides → 1180 × 880 µm
# floorPlan is the correct Innovus 23.31 command.
# -r sets utilisation ratio, -s sets die dimensions explicitly.
# -core_margin_t/b/l/r set core boundary offsets from die edge.
floorPlan -site CoreSite -s 1200 900 10 10 10 10

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
placeInstance u_sram_a/u_lower  10.0  140.0  R0
# Place SRAM-A upper macro (beside lower: 10 + 236.8 = 246.8, round to grid)
placeInstance u_sram_a/u_upper  247.0 140.0  R0

# Place SRAM-B lower macro
placeInstance u_sram_b/u_lower  500.0 140.0  R0
# Place SRAM-B upper macro
placeInstance u_sram_b/u_upper  737.0 140.0  R0

# Add 10 µm placement halo around all macros.
# Syntax: addHaloToBlock <left bottom right top> [inst | -allMacro]
addHaloToBlock 10 10 10 10 -allMacro

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

# Create VDD and VSS as power/ground nets.
# addNet is the correct Innovus Tcl API for creating special nets
# when they are not present in the Verilog netlist (implicit pg_pins only).
addNet VDD -power
addNet VSS -ground

# Connect all pg_pins and tie cells to the declared power nets
globalNetConnect VDD -type pgpin -pin VDD -all -override
globalNetConnect VSS -type pgpin -pin VSS -all -override
globalNetConnect VDD -type tiehi -all -override
globalNetConnect VSS -type tielo -all -override

# Add core power ring on Metal4
addRing \
    -nets  {VDD VSS} \
    -type  core_rings \
    -layer {top Metal4 bottom Metal4 left Metal3 right Metal3} \
    -width 2.0 \
    -spacing 1.0 \
    -offset 2.0

# Add power stripes on Metal3 (horizontal, every 50 µm)
addStripe \
    -nets  {VDD VSS} \
    -layer Metal3 \
    -direction horizontal \
    -width 1.6 \
    -spacing 1.0 \
    -set_to_set_distance 50 \
    -start_offset 10 \
    -stop_offset 10

# Connect standard cell power rails (corePin) and macro power pins (blockPin)
# blockPin routes power to SRAM macro VDD/VSS pins which sroute previously left open
sroute \
    -connect { corePin blockPin } \
    -nets    {VDD VSS}

##############################################################################
# 6. PLACE STANDARD CELLS
##############################################################################

# Standard cell placement
place_design

# Verify legality before optimisation
catch {check_place}

# Post-placement optimisation
optDesign -preCTS

# CHECKPOINT: save after placement + preCTS opt so this work is never lost
saveDesign $RESULTS_DIR/checkpoints/cnn_top_placed.enc

##############################################################################
# 7. CLOCK TREE SYNTHESIS (CTS)
##############################################################################

catch {set_ccopt_property target_max_trans 0.15}
catch {set_ccopt_property buffer_cells  {sg13g2_buf_1 sg13g2_buf_2 sg13g2_buf_4}}
catch {set_ccopt_property inverter_cells {sg13g2_inv_1 sg13g2_inv_2 sg13g2_inv_4}}

clock_opt_design

# CHECKPOINT: save after CTS
saveDesign $RESULTS_DIR/checkpoints/cnn_top_cts.enc

catch {
    report_clock_timing -type skew
}

##############################################################################
# 8. POST-CTS OPTIMISATION
##############################################################################

optDesign -postCTS
optDesign -postCTS -hold

##############################################################################
# 9. ROUTING
##############################################################################

routeDesign

# Post-route optimisation
# Post-route optimisation requires OCV timing mode for SI analysis.
# setAnalysisMode -analysisType onChipVariation enables this.
setAnalysisMode -analysisType onChipVariation
optDesign -postRoute

# CHECKPOINT: save after routing
saveDesign $RESULTS_DIR/checkpoints/cnn_top_routed.enc

##############################################################################
# 10. REPORTS — timing, area, power, DRC
# All wrapped in catch so a single bad report command cannot abort the flow.
# The critical output is the GDSII — reports are secondary.
##############################################################################

catch {
    report_timing -max_paths 10 -path_type full
}
catch {
    report_timing -max_paths 10 -early
}
catch {
    report_area \
        -out_file $RESULTS_DIR/reports/area_postroute.rpt
}
catch {
    report_power \
        -outfile $RESULTS_DIR/reports/power_postroute.rpt
}

# DRC check — verify_drc and -report confirmed valid from interactive help
verify_drc \
    -report $RESULTS_DIR/reports/drc.rpt

catch {
    check_connectivity -type all \
        -out_file $RESULTS_DIR/reports/connectivity.rpt
}
catch {
    check_metal_density \
        -report $RESULTS_DIR/reports/density.rpt
}

##############################################################################
# 11. WRITE OUTPUTS
##############################################################################

# Final gate-level netlist — saveNetlist and -topModuleFirst confirmed valid
saveNetlist \
    $RESULTS_DIR/netlist/cnn_top_final.v \
    -topModuleFirst

# Final SDC
catch {
    write_sdc $RESULTS_DIR/sdc/cnn_top_final.sdc
}

# DEF
catch {
    write_def $RESULTS_DIR/cnn_top_final.def
}

# GDSII (final layout for tape-out)
#
# IMPORTANT: -layer_map must point to the Innovus GDS layer map file,
# NOT the tech LEF. The correct file is typically:
#   $LIB_ROOT/sg13g2_stdcell/lef/sg13g2.layermap   (if it exists), or
#   a .map file provided in libs.tech/innovus/ of the IHP PDK.

set GDS_LAYERMAP /home/rah47472/pdk/ihp/sg13g2/SG13G2_618_rev1.3.2/lib/SG13_dev/SG13G2.layermap
set STD_GDS     $LIB_ROOT/sg13g2_stdcell/gds/sg13g2_stdcell.gds
set SRAM_GDS    $LIB_ROOT/sg13g2_sram/gds/RM_IHPSG13_1P_4096x8_c3_bm_bist.gds

if {[file exists $GDS_LAYERMAP]} {
    streamOut $RESULTS_DIR/gds/cnn_top_final.gds \
        -mapFile $GDS_LAYERMAP \
        -libName cnn_top \
        -units   1000 \
        -merge   [list $STD_GDS $SRAM_GDS]
} else {
    puts "WARNING: GDS layer map not found at $GDS_LAYERMAP"
    streamOut $RESULTS_DIR/gds/cnn_top_final.gds \
        -libName cnn_top \
        -units   1000 \
        -merge   [list $STD_GDS $SRAM_GDS]
}

# Innovus design database (allows re-opening without re-running)
catch {saveDesign $RESULTS_DIR/cnn_top_innovus.enc -mmmc2}

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

# Write DEF for re-loading the layout in Innovus or other tools
catch {
    write_def $RESULTS_DIR/cnn_top_final.def
    puts "  DEF    : $RESULTS_DIR/cnn_top_final.def"
}

##############################################################################
# 13. OPEN GUI FOR LAYOUT INSPECTION
# win   : opens the Innovus layout GUI
# suspend: pauses the script so you can interact with the layout
#          Type 'resume' in the terminal to continue/exit when done
##############################################################################
win
suspend