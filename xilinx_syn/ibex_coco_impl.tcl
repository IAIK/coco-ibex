
read_verilog ../rtl/secure.sv
#read_verilog /nfs/home/tanvira/security_research_project/lec_out_coco/prim_assert.sv
set_property file_type "Verilog Header" [get_files ../rtl/secure.sv]
#set_property file_type "Verilog Header" [get_files /nfs/home/tanvira/security_research_project/lec_out_coco/prim_assert.sv]
read_verilog -library xil_defaultlib -sv ../rtl/ibex_pkg.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_alu.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_compressed_decoder.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_controller.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_counters.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_cs_registers.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_decoder.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_ex_block.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_fetch_fifo.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_icache.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_id_stage.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_if_stage.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_load_store_unit.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_multdiv_fast.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_multdiv_slow.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_pmp.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_prefetch_buffer.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_register_file_ff.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_wb_stage.sv
#read_verilog -library xil_defaultlib -sv /nfs/home/tanvira/security_research_project/lec_out_coco/prim_generic_ram_1p.sv
#read_verilog -library xil_defaultlib -sv /nfs/home/tanvira/security_research_project/lec_out_coco/ram_1p_secure.v
#read_verilog -library xil_defaultlib -sv /nfs/home/tanvira/security_research_project/lec_out_coco/rom_1p.v
#read_verilog -library xil_defaultlib -sv /nfs/home/tanvira/security_research_project/lec_out_coco/prim_secded_28_22_dec.sv
#read_verilog -library xil_defaultlib -sv /nfs/home/tanvira/security_research_project/lec_out_coco/prim_secded_28_22_enc.sv
#read_verilog -library xil_defaultlib -sv /nfs/home/tanvira/security_research_project/lec_out_coco/prim_secded_72_64_dec.sv
#read_verilog -library xil_defaultlib -sv /nfs/home/tanvira/security_research_project/lec_out_coco/prim_secded_72_64_enc.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_core.sv
read_verilog -library xil_defaultlib -sv ../rtl/ibex_top.v





read_xdc ibex_coco.xdc

#synth_design -part xc7k160tlffv676-2L -mode out_of_context -top ibex_core
synth_design -part xc7k160tlffv676-2L -mode out_of_context -top ibex_top
opt_design -resynth_seq_area

report_utilization
report_timing
report_power
