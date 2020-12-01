// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Single-port RAM with 1 cycle read/write delay, 32 bit words
 */


module rom_1p (
  clk_i, rst_ni,
  req_i, we_i, be_i, addr_i, wdata_i,
  rvalid_o, rdata_o
);
    input clk_i;
    input rst_ni;

    input               req_i;
    input               we_i;
    input        [ 3:0] be_i;
    input        [31:0] addr_i;
    input        [31:0] wdata_i;
    output        rvalid_o;
    output  [31:0] rdata_o;

  localparam Depth = 256;
  localparam Aw = $clog2(Depth);
  
  (* keep *) reg [31:0] mem [Depth-1:0];

  wire [Aw-1:0] addr_idx;
  assign addr_idx = addr_i[Aw-1+2:2];
  
  wire [31-Aw:0] unused_addr_parts;
  assign unused_addr_parts = {addr_i[31:Aw+2], addr_i[1:0]};

  always @(posedge clk_i) begin
    if (req_i) begin
      if (we_i) begin
          mem[addr_idx][31:0] <= wdata_i[31:0];
      end
      rdata_o <= mem[addr_idx];
    end
  end

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rvalid_o <= 0;
    end else begin
      rvalid_o <= req_i;
    end
  end

endmodule
