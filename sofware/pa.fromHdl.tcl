
# PlanAhead Launch Script for Pre-Synthesis Floorplanning, created by Project Navigator

create_project -name GTIA -dir "/mnt/data/projekty/VHDL/GTIA/planAhead_run_1" -part xc6slx25ftg256-3
set_param project.pinAheadLayout yes
set srcset [get_property srcset [current_run -impl]]
set_property target_constrs_file "miniSpartan6-plus.ucf" [current_fileset -constrset]
set hdlfile [add_files [list {gtia.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {vga_out.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {Serializer_10_1.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {pmg.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {gtia_palette.vhdl}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {DVI_OUT.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {Component_encoder.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {clocks.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {CLOCK.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set_property top gtia $srcset
add_files [list {miniSpartan6-plus.ucf}] -fileset [get_property constrset [current_run]]
open_rtl_design -part xc6slx25ftg256-3
