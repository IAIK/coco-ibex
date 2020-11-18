// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Compressed instruction decoder
 *
 * Decodes RISC-V compressed instructions into their RV32 equivalent.
 * This module is fully combinatorial, clock and reset are used for
 * assertions only.
 */

`include "prim_assert.sv"
`include "secure.sv"
`define REG_S1 19:15
`define REG_S2 24:20

module ibex_compressed_decoder (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        valid_i,
    input  logic [31:0] instr_i,
    output logic [31:0] instr_o,
  `ifdef REGREAD_SECURE
    output logic [31:0] rf_read_enable_a_o,
    output logic [31:0] rf_read_enable_b_o,
  `endif
  `ifdef REGWRITE_SECURE
    output logic [31:0] rf_write_enable_o,
  `endif
  `ifdef MD_SECURE
    output logic md_enable_o,
  `endif
  `ifdef SHIFT_SECURE
    output logic shift_enable_o,
  `endif
  `ifdef ADDER_SECURE
    output logic adder_enable_o,
  `endif
  `ifdef CSR_SECURE
    output logic csr_enable_o,
  `endif
    output logic        is_compressed_o,
    output logic        illegal_instr_o
);
  import ibex_pkg::*;

  // valid_i indicates if instr_i is valid and is used for assertions only.
  // The following signal is used to avoid possible lint errors.
  logic unused_valid;
  assign unused_valid = valid_i;

`ifdef REGREAD_SECURE
  logic read_a;
  logic read_b;
  logic [4:0] read_address_a;
  logic [4:0] read_address_b;
`endif

`ifdef REGWRITE_SECURE
  logic write_reg;
  logic [4:0] write_address;
`endif

`ifdef MD_SECURE
  logic md_enable;
`endif

`ifdef SHIFT_SECURE
  logic shift_enable;
`endif

`ifdef ADDER_SECURE
  logic is_bw_op;
`endif

 `ifdef CSR_SECURE
    logic csr_enable;
  `endif
  ////////////////////////
  // Compressed decoder //
  ////////////////////////

  always_comb begin
    // By default, forward incoming instruction, mark it as legal.
    instr_o         = instr_i;
    illegal_instr_o = 1'b0;
  `ifdef REGREAD_SECURE
    read_a = 0;
    read_b = 0;
    read_address_a = 5'b0;
    read_address_b = 5'b0;
  `endif
  `ifdef REGWRITE_SECURE
    write_reg = 0;
    write_address = 5'b0;
  `endif 
  `ifdef MD_SECURE
    md_enable = 0;
  `endif
  `ifdef SHIFT_SECURE
    shift_enable = 0;
  `endif
  `ifdef ADDER_SECURE
    is_bw_op = 0;
  `endif
   `ifdef CSR_SECURE
    csr_enable = 0;
  `endif

    // Check if incoming instruction is compressed.
    unique case (instr_i[1:0])
      // C0
      2'b00: begin
        unique case (instr_i[15:13])
          3'b000: begin
            // c.addi4spn -> addi rd', x2, imm
            instr_o = {2'b0, instr_i[10:7], instr_i[12:11], instr_i[5],
                       instr_i[6], 2'b00, 5'h02, 3'b000, 2'b01, instr_i[4:2], {OPCODE_OP_IMM}};
            if (instr_i[12:5] == 8'b0)  illegal_instr_o = 1'b1;
          `ifdef REGREAD_SECURE
            read_a = 1;
            read_address_a = 5'h02;
          `endif

          `ifdef REGWRITE_SECURE
            write_reg = 1;
            write_address = {2'b01, instr_i[4:2]};
          `endif
          end

          3'b010: begin
            // c.lw -> lw rd', imm(rs1')
            instr_o = {5'b0, instr_i[5], instr_i[12:10], instr_i[6],
                       2'b00, 2'b01, instr_i[9:7], 3'b010, 2'b01, instr_i[4:2], {OPCODE_LOAD}};
          `ifdef REGREAD_SECURE
            read_a = 1;
            read_address_a = {2'b01, instr_i[9:7]};
          `endif

          `ifdef REGWRITE_SECURE
            write_reg = 1;
            write_address = {2'b01, instr_i[4:2]};
          `endif
          end

          3'b110: begin
            // c.sw -> sw rs2', imm(rs1')
            instr_o = {5'b0, instr_i[5], instr_i[12], 2'b01, instr_i[4:2],
                       2'b01, instr_i[9:7], 3'b010, instr_i[11:10], instr_i[6],
                       2'b00, {OPCODE_STORE}};
          `ifdef REGREAD_SECURE
            read_a = 1;
            read_address_a = {2'b01, instr_i[9:7]};
            read_b = 1;
            read_address_b = {2'b01, instr_i[4:2]};
          `endif

          //write: no. It's a store instruction.

          end

          3'b001,
          3'b011,
          3'b100,
          3'b101,
          3'b111: begin
            illegal_instr_o = 1'b1;
          end

          default: begin
            illegal_instr_o = 1'b1;
          end
        endcase
      end

      // C1
      //
      // Register address checks for RV32E are performed in the regular instruction decoder.
      // If this check fails, an illegal instruction exception is triggered and the controller
      // writes the actual faulting instruction to mtval.
      2'b01: begin
        unique case (instr_i[15:13])
          3'b000: begin
            // c.addi -> addi rd, rd, nzimm
            // c.nop
            instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2],
                       instr_i[11:7], 3'b0, instr_i[11:7], {OPCODE_OP_IMM}};
          `ifdef REGREAD_SECURE
            read_a = 1;
            read_address_a = instr_i[11:7];
          `endif

          `ifdef REGWRITE_SECURE
            write_reg = 1;
            write_address = instr_i[11:7];
          `endif

          end

          3'b001, 3'b101: begin
            // 001: c.jal -> jal x1, imm
            // 101: c.j   -> jal x0, imm
            instr_o = {instr_i[12], instr_i[8], instr_i[10:9], instr_i[6],
                       instr_i[7], instr_i[2], instr_i[11], instr_i[5:3],
                       {9 {instr_i[12]}}, 4'b0, ~instr_i[15], {OPCODE_JAL}};
            //write: no, its jump.
          end

          3'b010: begin
            // c.li -> addi rd, x0, nzimm
            // (c.li hints are translated into an addi hint)
            instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], 5'b0,
                       3'b0, instr_i[11:7], {OPCODE_OP_IMM}};
          `ifdef REGREAD_SECURE
            read_a = 1;
            read_address_a = 5'b0;
          `endif
          
          `ifdef REGWRITE_SECURE
            write_reg = 1;
            write_address = instr_i[11:7];
          `endif
          
          end

          3'b011: begin
            // c.lui -> lui rd, imm
            // (c.lui hints are translated into a lui hint)
            instr_o = {{15 {instr_i[12]}}, instr_i[6:2], instr_i[11:7], {OPCODE_LUI}};
            
            if (instr_i[11:7] == 5'h02) begin
              // c.addi16sp -> addi x2, x2, nzimm
              instr_o = {{3 {instr_i[12]}}, instr_i[4:3], instr_i[5], instr_i[2],
                         instr_i[6], 4'b0, 5'h02, 3'b000, 5'h02, {OPCODE_OP_IMM}};
            `ifdef REGREAD_SECURE
              read_a = 1;
              read_address_a = 5'h02;
            `endif

            `ifdef REGWRITE_SECURE
              write_reg = 1;
              write_address = 5'h02;
            `endif
            end

            if ({instr_i[12], instr_i[6:2]} == 6'b0) illegal_instr_o = 1'b1;
          end

          3'b100: begin
            unique case (instr_i[11:10])
              2'b00,
              2'b01: begin
                // 00: c.srli -> srli rd, rd, shamt
                // 01: c.srai -> srai rd, rd, shamt
                // (c.srli/c.srai hints are translated into a srli/srai hint)
                instr_o = {1'b0, instr_i[10], 5'b0, instr_i[6:2], 2'b01, instr_i[9:7],
                           3'b101, 2'b01, instr_i[9:7], {OPCODE_OP_IMM}};
                if (instr_i[12] == 1'b1)  illegal_instr_o = 1'b1;
              `ifdef REGREAD_SECURE
                read_a = 1;            
                read_address_a = {2'b01, instr_i[9:7]};
              `endif

              `ifdef REGWRITE_SECURE
                write_reg = 1;
                write_address = {2'b01, instr_i[9:7]};
              `endif

              `ifdef SHIFT_SECURE
                shift_enable = 1;
              `endif

              end

              2'b10: begin
                // c.andi -> andi rd, rd, imm
                instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], 2'b01, instr_i[9:7],
                           3'b111, 2'b01, instr_i[9:7], {OPCODE_OP_IMM}};
              `ifdef REGREAD_SECURE
                read_a = 1;
                read_address_a = {2'b01, instr_i[9:7]};
              `endif

              `ifdef REGWRITE_SECURE
                write_reg = 1;
                write_address = {2'b01, instr_i[9:7]};
              `endif

              `ifdef ADDER_SECURE
                is_bw_op = 1;
              `endif

              end

              2'b11: begin
                unique case ({instr_i[12], instr_i[6:5]})
                  3'b000: begin
                    // c.sub -> sub rd', rd', rs2'
                    instr_o = {2'b01, 5'b0, 2'b01, instr_i[4:2], 2'b01, instr_i[9:7],
                               3'b000, 2'b01, instr_i[9:7], {OPCODE_OP}};
                  `ifdef REGREAD_SECURE
                    read_a = 1;
                    read_address_a = {2'b01, instr_i[9:7]};
                    read_b = 1;
                    read_address_b = {2'b01, instr_i[4:2]};
                  `endif

                  `ifdef REGWRITE_SECURE
                    write_reg = 1;
                    write_address = {2'b01, instr_i[9:7]};
                  `endif

                  end

                  3'b001: begin
                    // c.xor -> xor rd', rd', rs2'
                    instr_o = {7'b0, 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b100,
                               2'b01, instr_i[9:7], {OPCODE_OP}};
                  `ifdef REGREAD_SECURE
                    read_a = 1;
                    read_address_a = {2'b01, instr_i[9:7]};
                    read_b = 1;
                    read_address_b = {2'b01, instr_i[4:2]};
                  `endif

                  `ifdef REGWRITE_SECURE
                    write_reg = 1;
                    write_address = {2'b01, instr_i[9:7]};
                  `endif

                  `ifdef ADDER_SECURE
                    is_bw_op = 1;
                  `endif

                  end

                  3'b010: begin
                    // c.or  -> or  rd', rd', rs2'
                    instr_o = {7'b0, 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b110,
                               2'b01, instr_i[9:7], {OPCODE_OP}};
                  `ifdef REGREAD_SECURE
                    read_a = 1;
                    read_address_a = {2'b01, instr_i[9:7]};
                    read_b = 1;
                    read_address_b = {2'b01, instr_i[4:2]};
                  `endif

                  `ifdef REGWRITE_SECURE
                    write_reg = 1;
                    write_address = {2'b01, instr_i[9:7]};
                  `endif

                  `ifdef ADDER_SECURE
                    is_bw_op = 1;
                  `endif

                  end

                  3'b011: begin
                    // c.and -> and rd', rd', rs2'
                    instr_o = {7'b0, 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b111,
                               2'b01, instr_i[9:7], {OPCODE_OP}};
                  `ifdef REGREAD_SECURE
                    read_a = 1;
                    read_address_a = {2'b01, instr_i[9:7]};
                    read_b = 1;
                    read_address_b = {2'b01, instr_i[4:2]};
                  `endif

                  `ifdef REGWRITE_SECURE
                    write_reg = 1;
                    write_address = {2'b01, instr_i[9:7]};
                  `endif

                  `ifdef ADDER_SECURE
                    is_bw_op = 1;
                  `endif


                  end

                  3'b100,
                  3'b101,
                  3'b110,
                  3'b111: begin
                    // 100: c.subw
                    // 101: c.addw
                    illegal_instr_o = 1'b1;
                  end

                  default: begin
                    illegal_instr_o = 1'b1;
                  end
                endcase
              end

              default: begin
                illegal_instr_o = 1'b1;
              end
            endcase
          end

          3'b110, 3'b111: begin
            // 0: c.beqz -> beq rs1', x0, imm
            // 1: c.bnez -> bne rs1', x0, imm
            instr_o = {{4 {instr_i[12]}}, instr_i[6:5], instr_i[2], 5'b0, 2'b01,
                       instr_i[9:7], 2'b00, instr_i[13], instr_i[11:10], instr_i[4:3],
                       instr_i[12], {OPCODE_BRANCH}};
          `ifdef REGREAD_SECURE
            read_a = 1;
            read_address_a = {2'b01, instr_i[9:7]};
            read_b = 1;
            read_address_b = 5'b0;
          `endif

          //Branch: aint writin to no register bro

          end

          default: begin
            illegal_instr_o = 1'b1;
          end
        endcase
      end

      // C2
      //
      // Register address checks for RV32E are performed in the regular instruction decoder.
      // If this check fails, an illegal instruction exception is triggered and the controller
      // writes the actual faulting instruction to mtval.
      2'b10: begin
        unique case (instr_i[15:13])
          3'b000: begin
            // c.slli -> slli rd, rd, shamt
            // (c.ssli hints are translated into a slli hint)
            instr_o = {7'b0, instr_i[6:2], instr_i[11:7], 3'b001, instr_i[11:7], {OPCODE_OP_IMM}};
            if (instr_i[12] == 1'b1)  illegal_instr_o = 1'b1; // reserved for custom extensions
          `ifdef REGREAD_SECURE
            read_a = 1;
            read_address_a = {instr_i[11:7]};
          `endif
          `ifdef SHIFT_SECURE
            shift_enable = 1;
          `endif
          end

          3'b010: begin
            // c.lwsp -> lw rd, imm(x2)
            instr_o = {4'b0, instr_i[3:2], instr_i[12], instr_i[6:4], 2'b00, 5'h02,
                       3'b010, instr_i[11:7], OPCODE_LOAD};
            if (instr_i[11:7] == 5'b0)  illegal_instr_o = 1'b1;
          `ifdef REGREAD_SECURE
            read_a = 1;
            read_address_a = 5'h02;
          `endif
          `ifdef REGWRITE_SECURE
            write_reg = 1;
            write_address = instr_i[11:7];
          `endif
          end

          3'b100: begin
            if (instr_i[12] == 1'b0) begin
              if (instr_i[6:2] != 5'b0) begin
                // c.mv -> add rd/rs1, x0, rs2
                // (c.mv hints are translated into an add hint)
                instr_o = {7'b0, instr_i[6:2], 5'b0, 3'b0, instr_i[11:7], {OPCODE_OP}};
              `ifdef REGREAD_SECURE
                read_a = 1;
                read_address_a = 5'b0;
                read_b = 1;
                read_address_b = instr_i[6:2];
              `endif
              `ifdef REGWRITE_SECURE
                write_reg = 1;
                write_address = instr_i[11:7];
              `endif
              end else begin
                // c.jr -> jalr x0, rd/rs1, 0
                instr_o = {12'b0, instr_i[11:7], 3'b0, 5'b0, {OPCODE_JALR}};
                if (instr_i[11:7] == 5'b0)  illegal_instr_o = 1'b1;
              `ifdef REGREAD_SECURE
                read_a = 1;
                read_address_a = instr_i[11:7];
              `endif
              //I think there is no writing. The comment must be wrong.
              end
            end else begin
              if (instr_i[6:2] != 5'b0) begin
                // c.add -> add rd, rd, rs2
                // (c.add hints are translated into an add hint)
                instr_o = {7'b0, instr_i[6:2], instr_i[11:7], 3'b0, instr_i[11:7], {OPCODE_OP}};
              `ifdef REGREAD_SECURE
                read_a = 1;
                read_address_a = instr_i[11:7];
                read_b = 1;
                read_address_b = instr_i[6:2];
              `endif
              `ifdef REGWRITE_SECURE
                write_reg = 1;
                write_address = instr_i[11:7];
              `endif
              end else begin
                if (instr_i[11:7] == 5'b0) begin
                  // c.ebreak -> ebreak
                  instr_o = {32'h00_10_00_73};
                end else begin
                  // c.jalr -> jalr x1, rs1, 0
                  instr_o = {12'b0, instr_i[11:7], 3'b000, 5'b00001, {OPCODE_JALR}};
                `ifdef REGREAD_SECURE
                  read_a = 1;
                  read_address_a = instr_i[11:7];
                `endif
                `ifdef REGWRITE_SECURE
                  write_reg = 1;
                  write_address = 5'b00001;
                `endif
                end
              end
            end
          end

          3'b110: begin
            // c.swsp -> sw rs2, imm(x2)
            instr_o = {4'b0, instr_i[8:7], instr_i[12], instr_i[6:2], 5'h02, 3'b010,
                       instr_i[11:9], 2'b00, {OPCODE_STORE}};
          `ifdef REGREAD_SECURE
            read_a = 1;
            read_address_a = 5'h02;
            read_b = 1;
            read_address_b = instr_i[6:2];
          `endif
          end

          3'b001,
          3'b011,
          3'b101,
          3'b111: begin
            illegal_instr_o = 1'b1;
          end

          default: begin
            illegal_instr_o = 1'b1;
          end
        endcase
      end

      // Incoming instruction is not compressed.
      2'b11: 
      begin
          `ifdef REGREAD_SECURE
            read_address_a = instr_i[`REG_S1];
            read_address_b = instr_i[`REG_S2];
            
            if(instr_i[6:2] == 5'b01101 || //LUI
               instr_i[6:2] == 5'b00101 || //AUIPC
               instr_i[6:2] == 5'b11011 || //JAL
               instr_i[6:2] == 5'b11100    //ECALL, EBREAK 
            ) begin
               read_a = 0;
            end else begin
               read_a = 1;
            end

            if(instr_i[6:2] == 5'b11000 || //BEQ, BNE, BLT, BGE, BLTU, BGEU
               instr_i[6:2] == 5'b01000 || //SW, SB, SH
               instr_i[6:2] == 5'b01100    //ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
            ) begin
              read_b = 1;
            end else begin
              read_b = 0;
            end
          `endif
          `ifdef REGWRITE_SECURE

            if(instr_i[6:2] != 5'b01000 && 
               instr_i[6:2] != 5'b11000 &&
               instr_i[6:2] != 5'b11100 ) begin
                write_reg = 1;
                write_address = instr_i[11:7];
            end
          `endif

          `ifdef MD_SECURE
            if(instr_i[6:2] == 5'b01100 &&
               instr_i[25] == 1'b1) begin
                 md_enable = 1;
            end
          `endif

          `ifdef SHIFT_SECURE
            if(instr_i[6:2] == 5'b00100 && 
               (instr_i[14:12] == 3'b001 ||  //SLLI
                instr_i[14:12] == 3'b101))    //SRLI, SRAI
            begin
              shift_enable = 1;
            end else if (instr_i[6:2] == 5'b01100 && 
               (instr_i[14:12] == 3'b001 ||  //SLL
                instr_i[14:12] == 3'b010 ||  //SLT
                instr_i[14:12] == 3'b011 ||  //SLTU
                instr_i[14:12] == 3'b101  //SRL, SRA
               ))
            begin
              shift_enable = 1;
            end            
          `endif

          `ifdef ADDER_SECURE
            if(instr_i[6:2] == 5'b00100 &&   //XORI, ORI, ANDI
               (instr_i[14:12] == 3'b100 ||
                instr_i[14:12] == 3'b110 ||
                instr_i[14:12] == 3'b111))
              begin          
                    is_bw_op = 1;
              end else if(instr_i[6:2] == 5'b01100 && //XOR, AND, OR
               (instr_i[14:12] == 3'b100 ||
                instr_i[14:12] == 3'b110 ||
                instr_i[14:12] == 3'b111) && 
                instr_i[25] == 1'b0) 
              begin
                     is_bw_op = 1;
              end
          `endif

          `ifdef CSR_SECURE
           if(instr_i[6:2] == 5'b11100) begin
            csr_enable = 1;
           end
          `endif
        end
 

    
    
      default: begin
        illegal_instr_o = 1'b1;
      end
    endcase
  end

  assign is_compressed_o = (instr_i[1:0] != 2'b11);

`ifdef REGREAD_SECURE
  always_comb begin : re_decoder
    for (int unsigned i = 0; i < 32; i++) begin
      rf_read_enable_a_o[i] = (read_address_a == 5'(i)) ?  read_a : 1'b0;
      rf_read_enable_b_o[i] = (read_address_b == 5'(i)) ?  read_b : 1'b0;
    end
  end
`endif

`ifdef REGWRITE_SECURE
  always_comb begin : we_decoder
    for (int unsigned i = 0; i < 32; i++) begin
      rf_write_enable_o[i] = (write_address == 5'(i)) ? write_reg : 1'b0;
    end
  end
`endif

`ifdef MD_SECURE
  assign md_enable_o = md_enable;
`endif

`ifdef SHIFT_SECURE
  assign shift_enable_o = shift_enable; 
`endif

`ifdef ADDER_SECURE
  assign adder_enable_o = ~(shift_enable | is_bw_op);
`endif

`ifdef CSR_SECURE
  assign csr_enable_o = csr_enable;
`endif
  
  ////////////////
  // Assertions //
  ////////////////

  // Selectors must be known/valid.
  `ASSERT(IbexInstrLSBsKnown, valid_i |->
      !$isunknown(instr_i[1:0]))
  `ASSERT(IbexC0Known1, (valid_i && (instr_i[1:0] == 2'b00)) |->
      !$isunknown(instr_i[15:13]))
  `ASSERT(IbexC1Known1, (valid_i && (instr_i[1:0] == 2'b01)) |->
      !$isunknown(instr_i[15:13]))
  `ASSERT(IbexC1Known2, (valid_i && (instr_i[1:0] == 2'b01) && (instr_i[15:13] == 3'b100)) |->
      !$isunknown(instr_i[11:10]))
  `ASSERT(IbexC1Known3, (valid_i &&
      (instr_i[1:0] == 2'b01) && (instr_i[15:13] == 3'b100) && (instr_i[11:10] == 2'b11)) |->
      !$isunknown({instr_i[12], instr_i[6:5]}))
  `ASSERT(IbexC2Known1, (valid_i && (instr_i[1:0] == 2'b10)) |->
      !$isunknown(instr_i[15:13]))
  
`ifdef REGREAD_SECURE
   `ASSERT(IbexReadNotOnlyB, read_b |-> read_a)
   `ASSERT(IbexOpcodeLuiA, (instr_o[0:6]==OPCODE_LUI) |-> !read_a)
   `ASSERT(IbexOpcodeLuiB, (instr_o[0:6]==OPCODE_LUI) |-> !read_b)
   `ASSERT(IbexOpcodeAuipcA, (instr_o[0:6]==OPCODE_AUIPC) |-> !read_a)
   `ASSERT(IbexOpcodeAuipcB, (instr_o[0:6]==OPCODE_AUIPC) |-> !read_b)
   `ASSERT(IbexOpcodeJalA, (instr_o[0:6]==OPCODE_JAL) |-> !read_a)
   `ASSERT(IbexOpcodeJalB, (instr_o[0:6]==OPCODE_JAL) |-> !read_b)
   `ASSERT(IbexOpcodeJalrA, (instr_o[0:6]==OPCODE_JALR) |-> read_a) 
   `ASSERT(IbexOpcodeJalrB, (instr_o[0:6]==OPCODE_JALR) |-> !read_b)
   `ASSERT(IbexOpcodeBranchA, (instr_o[0:6]==OPCODE_BRANCH) |-> read_a)
   `ASSERT(IbexOpcodeBranchB, (instr_o[0:6]==OPCODE_BRANCH) |-> read_b)
   `ASSERT(IbexOpcodeLoadA, (instr_o[0:6]==OPCODE_LOAD) |-> read_a)
   `ASSERT(IbexOpcodeLoadB, (instr_o[0:6]==OPCODE_LOAD) |-> !read_b)
   `ASSERT(IbexOpcodeStoreA, (instr_o[0:6]==OPCODE_STORE) |-> read_a)
   `ASSERT(IbexOpcodeStoreB, (instr_o[0:6]==OPCODE_STORE) |-> read_b)
   `ASSERT(IbexOpcodeImmA, (instr_o[0:6]==OPCODE_OP_IMM) |-> read_a)
   `ASSERT(IbexOpcodeImmB, (instr_o[0:6]==OPCODE_OP_IMM) |-> !read_b)
   `ASSERT(IbexOpcodeOpA, (instr_o[0:6]==OPCODE_OP) |-> read_a)
   `ASSERT(IbexOpcodeOpB, (instr_o[0:6]==OPCODE_OP) |-> read_b)
   `ASSERT(IbexOpcodeMiscMemA, (instr_o[0:6]==OPCODE_MISC_MEM) |-> read_a)
   `ASSERT(IbexOpcodeMiscMemB, (instr_o[0:6]==OPCODE_MISC_MEM) |-> !read_b)
   `ASSERT(IbexOpcodeSystemA, (instr_o[0:6]==OPCODE_SYSTEM) |-> !read_a)
   `ASSERT(IbexOpcodeSystemB, (instr_o[0:6]==OPCODE_SYSTEM) |-> !read_b)
`endif
   

      


endmodule
