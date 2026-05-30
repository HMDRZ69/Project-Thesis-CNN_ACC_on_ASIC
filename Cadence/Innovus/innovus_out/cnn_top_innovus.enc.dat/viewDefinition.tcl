if {![namespace exists ::IMEX]} { namespace eval ::IMEX {} }
set ::IMEX::dataVar [file dirname [file normalize [info script]]]
set ::IMEX::libVar ${::IMEX::dataVar}/libs

create_library_set -name libs_typ\
   -timing\
    [list ${::IMEX::libVar}/mmmc/sg13g2_stdcell_typ_1p20V_25C.lib\
    ${::IMEX::libVar}/mmmc/RM_IHPSG13_1P_4096x8_c3_bm_bist_typ_1p20V_25C.lib]
create_rc_corner -name rc_typ\
   -pre_route_res 1\
   -post_route_res 1\
   -pre_route_cap 1\
   -post_route_cap 1\
   -post_route_cross_cap 1\
   -pre_route_clock_res 0\
   -pre_route_clock_cap 0
create_timing_condition -name default_mapping_tc_0\
   -library_sets [list libs_typ]
create_delay_corner -name corner_typ\
   -timing_condition {default_mapping_tc_0}\
   -rc_corner rc_typ
create_constraint_mode -name func_mode\
   -sdc_files\
    [list ${::IMEX::dataVar}/mmmc/modes/func_mode/func_mode.sdc]
create_analysis_view -name view_typ -constraint_mode func_mode -delay_corner corner_typ -latency_file ${::IMEX::dataVar}/mmmc/views/view_typ/latency.sdc
set_analysis_view -setup [list view_typ] -hold [list view_typ]
