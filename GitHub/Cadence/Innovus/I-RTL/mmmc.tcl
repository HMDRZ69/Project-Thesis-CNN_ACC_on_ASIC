create_library_set -name libs_typ \
    -timing {
        /home/rah47472/asic_project/libs/OpenFPGA/Fabric/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib
        /home/rah47472/asic_project/libs/OpenFPGA/Fabric/ihp-sg13g2/libs.ref/sg13g2_sram/lib/RM_IHPSG13_1P_4096x8_c3_bm_bist_typ_1p20V_25C.lib
    }

create_rc_corner -name rc_typ \
    -preRoute_res  1.0 \
    -preRoute_cap  1.0 \
    -postRoute_res 1.0 \
    -postRoute_cap 1.0 \
    -postRoute_xcap 1.0

create_delay_corner \
    -name corner_typ \
    -library_set libs_typ \
    -rc_corner rc_typ

create_constraint_mode -name func_mode \
    -sdc_files {/home/rah47472/asic_project/genus_out/sdc/cnn_top.sdc}

create_analysis_view -name view_typ \
    -constraint_mode func_mode \
    -delay_corner corner_typ