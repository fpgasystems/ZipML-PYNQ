if {$argc != 4} {
  puts "Expected: <proj_name> <proj_dir> <xdc_dir> <log2_quantization_bits>"
  exit
}

# project name, target dir and FPGA part to use
set config_proj_name [lindex $argv 0]
set config_proj_dir [lindex $argv 1]
set config_proj_part "xc7z020clg400-1"

# other project config

set xdc_dir [lindex $argv 2]
set log2_quantization_bits [lindex $argv 3]

puts "config_proj_name: ${config_proj_name}"
puts "config_proj_dir: ${config_proj_dir}"
puts "xdc_dir:  ${xdc_dir}"
puts "log2_quantization_bits: ${log2_quantization_bits}"

# set up project
create_project -force $config_proj_name $config_proj_dir -part $config_proj_part

add_files $xdc_dir/../xlnx_ip/xlnx_dec23_to_float_conv.xci
add_files $xdc_dir/../xlnx_ip/xlnx_fp_lessthan.xci
add_files $xdc_dir/../xlnx_ip/xlnx_fp_mult.xci
add_files $xdc_dir/../xlnx_ip/xlnx_fp_sub.xci


add_files $xdc_dir/../RTL/dual_port_ram.vhd
add_files $xdc_dir/../RTL/fixed_adder_tree.vhd
add_files $xdc_dir/../RTL/fixed_vector_subtract.vhd
add_files $xdc_dir/../RTL/fp_subtract_mult.vhd
add_files $xdc_dir/../RTL/normal2axis_fifo.vhd


if {$log2_quantization_bits == -1} {
	add_files $xdc_dir/../RTL/fp_vector_mult.vhd
	add_files $xdc_dir/../RTL/fp_scalar_vector_mult.vhd
	add_files $xdc_dir/../RTL/hybrid_dot_product.vhd
	add_files $xdc_dir/../RTL/floatFSGD.vhd
} else {
	add_files $xdc_dir/../RTL/qfixed_dot_product.vhd
	add_files $xdc_dir/../RTL/qfixed_scalar_vector_mult.vhd
	add_files $xdc_dir/../RTL/qFSGD.vhd
}

ipx::package_project -root_dir $config_proj_dir -vendor xilinx.com -library SGD -import_files -set_current false