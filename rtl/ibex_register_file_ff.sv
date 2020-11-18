// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * RISC-V register file
 *
 * Register file with 31 or 15x 32 bit wide registers. Register 0 is fixed to 0.
 * This register file is based on flip flops. Use this register file when
 * targeting FPGA synthesis or Verilator simulation.
 */
`include "secure.sv"

module ibex_register_file #(
    parameter bit RV32E              = 0,
    parameter int unsigned DataWidth = 32
) (
    // Clock and Reset
    input  logic                 clk_i,
    input  logic                 rst_ni,

    input  logic                 test_en_i,
    
    //Read port R1
  `ifdef REGREAD_SECURE
    input logic [31:0]           read_enable_a_i,
  `else
    input  logic [4:0]           raddr_a_i,
  `endif
    output logic [DataWidth-1:0] rdata_a_o,

    //Read port R2
  `ifdef REGREAD_SECURE
    input logic [31:0]           read_enable_b_i,
  `else
    input  logic [4:0]           raddr_b_i,
  `endif    
    output logic [DataWidth-1:0] rdata_b_o,

    // Write port W1
  `ifdef REGWRITE_SECURE
    input logic [31:0] write_enable_secure_i,
  `endif
    input  logic [4:0]           waddr_a_i,
    input  logic [DataWidth-1:0] wdata_a_i,
    input  logic                 we_a_i


);

  localparam int unsigned ADDR_WIDTH = RV32E ? 4 : 5;
  localparam int unsigned NUM_WORDS  = 2**ADDR_WIDTH;

  logic [NUM_WORDS-1:0][DataWidth-1:0] rf_reg;
  logic [NUM_WORDS-1:1][DataWidth-1:0] rf_reg_tmp;
  logic [NUM_WORDS-1:1]                we_a_dec;

  always_comb begin : we_a_decoder
    for (int unsigned i = 1; i < NUM_WORDS; i++) begin
      we_a_dec[i] = (waddr_a_i == 5'(i)) ?  we_a_i : 1'b0;
    end
  end

  // loop from 1 to NUM_WORDS-1 as R0 is nil
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rf_reg_tmp <= '{default:'0};
    end else begin
    `ifdef REGWRITE_SECURE
      for (int reg_id = 1; reg_id < NUM_WORDS; reg_id++) begin
        for(int bit_id = 0; bit_id < DataWidth; bit_id++) begin
          if (we_a_dec[reg_id]) rf_reg_tmp[reg_id][bit_id] <= (wdata_a_i[bit_id] & write_enable_secure_i[reg_id]);
        end
      end
    `else 
      for (int r = 1; r < NUM_WORDS; r++) begin
        if (we_a_dec[r]) rf_reg_tmp[r] <= wdata_a_i;
      end
    `endif
    end
  end

  // R0 is nil
  assign rf_reg[0] = '0;
  assign rf_reg[NUM_WORDS-1:1] = rf_reg_tmp[NUM_WORDS-1:1];

`ifdef REGREAD_SECURE
  always_comb begin : reg_read_with_read_enable
    rdata_a_o = 0;
    rdata_b_o = 0;

    for (int reg_id = 0; reg_id < NUM_WORDS; reg_id++) begin
      for(int bit_id = 0; bit_id < DataWidth; bit_id++) begin
        rdata_a_o[bit_id] = rdata_a_o[bit_id] | (rf_reg[reg_id][bit_id] & read_enable_a_i[reg_id]);
        rdata_b_o[bit_id] = rdata_b_o[bit_id] | (rf_reg[reg_id][bit_id] & read_enable_b_i[reg_id]);
      end
    end
  end
`else
  assign rdata_a_o = rf_reg[raddr_a_i];
  assign rdata_b_o = rf_reg[raddr_b_i];
`endif



endmodule
