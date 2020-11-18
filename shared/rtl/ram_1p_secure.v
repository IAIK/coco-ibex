module ram_1p_secure  (
    clk_i, rst_ni,
    req_i, we_i, be_i, addr_i, wdata_i, 
    gnt_o, rvalid_o, rdata_o
);
  input clk_i;
  input rst_ni;
  input req_i;
  input we_i;
  input [3:0] be_i;
  input [31:0] wdata_i;

  input [31:0] addr_i;
  output gnt_o;
  output rvalid_o;
  output [31:0] rdata_o;


parameter a = 3; //Address bits for in-block addressing.
                 //2^a = number of registers in block.
                 //Each register has 32 bits.
parameter b = 4; //Address bits for inter-block addressing.
                 //2^b = number of block.
localparam num_regs_in_block = 2 ** a;
localparam num_blocks = 2 ** b;

  // Compute address index
  // Since our memory registers are 32 bit, we cut off the two bits MSB
  wire [a+b-1:0] addr_idx;
  assign addr_idx = addr_i[a+b-1+2:2];

  //Create mem:
  // 32 Bit wide registers
  // num_regs_in_block registers per block in num_blocks
  reg [31:0] mem [num_blocks-1:0][num_regs_in_block-1:0];

  //OH-vector for register accesses
  reg [num_regs_in_block-1:0] OH_in_reg;
  reg [num_regs_in_block-1:0] OH_in_signal;

  //Address of register in block
  wire [a-1:0] in_block_addr;
  assign in_block_addr = addr_idx[a-1:0];

  //Address of block
  wire [b-1:0] inter_block_addr;
  assign inter_block_addr = addr_idx[b+a-1:a];
  reg [b-1:0] inter_block_addr_reg;
  reg [b-1:0] inter_block_addr_stage1;


  //------------------------------------------------------------------
  
  integer oh_reg_id;
  always @* begin
    for(oh_reg_id = 0; oh_reg_id < num_regs_in_block; oh_reg_id = oh_reg_id + 1) begin
      OH_in_signal[oh_reg_id] = (in_block_addr == /*5'*/(oh_reg_id)) ?  1'b1 : 1'b0;
    end
  end

  
  reg gnt;

  reg we;
  reg [31:0] wdata;
  reg [3:0] be;


  always@(posedge clk_i or negedge rst_ni)
  begin
    if(!rst_ni) begin
      OH_in_reg <= 0;      
      gnt <= 0;
      we <= 0;
      wdata <= 0;
      be <= 0;
    end else begin
      if(req_i) begin
        OH_in_reg <= OH_in_signal;
        gnt <= 1;
        inter_block_addr_stage1 <= inter_block_addr;
        we <= we_i;
        wdata <= wdata_i;
        be <= be_i;
      end else begin
        OH_in_reg <= 0;
        gnt <= 0;
        inter_block_addr_stage1 <= 0;
        we <= 0;
        wdata <= 0;
        be <= 0;
      end
      if(gnt) begin
        inter_block_addr_reg <= inter_block_addr_stage1;
      end
    end
  end

  assign gnt_o = req_i;

  //------------------------------------------------------------------
  
  reg [31:0] rdata_OR [num_blocks-1:0]; //32 bit per block
  reg rvalid;

  integer read_mem_id;
  integer read_mem_block_id;
  integer rdata_OR_tmp;
  always @(posedge clk_i) begin
    for(read_mem_block_id = 0; read_mem_block_id < num_blocks; read_mem_block_id = read_mem_block_id + 1) begin
      rdata_OR_tmp = 0;
      for(read_mem_id = 0; read_mem_id < num_regs_in_block; read_mem_id = read_mem_id + 1) begin
        rdata_OR_tmp = rdata_OR_tmp | (mem[read_mem_block_id][read_mem_id] & {32{OH_in_reg[read_mem_id]}} & {32{~we}});
      end
      rdata_OR[read_mem_block_id] = rdata_OR_tmp;
    end
  end

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rvalid <= 0;
    end else begin
      rvalid <= |OH_in_reg;
      
    end
  end

  assign rvalid_o = rvalid;


  genvar gen_level_cnt;
  genvar gen_data_cnt;
  generate
    for (gen_level_cnt = 0; gen_level_cnt <= b; gen_level_cnt = gen_level_cnt + 1) begin : rdata
      wire [31:0] leveldata [2**(b-gen_level_cnt)-1:0];
      if(gen_level_cnt != 0) begin
        for(gen_data_cnt = 0; gen_data_cnt < 2**(b-gen_level_cnt); gen_data_cnt = gen_data_cnt + 1) begin
          assign leveldata[gen_data_cnt] = inter_block_addr_reg[gen_level_cnt-1] ? 
                                           rdata[gen_level_cnt-1].leveldata[2 * gen_data_cnt + 1] :  
                                           rdata[gen_level_cnt-1].leveldata[2 * gen_data_cnt];
        end
      end
    end

  endgenerate
  
  genvar gen_init_cnt;
  generate
    for(gen_init_cnt = 0; gen_init_cnt < num_blocks; gen_init_cnt = gen_init_cnt+1) begin
      assign rdata[0].leveldata[gen_init_cnt] = rdata_OR[gen_init_cnt];
    end
  endgenerate

  assign rdata_o = rdata[b].leveldata[0];

  //-----------------------------------------------------------------
  
  integer write_block_id0;
  integer write_reg_id0;
  always @(posedge clk_i)
  begin
    for(write_block_id0 = 0; write_block_id0 < num_blocks; write_block_id0 = write_block_id0 + 1) begin
      for(write_reg_id0 = 0; write_reg_id0 < num_regs_in_block; write_reg_id0 = write_reg_id0 + 1) begin
        if(be[0] & we & (/*3'*/(write_block_id0) == inter_block_addr_stage1)) begin
          mem[write_block_id0][write_reg_id0][7:0] <= 
            (wdata[7:0] & {8{OH_in_reg[write_reg_id0]}}) |
            (mem[write_block_id0][write_reg_id0][7:0] & {8{~OH_in_reg[write_reg_id0]}});
        end
      end
    end
  end
  
  integer write_block_id1;
  integer write_reg_id1;
  always @(posedge clk_i)
  begin
    for(write_block_id1 = 0; write_block_id1 < num_blocks; write_block_id1 = write_block_id1 + 1) begin
      for(write_reg_id1 = 0; write_reg_id1 < num_regs_in_block; write_reg_id1 = write_reg_id1 + 1) begin
        if(be[1] & we & (/*3'*/(write_block_id1) == inter_block_addr_stage1)) begin
          mem[write_block_id1][write_reg_id1][15:8] <= 
            (wdata[15:8] & {8{OH_in_reg[write_reg_id1]}}) |
            (mem[write_block_id1][write_reg_id1][15:8] & {8{~OH_in_reg[write_reg_id1]}});
        end
      end
    end
  end

  integer write_block_id2;
  integer write_reg_id2;
  always @(posedge clk_i)
  begin
    for(write_block_id2 = 0; write_block_id2 < num_blocks; write_block_id2 = write_block_id2 + 1) begin
      for(write_reg_id2 = 0; write_reg_id2 < num_regs_in_block; write_reg_id2 = write_reg_id2 + 1) begin
        if(be[2] & we & (/*3'*/(write_block_id2) == inter_block_addr_stage1)) begin
          mem[write_block_id2][write_reg_id2][23:16] <= 
            (wdata[23:16] & {8{OH_in_reg[write_reg_id2]}}) |
            (mem[write_block_id2][write_reg_id2][23:16] & {8{~OH_in_reg[write_reg_id2]}});
        end
      end
    end
  end
  
  integer write_block_id3;
  integer write_reg_id3;
  always @(posedge clk_i)
  begin
    for(write_block_id3 = 0; write_block_id3 < num_blocks; write_block_id3 = write_block_id3 + 1) begin
      for(write_reg_id3 = 0; write_reg_id3 < num_regs_in_block; write_reg_id3 = write_reg_id3 + 1) begin
        if(be[3] & we & (/*3'*/(write_block_id3) == inter_block_addr_stage1)) begin
          mem[write_block_id3][write_reg_id3][31:24] <= 
            (wdata[31:24] & {8{OH_in_reg[write_reg_id3]}}) |
            (mem[write_block_id3][write_reg_id3][31:24] & {8{~OH_in_reg[write_reg_id3]}});
        end
      end
    end
  end
endmodule

