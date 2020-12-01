# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

source ./tcl/yosys_common.tcl

if { $lr_synth_flatten } {
  set flatten_opt "-flatten"
} else {
  set flatten_opt ""
}

if { $lr_synth_timing_run } {
  write_sdc_out $lr_synth_sdc_file_in $lr_synth_sdc_file_out
}

yosys "read_verilog -sv ./rtl/prim_clock_gating.v $lr_synth_out_dir/generated/*.v"

if { $lr_synth_ibex_branch_target_alu } {
  yosys "chparam -set BranchTargetALU 1 ibex_core"
}

yosys "synth $flatten_opt -top $lr_synth_top_module"
yosys "opt -purge"

yosys "write_verilog $lr_synth_pre_map_out"

# yosys "dfflibmap -liberty $lr_synth_cell_library_path"
yosys "opt"
yosys "clean"
yosys "write_verilog $lr_synth_netlist_out"

yosys "check"

