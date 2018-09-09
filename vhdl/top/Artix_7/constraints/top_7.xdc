#clk_ztex
set_property PACKAGE_PIN Y18 [get_ports clk_ztex]
set_property IOSTANDARD LVCMOS33 [get_ports clk_ztex]
#reset (PC0)
set_property PACKAGE_PIN L20 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]
#clk_reset (PC1)
set_property PACKAGE_PIN L19 [get_ports clk_reset]
set_property IOSTANDARD LVCMOS33 [get_ports clk_reset]
#clken_n (PC2)
set_property PACKAGE_PIN L18 [get_ports clken_n]
set_property IOSTANDARD LVCMOS33 [get_ports clken_n]
#ifclk
set_property PACKAGE_PIN J19 [get_ports ifclk]
set_property IOSTANDARD LVCMOS33 [get_ports ifclk]
#FIFO DATA
#fifo_data(0) (PB0)
set_property PACKAGE_PIN P20 [get_ports {fifo_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fifo_data[0]}]
set_property DRIVE 12 [get_ports {fifo_data[0]}]
#fifo_data(1) (PB1)
set_property PACKAGE_PIN N17 [get_ports {fifo_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fifo_data[1]}]
set_property DRIVE 12 [get_ports {fifo_data[1]}]
#fifo_data(2) (PB2)
set_property PACKAGE_PIN P21 [get_ports {fifo_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fifo_data[2]}]
set_property DRIVE 12 [get_ports {fifo_data[2]}]
#fifo_data(3) (PB3)
set_property PACKAGE_PIN R21 [get_ports {fifo_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fifo_data[3]}]
set_property DRIVE 12 [get_ports {fifo_data[3]}]
#fifo_data(4) (PB4)
set_property PACKAGE_PIN T21 [get_ports {fifo_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fifo_data[4]}]
set_property DRIVE 12 [get_ports {fifo_data[4]}]
#fifo_data(5) (PB5)
set_property PACKAGE_PIN U21 [get_ports {fifo_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fifo_data[5]}]
set_property DRIVE 12 [get_ports {fifo_data[5]}]
#fifo_data(6) (PB6)
set_property PACKAGE_PIN P19 [get_ports {fifo_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fifo_data[6]}]
set_property DRIVE 12 [get_ports {fifo_data[6]}]
#fifo_data(7) (PB7)
set_property PACKAGE_PIN R19 [get_ports {fifo_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fifo_data[7]}]
set_property DRIVE 12 [get_ports {fifo_data[7]}]
#fifo2_empty (FLAG A)
set_property PACKAGE_PIN K19 [get_ports fifo2_empty]
set_property IOSTANDARD LVCMOS33 [get_ports fifo2_empty]
#fifo4_empty (FLAG B)
set_property PACKAGE_PIN K18 [get_ports fifo4_empty]
set_property IOSTANDARD LVCMOS33 [get_ports fifo4_empty]
#fifo6_empty (FLAG C)
set_property PACKAGE_PIN L21 [get_ports fifo6_empty]
set_property IOSTANDARD LVCMOS33 [get_ports fifo6_empty]
#fifo6_pf (FLAG D)
set_property PACKAGE_PIN R18 [get_ports fifo6_pf]
set_property IOSTANDARD LVCMOS33 [get_ports fifo6_pf]
#FIFO CONTROL
#fifo_addr(0) (PA4)
set_property PACKAGE_PIN N19 [get_ports {fifo_addr[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fifo_addr[0]}]
set_property DRIVE 12 [get_ports {fifo_addr[0]}]
#fifo_addr(1) (PA5)
set_property PACKAGE_PIN N18 [get_ports {fifo_addr[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fifo_addr[1]}]
set_property DRIVE 12 [get_ports {fifo_addr[1]}]
#sloe (PA2)
set_property PACKAGE_PIN M20 [get_ports sloe]
set_property IOSTANDARD LVCMOS33 [get_ports sloe]
set_property DRIVE 12 [get_ports sloe]
#slrd
set_property PACKAGE_PIN AB22 [get_ports slrd]
set_property IOSTANDARD LVCMOS33 [get_ports slrd]
set_property DRIVE 12 [get_ports slrd]
#slwr
set_property PACKAGE_PIN AB21 [get_ports slwr]
set_property IOSTANDARD LVCMOS33 [get_ports slwr]
set_property DRIVE 12 [get_ports slwr]
#pktend (PA6)
set_property PACKAGE_PIN P17 [get_ports pktend]
set_property IOSTANDARD LVCMOS33 [get_ports pktend]
set_property DRIVE 12 [get_ports pktend]


#Timing Constrains of clk input Signals
create_clock -period 33.333 -name ifclk [get_ports ifclk]
create_clock -period 20.833 -name clk_ztex [get_ports clk_ztex]

#Set ifclk as Asynchronous clock
#All paths between ifclk and all other clocks are ignored
set_clock_groups -name clk_domain_crossing -asynchronous -group ifclk

#Ignore clk crossing between MMCM outputs (It cannot happen because of BUFGMUX)
set_clock_groups -name mmcm_output_exclusive -physically_exclusive -group clk0 -group clk1

#Specific Timing Constraints
#INPUT CONSTRAINTS
#FIFO DATA Setup=11ns
set_input_delay -clock ifclk -max 11.000 [get_ports {{fifo_data[0]} {fifo_data[1]} {fifo_data[2]} {fifo_data[3]} {fifo_data[4]} {fifo_data[5]} {fifo_data[6]} {fifo_data[7]}}]
#FLAGS Setup=9.5ns
set_input_delay -clock ifclk -max 9.500 [get_ports {fifo4_empty fifo6_empty fifo6_pf fifo2_empty}]

##OUTPUT CONSTRAINTS
#FIFO DATA Setup=9.2ns Hold=0ns
set_output_delay -clock ifclk -max 9.200 [get_ports {{fifo_data[0]} {fifo_data[1]} {fifo_data[2]} {fifo_data[3]} {fifo_data[4]} {fifo_data[5]} {fifo_data[6]} {fifo_data[7]}}]
set_output_delay -clock ifclk -min 0.000 [get_ports {{fifo_data[0]} {fifo_data[1]} {fifo_data[2]} {fifo_data[3]} {fifo_data[4]} {fifo_data[5]} {fifo_data[6]} {fifo_data[7]}}]
#PKTEND Setup=14.6ns Hold=0ns
set_output_delay -clock ifclk -max 14.600 [get_ports pktend]
set_output_delay -clock ifclk -min 0.000 [get_ports pktend]
#SLOE Setup=19.7ns (CUSTOM)
set_output_delay -clock ifclk -max 19.700 [get_ports sloe]
#SLRD Setup=18.7ns Hold=0ns
set_output_delay -clock ifclk -max 18.700 [get_ports slrd]
set_output_delay -clock ifclk -min 0.000 [get_ports slrd]
#SLWR Setup=18.1ns Hold=0ns
set_output_delay -clock ifclk -max 18.100 [get_ports slwr]
set_output_delay -clock ifclk -min 0.000 [get_ports slwr]
#FIFO_ADDR Hold=10ns (Setup is 25ns, but it's longer than the period, so it is set in the clk before)
set_output_delay -clock ifclk -min 10.000 [get_ports {{fifo_addr[0]} {fifo_addr[1]}}]

#PORTED TIMING CONSTRAINTS
#Input Timing Constraints
#set_input_delay -clock [get_clocks ifclk] -max 18.333 -add_delay [get_ports [list fifo4_empty fifo6_empty fifo6_pf {fifo_data[0]} {fifo_data[1]} {fifo_data[2]} {fifo_data[3]} {fifo_data[4]} {fifo_data[5]} {fifo_data[6]} {fifo_data[7]} fifo2_empty]]
# OFFSET specified with no VALID keyword, inferring one to yield a zero hold time
#set_input_delay -clock [get_clocks ifclk] -min 0.000 -add_delay [get_ports [list fifo4_empty fifo6_empty fifo6_pf {fifo_data[0]} {fifo_data[1]} {fifo_data[2]} {fifo_data[3]} {fifo_data[4]} {fifo_data[5]} {fifo_data[6]} {fifo_data[7]} fifo2_empty]]
#set_false_path -rise_from [get_clocks ifclk] -through [get_ports [list fifo4_empty fifo6_empty fifo6_pf {fifo_data[0]} {fifo_data[1]} {fifo_data[2]} {fifo_data[3]} {fifo_data[4]} {fifo_data[5]} {fifo_data[6]} {fifo_data[7]} fifo2_empty]] -fall_to [get_clocks ifclk]

#Output Timing Constraints
#set_output_delay -clock [get_clocks ifclk] -add_delay 15.333 [get_ports [list {fifo_addr[1]} {fifo_data[0]} {fifo_data[1]} {fifo_data[2]} {fifo_data[3]} {fifo_data[4]} {fifo_data[5]} {fifo_data[6]} {fifo_data[7]} pktend sloe slrd slwr {fifo_addr[0]}]]

#Ignore Timing on Latched Control Signals
set_false_path -through [get_nets clken_n_buf*]
set_false_path -through [get_nets clk_reset_buf*]
set_false_path -through [get_nets reset_buf*]

#Ignore Timing of core_control_unit Output Signals (found, done, key_out)
set_false_path -from [all_fanin -startpoints_only [get_pins fpga_top_inst/*/found]]
set_false_path -from [all_fanin -startpoints_only [get_pins fpga_top_inst/*/done]]
set_false_path -from [all_fanin -startpoints_only [get_pins fpga_top_inst/*/key_out*]]

#Ignore Timing of core_control_unit Input Signals (cipher, start_cw/stop_cw)
set_false_path -to [all_fanout -endpoints_only [get_pins fpga_top_inst/*/start_cw*]]
set_false_path -to [all_fanout -endpoints_only [get_pins fpga_top_inst/*/cipher*]]

#Unsuccessful Floorplanning
#create_pblock {pblock_cr_gn[0].frst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[1].rst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[3].rst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[5].rst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[7].rst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[9].rst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[1].rst_itr.cr_cntrl_unt_inst_1}
#create_pblock {pblock_cr_gn[14].rst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[15].rst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[2].rst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[4].rst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[6].rst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[8].rst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[10].rst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[12].rst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[13].rst_itr.cr_cntrl_unt_inst}
#create_pblock {pblock_cr_gn[16].rst_itr.cr_cntrl_unt_inst}
#create_pblock pblock_core0
#add_cells_to_pblock [get_pblocks pblock_core0] [get_cells -quiet [list {fpga_top_inst/core_gen[0].first_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core0] -add {SLICE_X114Y0:SLICE_X163Y38}
#resize_pblock [get_pblocks pblock_core0] -add {DSP48_X7Y0:DSP48_X8Y13}
#resize_pblock [get_pblocks pblock_core0] -add {RAMB18_X7Y0:RAMB18_X8Y13}
#resize_pblock [get_pblocks pblock_core0] -add {RAMB36_X7Y0:RAMB36_X8Y6}
#create_pblock pblock_core1
#add_cells_to_pblock [get_pblocks pblock_core1] [get_cells -quiet [list {fpga_top_inst/core_gen[1].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core1] -add {SLICE_X114Y39:SLICE_X163Y77}
#resize_pblock [get_pblocks pblock_core1] -add {DSP48_X7Y16:DSP48_X8Y29}
#resize_pblock [get_pblocks pblock_core1] -add {RAMB18_X7Y16:RAMB18_X8Y29}
#resize_pblock [get_pblocks pblock_core1] -add {RAMB36_X7Y8:RAMB36_X8Y14}
#create_pblock pblock_core2
#add_cells_to_pblock [get_pblocks pblock_core2] [get_cells -quiet [list {fpga_top_inst/core_gen[2].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core2] -add {SLICE_X122Y78:SLICE_X163Y125}
#resize_pblock [get_pblocks pblock_core2] -add {DSP48_X7Y32:DSP48_X8Y49}
#resize_pblock [get_pblocks pblock_core2] -add {RAMB18_X7Y32:RAMB18_X8Y49}
#resize_pblock [get_pblocks pblock_core2] -add {RAMB36_X7Y16:RAMB36_X8Y24}
#create_pblock pblock_core3
#add_cells_to_pblock [get_pblocks pblock_core3] [get_cells -quiet [list {fpga_top_inst/core_gen[3].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core3] -add {SLICE_X122Y126:SLICE_X163Y171}
#resize_pblock [get_pblocks pblock_core3] -add {DSP48_X7Y52:DSP48_X8Y67}
#resize_pblock [get_pblocks pblock_core3] -add {RAMB18_X7Y52:RAMB18_X8Y67}
#resize_pblock [get_pblocks pblock_core3] -add {RAMB36_X7Y26:RAMB36_X8Y33}
#create_pblock pblock_core4
#add_cells_to_pblock [get_pblocks pblock_core4] [get_cells -quiet [list {fpga_top_inst/core_gen[4].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core4] -add {SLICE_X112Y172:SLICE_X163Y209}
#resize_pblock [get_pblocks pblock_core4] -add {DSP48_X7Y70:DSP48_X8Y83}
#resize_pblock [get_pblocks pblock_core4] -add {RAMB18_X7Y70:RAMB18_X8Y83}
#resize_pblock [get_pblocks pblock_core4] -add {RAMB36_X7Y35:RAMB36_X8Y41}
#create_pblock pblock_core5
#add_cells_to_pblock [get_pblocks pblock_core5] [get_cells -quiet [list {fpga_top_inst/core_gen[5].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core5] -add {SLICE_X114Y210:SLICE_X163Y248}
#resize_pblock [get_pblocks pblock_core5] -add {DSP48_X7Y84:DSP48_X8Y97}
#resize_pblock [get_pblocks pblock_core5] -add {RAMB18_X7Y84:RAMB18_X8Y97}
#resize_pblock [get_pblocks pblock_core5] -add {RAMB36_X7Y42:RAMB36_X8Y48}
#create_pblock pblock_core6
#add_cells_to_pblock [get_pblocks pblock_core6] [get_cells -quiet [list {fpga_top_inst/core_gen[6].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core6] -add {SLICE_X112Y156:SLICE_X121Y171 SLICE_X72Y156:SLICE_X111Y199}
#resize_pblock [get_pblocks pblock_core6] -add {DSP48_X4Y64:DSP48_X6Y79}
#resize_pblock [get_pblocks pblock_core6] -add {RAMB18_X4Y64:RAMB18_X6Y79}
#resize_pblock [get_pblocks pblock_core6] -add {RAMB36_X4Y32:RAMB36_X6Y39}
#create_pblock pblock_core7
#add_cells_to_pblock [get_pblocks pblock_core7] [get_cells -quiet [list {fpga_top_inst/core_gen[7].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core7] -add {SLICE_X72Y117:SLICE_X121Y155}
#resize_pblock [get_pblocks pblock_core7] -add {DSP48_X4Y48:DSP48_X6Y61}
#resize_pblock [get_pblocks pblock_core7] -add {RAMB18_X4Y48:RAMB18_X6Y61}
#resize_pblock [get_pblocks pblock_core7] -add {RAMB36_X4Y24:RAMB36_X6Y30}
#create_pblock pblock_core8
#add_cells_to_pblock [get_pblocks pblock_core8] [get_cells -quiet [list {fpga_top_inst/core_gen[8].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core8] -add {SLICE_X72Y78:SLICE_X121Y116}
#resize_pblock [get_pblocks pblock_core8] -add {DSP48_X4Y32:DSP48_X6Y45}
#resize_pblock [get_pblocks pblock_core8] -add {RAMB18_X4Y32:RAMB18_X6Y45}
#resize_pblock [get_pblocks pblock_core8] -add {RAMB36_X4Y16:RAMB36_X6Y22}
#create_pblock pblock_core9
#add_cells_to_pblock [get_pblocks pblock_core9] [get_cells -quiet [list {fpga_top_inst/core_gen[9].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core9] -add {SLICE_X46Y50:SLICE_X113Y77}
#resize_pblock [get_pblocks pblock_core9] -add {DSP48_X3Y20:DSP48_X6Y29}
#resize_pblock [get_pblocks pblock_core9] -add {RAMB18_X3Y20:RAMB18_X6Y29}
#resize_pblock [get_pblocks pblock_core9] -add {RAMB36_X3Y10:RAMB36_X6Y14}
#create_pblock pblock_core10
#add_cells_to_pblock [get_pblocks pblock_core10] [get_cells -quiet [list {fpga_top_inst/core_gen[10].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core10] -add {SLICE_X26Y50:SLICE_X45Y77 SLICE_X24Y0:SLICE_X51Y49}
#resize_pblock [get_pblocks pblock_core10] -add {DSP48_X2Y0:DSP48_X2Y29}
#resize_pblock [get_pblocks pblock_core10] -add {RAMB18_X2Y0:RAMB18_X2Y29}
#resize_pblock [get_pblocks pblock_core10] -add {RAMB36_X2Y0:RAMB36_X2Y14}
#create_pblock pblock_core11
#add_cells_to_pblock [get_pblocks pblock_core11] [get_cells -quiet [list {fpga_top_inst/core_gen[11].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core11] -add {SLICE_X24Y50:SLICE_X25Y77 SLICE_X0Y0:SLICE_X23Y77}
#resize_pblock [get_pblocks pblock_core11] -add {DSP48_X0Y0:DSP48_X1Y29}
#resize_pblock [get_pblocks pblock_core11] -add {RAMB18_X0Y0:RAMB18_X1Y29}
#resize_pblock [get_pblocks pblock_core11] -add {RAMB36_X0Y0:RAMB36_X1Y14}
#create_pblock pblock_core12
#add_cells_to_pblock [get_pblocks pblock_core12] [get_cells -quiet [list {fpga_top_inst/core_gen[12].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core12] -add {SLICE_X24Y78:SLICE_X55Y99 SLICE_X0Y78:SLICE_X23Y128}
#resize_pblock [get_pblocks pblock_core12] -add {DSP48_X2Y32:DSP48_X2Y39 DSP48_X0Y32:DSP48_X1Y49}
#resize_pblock [get_pblocks pblock_core12] -add {RAMB18_X2Y32:RAMB18_X2Y39 RAMB18_X0Y32:RAMB18_X1Y49}
#resize_pblock [get_pblocks pblock_core12] -add {RAMB36_X2Y16:RAMB36_X2Y19 RAMB36_X0Y16:RAMB36_X1Y24}
#create_pblock pblock_core13
#add_cells_to_pblock [get_pblocks pblock_core13] [get_cells -quiet [list {fpga_top_inst/core_gen[13].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core13] -add {SLICE_X56Y78:SLICE_X71Y144 SLICE_X36Y100:SLICE_X55Y144}
#resize_pblock [get_pblocks pblock_core13] -add {DSP48_X3Y32:DSP48_X3Y57 DSP48_X2Y40:DSP48_X2Y57}
#resize_pblock [get_pblocks pblock_core13] -add {RAMB18_X3Y32:RAMB18_X3Y57 RAMB18_X2Y40:RAMB18_X2Y57}
#resize_pblock [get_pblocks pblock_core13] -add {RAMB36_X3Y16:RAMB36_X3Y28 RAMB36_X2Y20:RAMB36_X2Y28}
#create_pblock pblock_core14
#add_cells_to_pblock [get_pblocks pblock_core14] [get_cells -quiet [list {fpga_top_inst/core_gen[14].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core14] -add {SLICE_X36Y145:SLICE_X71Y199}
#resize_pblock [get_pblocks pblock_core14] -add {DSP48_X2Y58:DSP48_X3Y79}
#resize_pblock [get_pblocks pblock_core14] -add {RAMB18_X2Y58:RAMB18_X3Y79}
#resize_pblock [get_pblocks pblock_core14] -add {RAMB36_X2Y29:RAMB36_X3Y39}
#create_pblock pblock_core15
#add_cells_to_pblock [get_pblocks pblock_core15] [get_cells -quiet [list {fpga_top_inst/core_gen[15].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core15] -add {SLICE_X10Y200:SLICE_X51Y249}
#resize_pblock [get_pblocks pblock_core15] -add {DSP48_X0Y80:DSP48_X2Y99}
#resize_pblock [get_pblocks pblock_core15] -add {RAMB18_X1Y80:RAMB18_X2Y99}
#resize_pblock [get_pblocks pblock_core15] -add {RAMB36_X1Y40:RAMB36_X2Y49}
#create_pblock pblock_core16
#add_cells_to_pblock [get_pblocks pblock_core16] [get_cells -quiet [list {fpga_top_inst/core_gen[16].rest_iter.core_control_unit_inst}]]
#resize_pblock [get_pblocks pblock_core16] -add {SLICE_X10Y129:SLICE_X23Y199 SLICE_X0Y129:SLICE_X9Y249}
#resize_pblock [get_pblocks pblock_core16] -add {DSP48_X0Y52:DSP48_X1Y79}
#resize_pblock [get_pblocks pblock_core16] -add {RAMB18_X1Y52:RAMB18_X1Y79 RAMB18_X0Y52:RAMB18_X0Y99}
#resize_pblock [get_pblocks pblock_core16] -add {RAMB36_X1Y26:RAMB36_X1Y39 RAMB36_X0Y26:RAMB36_X0Y49}