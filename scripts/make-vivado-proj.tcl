# Creates a Vivado project ready for synthesis and launches bitstream generation
if {$argc != 5} {
  puts "Expected: <proj_name> <proj_dir> <xdc_dir> <ip_repo> <log2_quantization_bits>"
  exit
}

# project name, target dir and FPGA part to use
set config_proj_name [lindex $argv 0]
set config_proj_dir [lindex $argv 1]
set config_proj_part "xc7z020clg400-1"

# other project config

set xdc_dir [lindex $argv 2]
set ip_repo [lindex $argv 3]
set log2_quantization_bits [lindex $argv 4]

puts "config_proj_name: ${config_proj_name}"
puts "config_proj_dir: ${config_proj_dir}"
puts "xdc_dir:  ${xdc_dir}"
puts "ip_repo: ${ip_repo}"
puts "log2_quantization_bits: ${log2_quantization_bits}"

# set up project
create_project -force $config_proj_name $config_proj_dir -part $config_proj_part

#Add PYNQ XDC
add_files -fileset constrs_1 -norecurse "${xdc_dir}/PYNQ-Z1_C.xdc"

set_property  ip_repo_paths $ip_repo [current_project]
update_ip_catalog

# # create block design
# create_bd_design "procsys"
# create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
# set ps7 [get_bd_cells ps7]
# apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable" } $ps7
# source "${xdc_dir}/pynq_revC.tcl"

# set_property -dict [apply_preset $ps7] $ps7
# set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {142.86} CONFIG.PCW_FPGA2_PERIPHERAL_FREQMHZ {200} CONFIG.PCW_FPGA3_PERIPHERAL_FREQMHZ {166.67} CONFIG.PCW_EN_CLK1_PORT {1} CONFIG.PCW_EN_CLK2_PORT {1} CONFIG.PCW_EN_CLK3_PORT {1} CONFIG.PCW_USE_M_AXI_GP0 {1} CONFIG.PCW_USE_S_AXI_HP0 {1}] $ps7

# save_bd_design

source "${xdc_dir}/procsys.tcl"

if {$log2_quantization_bits == -1} {
	set floatFSGD_0 [ create_bd_cell -type ip -vlnv xilinx.com:SGD:floatFSGD:1.0 floatFSGD_0 ]
	set_property -dict [ list \
		CONFIG.LOG2_S_AXIS_DATA_WIDTH {6} \
		CONFIG.LOG2_MAX_DIMENSION {12} \
	] $floatFSGD_0
	
	connect_bd_intf_net -intf_net floatFSGD_0_m_axis [get_bd_intf_pins floatFSGD_0/m_axis] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]
	connect_bd_intf_net -intf_net axi_dma_0_M_AXIS_MM2S [get_bd_intf_pins floatFSGD_0/s_axis] [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S]
	connect_bd_net -net floatFSGD_0_done [get_bd_ports led_green] [get_bd_pins floatFSGD_0/done] [get_bd_pins xlconcat_0/In0]
	connect_bd_net -net ps7_FCLK_CLK0 [get_bd_pins floatFSGD_0/clk] [get_bd_pins axi_dma_0/m_axi_mm2s_aclk] [get_bd_pins axi_dma_0/m_axi_s2mm_aclk] [get_bd_pins axi_dma_0/s_axi_lite_aclk] [get_bd_pins axi_gpio_0/s_axi_aclk] [get_bd_pins axi_mem_intercon/ACLK] [get_bd_pins axi_mem_intercon/M00_ACLK] [get_bd_pins axi_mem_intercon/S00_ACLK] [get_bd_pins axi_mem_intercon_1/ACLK] [get_bd_pins axi_mem_intercon_1/M00_ACLK] [get_bd_pins axi_mem_intercon_1/S00_ACLK] [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins ps7/M_AXI_GP0_ACLK] [get_bd_pins ps7/S_AXI_HP0_ACLK] [get_bd_pins ps7/S_AXI_HP1_ACLK] [get_bd_pins ps7_axi_periph/ACLK] [get_bd_pins ps7_axi_periph/M00_ACLK] [get_bd_pins ps7_axi_periph/M01_ACLK] [get_bd_pins ps7_axi_periph/S00_ACLK] [get_bd_pins rst_ps7_100M/slowest_sync_clk]
	connect_bd_net -net xlslice_0_Dout [get_bd_ports led_blue] [get_bd_pins floatFSGD_0/resetn] [get_bd_pins xlslice_0/Dout]
} else {
	set qFSGD_0 [ create_bd_cell -type ip -vlnv xilinx.com:SGD:qFSGD:1.0 qFSGD_0 ]
	set_property -dict [ list \
		CONFIG.LOG2_S_AXIS_DATA_WIDTH {6} \
		CONFIG.LOG2_MAX_DIMENSION {12} \
	] $qFSGD_0

	if {$log2_quantization_bits == 0} {
		set_property -dict [ list CONFIG.LOG2_QUANTIZATION_BITS {0} ] $qFSGD_0
	} elseif {$log2_quantization_bits == 1} {
		set_property -dict [ list CONFIG.LOG2_QUANTIZATION_BITS {1} ] $qFSGD_0
	} elseif {$log2_quantization_bits == 2} {
		set_property -dict [ list CONFIG.LOG2_QUANTIZATION_BITS {2} ] $qFSGD_0
	} elseif {$log2_quantization_bits == 3} {
		set_property -dict [ list CONFIG.LOG2_QUANTIZATION_BITS {3} ] $qFSGD_0
	}
	connect_bd_intf_net -intf_net qFSGD_0_m_axis [get_bd_intf_pins qFSGD_0/m_axis] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]
	connect_bd_intf_net -intf_net axi_dma_0_M_AXIS_MM2S [get_bd_intf_pins qFSGD_0/s_axis] [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S]
	connect_bd_net -net qFSGD_0_done [get_bd_ports led_green] [get_bd_pins qFSGD_0/done] [get_bd_pins xlconcat_0/In0]
	connect_bd_net -net ps7_FCLK_CLK0 [get_bd_pins qFSGD_0/clk] [get_bd_pins axi_dma_0/m_axi_mm2s_aclk] [get_bd_pins axi_dma_0/m_axi_s2mm_aclk] [get_bd_pins axi_dma_0/s_axi_lite_aclk] [get_bd_pins axi_gpio_0/s_axi_aclk] [get_bd_pins axi_mem_intercon/ACLK] [get_bd_pins axi_mem_intercon/M00_ACLK] [get_bd_pins axi_mem_intercon/S00_ACLK] [get_bd_pins axi_mem_intercon_1/ACLK] [get_bd_pins axi_mem_intercon_1/M00_ACLK] [get_bd_pins axi_mem_intercon_1/S00_ACLK] [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins ps7/M_AXI_GP0_ACLK] [get_bd_pins ps7/S_AXI_HP0_ACLK] [get_bd_pins ps7/S_AXI_HP1_ACLK] [get_bd_pins ps7_axi_periph/ACLK] [get_bd_pins ps7_axi_periph/M00_ACLK] [get_bd_pins ps7_axi_periph/M01_ACLK] [get_bd_pins ps7_axi_periph/S00_ACLK] [get_bd_pins rst_ps7_100M/slowest_sync_clk]
	connect_bd_net -net xlslice_0_Dout [get_bd_ports led_blue] [get_bd_pins qFSGD_0/resetn] [get_bd_pins xlslice_0/Dout]
}

save_bd_design

make_wrapper -files [get_files $config_proj_dir/$config_proj_name.srcs/sources_1/bd/procsys/procsys.bd] -top
add_files -norecurse $config_proj_dir/$config_proj_name.srcs/sources_1/bd/procsys/hdl/procsys_wrapper.v
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1


#set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
#set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE AlternateRoutability [get_runs synth_1]
#set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]

#set_property strategy Performance_ExtraTimingOpt [get_runs impl_1]
#set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
#set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
#set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
#set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]


# launch bitstream generation
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1

