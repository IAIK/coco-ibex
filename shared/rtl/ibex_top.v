`include "../../rtl/secure.sv"

`ifdef MEM_SECURE
  `include "ram_1p_secure.v"
  `include "rom_1p.v"
`else
  `include "ram_1p.v"
`endif

module ibex_top (clk_sys, rst_sys_n, 
                 `ifdef MEM_SECURE
                 instr_we, instr_be, instr_wdata
                 `endif
);
  // Inputs
  input clk_sys;
  input rst_sys_n;
  `ifdef MEM_SECURE
  input instr_we;
  input [3:0] instr_be;
  input [31:0] instr_wdata;
  `endif
  
  `ifdef MEM_SECURE
  parameter MEM_SIZE  = 8*1024; //8 * 1024; // 64 kB
  parameter MEM_START = 32'h00000000;
  parameter MEM_MASK  = MEM_SIZE-1;
  `endif
  
  // Instruction connection to SRAM
  wire        instr_req;
  wire        instr_gnt;
  wire        instr_rvalid;
  wire [31:0] instr_addr;
  wire [31:0] instr_rdata;

  // Data connection to SRAM
  wire        data_req;
  wire        data_gnt;
  wire        data_rvalid;
  wire        data_we;
  wire  [3:0] data_be;
  wire [31:0] data_addr;
  wire [31:0] data_wdata;
  wire [31:0] data_rdata;

  // Normal SRAM arbiter
  `ifndef MEM_SECURE
  wire [31:0] mem_addr;
  wire        mem_req;
  wire        mem_write;
  wire  [3:0] mem_be;
  wire [31:0] mem_wdata;
  wire        mem_rvalid;
  wire [31:0] mem_rdata;
  
  always @(*) begin
    mem_req = 1'b0;
    mem_addr = 32'b0;
    mem_write = 1'b0;
    mem_be = 4'b0;
    mem_wdata = 32'b0;
    if (instr_req) begin
      mem_req = (instr_addr & ~MEM_MASK) == MEM_START;
      mem_addr = instr_addr;
    end
    else if (data_req) begin
      mem_req = (data_addr & ~MEM_MASK) == MEM_START;
      mem_write = data_we;
      mem_be = data_be;
      mem_addr = data_addr;
      mem_wdata = data_wdata;
    end
  end
  `endif
  
  // The ibex core
  ibex_core u_core (
     .clk_i                 (clk_sys),
     .rst_ni                (rst_sys_n),

     .test_en_i             ('b0),

     .hart_id_i             (32'b0),
     // First instruction executed is at 0x0 + 0x80
     .boot_addr_i           (32'h00000000),

     .instr_req_o           (instr_req),
     .instr_gnt_i           (instr_gnt),
     .instr_rvalid_i        (instr_rvalid),
     .instr_addr_o          (instr_addr),
     .instr_rdata_i         (instr_rdata),
     .instr_err_i           ('b0),

     .data_req_o            (data_req),
     .data_gnt_i            (data_gnt),
     .data_rvalid_i         (data_rvalid),
     .data_we_o             (data_we),
     .data_be_o             (data_be),
     .data_addr_o           (data_addr),
     .data_wdata_o          (data_wdata),
     .data_rdata_i          (data_rdata),
     .data_err_i            ('b0),

     .irq_software_i        (1'b0),
     .irq_timer_i           (1'b0),
     .irq_external_i        (1'b0),
     .irq_fast_i            (15'b0),
     .irq_nm_i              (1'b0),

     .debug_req_i           ('b0),

     .fetch_enable_i        ('b1),
     .core_sleep_o          ()
  );

  `ifdef MEM_SECURE
  // separate SRAM blocks for instruction and data storage
  ram_1p_secure u_ram (
    .clk_i     ( clk_sys      ),
    .rst_ni    ( rst_sys_n    ),
    .req_i     ( data_req     ),
    .we_i      ( data_we      ),
    .be_i      ( data_be      ),
    .addr_i    ( data_addr    ),
    .wdata_i   ( data_wdata   ),
    .rvalid_o  ( data_rvalid  ),
    .rdata_o   ( data_rdata   ),
    .gnt_o     ( data_gnt     )
  );

  rom_1p instr_rom (
    .clk_i     ( clk_sys      ),
    .rst_ni    ( rst_sys_n    ),
    .req_i     ( instr_req    ),
    .we_i      ( instr_we     ),
    .be_i      ( instr_be     ),
    .addr_i    ( instr_addr   ),
    .wdata_i   ( instr_wdata  ),
    .rvalid_o  ( instr_rvalid ),
    .rdata_o   ( instr_rdata  )
  );
  
  always @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      instr_gnt    <= 'b0;
    end else begin
      instr_gnt    <= instr_req;
    end
  end
  
  `else // if not MEM_SECURE
  // SRAM block for instruction and data storage
  ram_1p #(.Depth(MEM_SIZE / 4)) u_ram(
    .clk_i(clk_sys),
    .rst_ni(rst_sys_n),
    .req_i(mem_req),
    .we_i(mem_write),
    .be_i(mem_be),
    .addr_i(mem_addr),
    .wdata_i(mem_wdata),
    .rvalid_o(mem_rvalid),
    .rdata_o(mem_rdata)
  );
  assign instr_rdata = mem_rdata;
  assign data_rdata = mem_rdata;
  assign instr_rvalid = mem_rvalid;
  always @(posedge clk_sys or negedge rst_sys_n)
    if (!rst_sys_n) begin
      instr_gnt <= 'b0;
      data_gnt <= 'b0;
      data_rvalid <= 'b0;
    end
    else begin
      instr_gnt <= instr_req && mem_req;
      data_gnt <= (~instr_req && data_req) && mem_req;
      data_rvalid <= (~instr_req && data_req) && mem_req;
    end
  `endif
endmodule
