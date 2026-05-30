if {![namespace exists ::IMEX]} { namespace eval ::IMEX {} }
set ::IMEX::dataVar [file dirname [file normalize [info script]]]
set ::IMEX::libVar ${::IMEX::dataVar}/libs

create_library_set -name libs_typ\
   -timing\
    [list ${::IMEX::libVar}/mmmc/sg13g2_stdcell_typ_1p20V_25C.lib\
    ${::IMEX::libVar}/mmmc/RM_IHPSG13_1P_4096x8_c3_bm_bist_typ_1p20V_25C.lib]
create_rc_corner -name rc_typ\
   -preRoute_res 1\
   -postRoute_res 1\
   -preRoute_cap 1\
   -postRoute_cap 1\
   -postRoute_xcap 1\
   -preRoute_clkres 0\
   -preRoute_clkcap 0
create_delay_corner -name corner_typ\
   -library_set libs_typ\
   -rc_corner rc_typ
create_constraint_mode -name func_mode\
   -sdc_files\
    [list ${::IMEX::dataVar}/mmmc/modes/func_mode/func_mode.sdc]
create_analysis_view -name view_typ -constraint_mode func_mode -delay_corner corner_typ -latency_file ${::IMEX::dataVar}/mmmc/views/view_typ/latency.sdc
set_analysis_view -setup [list view_typ] -hold [list view_typ]
