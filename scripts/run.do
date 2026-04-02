
vlib work
vdel -all
vlib work

vlog axi_lite_pkg.sv
vlog axi_lite_if.sv
vlog axi_lite_master.sv 
vlog axi_lite_slave.sv  
vlog tb_axi_lite.sv +acc


vsim work.tb_axi_lite
add wave -r *


run -all
