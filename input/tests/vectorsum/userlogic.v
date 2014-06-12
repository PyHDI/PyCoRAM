`include "pycoram.v"

`define THREAD_NAME "ctrl_thread"

module userlogic #  
  (
   parameter W_A = 14,
   parameter W_COMM_A = 4,
   parameter W_D = 32,
   parameter SIZE = (1024 * 16)
   )
  (
   input CLK,
   input RST,
   output reg [31:0] sum
   );

  reg [W_A-1:0] read_mem_addr;
  reg [W_D-1:0] read_mem_d;
  reg           read_mem_we;
  wire [W_D-1:0] read_mem_q;

  reg [W_A-1:0] write_mem_addr;
  reg [W_D-1:0] write_mem_d;
  reg           write_mem_we;
  wire [W_D-1:0] write_mem_q;

  wire [W_A-1:0] read_mem0_addr;
  wire [W_D-1:0] read_mem0_d;
  wire           read_mem0_we;
  wire [W_D-1:0] read_mem0_q;

  wire [W_A-1:0] read_mem1_addr;
  wire [W_D-1:0] read_mem1_d;
  wire           read_mem1_we;
  wire [W_D-1:0] read_mem1_q;

  wire [W_A-1:0] write_mem0_addr;
  wire [W_D-1:0] write_mem0_d;
  wire           write_mem0_we;
  wire [W_D-1:0] write_mem0_q;

  wire [W_A-1:0] write_mem1_addr;
  wire [W_D-1:0] write_mem1_d;
  wire           write_mem1_we;
  wire [W_D-1:0] write_mem1_q;

  reg [W_D-1:0]  comm_d;
  reg            comm_enq;
  wire           comm_full;
  wire [W_D-1:0] comm_q;
  reg            comm_deq;
  wire           comm_empty;
  
  reg [3:0] state;

  reg mode;

  assign read_mem0_addr = read_mem_addr;
  assign read_mem0_d = read_mem_d;
  assign read_mem0_we = read_mem_we;
  assign read_mem1_addr = read_mem_addr;
  assign read_mem1_d = read_mem_d;
  assign read_mem1_we = read_mem_we;
  assign read_mem_q = (mode == 0)? read_mem0_q : read_mem1_q;

  assign write_mem0_addr = write_mem_addr;
  assign write_mem0_d = write_mem_d;
  assign write_mem0_we = write_mem_we;
  assign write_mem1_addr = write_mem_addr;
  assign write_mem1_d = write_mem_d;
  assign write_mem1_we = write_mem_we;
  assign write_mem_q = (mode == 0)? write_mem0_q : write_mem1_q;
  
  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      read_mem_we <= 0;
      write_mem_we <= 0;
      comm_deq <= 0;
      comm_enq <= 0;
      mode <= 1;
    end else begin
      // default value
      comm_enq <= 0;
      comm_deq <= 0;
      
      if(state == 0) begin
        sum <= 0;
        read_mem_d <= 0;
        read_mem_we <= 0;
        read_mem_addr <= 0;
        write_mem_d <= 0;
        write_mem_we <= 0;
        write_mem_addr <= 0;
        if(!comm_empty) begin
          comm_deq <= 1;
          state <= 1;
          mode <= !mode;
        end
      end else if(state == 1) begin
        state <= 2;
        read_mem_addr <= 0;
      end else if(state == 2) begin
        state <= 3;
        read_mem_addr <= read_mem_addr + 1;
        write_mem_addr <= 0 - 1;
      end else if(state == 3) begin
        read_mem_addr <= read_mem_addr + 1;
        sum <= sum + read_mem_q;
        write_mem_d <= sum + read_mem_q;
        write_mem_we <= 1;
        write_mem_addr <= write_mem_addr + 1;
        if(read_mem_addr == SIZE-2) begin
          state <= 4;
        end
      end else if(state == 4) begin
        state <= 5;
        sum <= sum + read_mem_q;
        write_mem_d <= sum + read_mem_q;
        write_mem_we <= 1;
        write_mem_addr <= write_mem_addr + 1;
      end else if(state == 5) begin
        state <= 6;
        sum <= sum + read_mem_q;
        write_mem_d <= sum + read_mem_q;
        write_mem_we <= 1;
        write_mem_addr <= write_mem_addr + 1;
      end else if(state == 6) begin
        write_mem_we <= 0;
        state <= 7;
      end else if(state == 7) begin
        if(!comm_full) begin
          comm_d <= sum;
          comm_enq <= 1;
          state <= 8;
        end
      end else if(state == 8) begin
        comm_enq <= 0;
        if(!comm_empty) begin
          comm_deq <= 1;
          state <= 1;
          mode <= !mode;
        end
      end
    end
  end

  
  CoramMemory1P
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(W_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_read_memory0
  (.CLK(CLK),
   .ADDR(read_mem0_addr),
   .D(read_mem0_d),
   .WE(read_mem0_we),
   .Q(read_mem0_q)
   );
  
  CoramMemory1P
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(1),
    .CORAM_ADDR_LEN(W_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_read_memory1
  (.CLK(CLK),
   .ADDR(read_mem1_addr),
   .D(read_mem1_d),
   .WE(read_mem1_we),
   .Q(read_mem1_q)
   );

  CoramMemory1P
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(2),
    .CORAM_ADDR_LEN(W_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_write_memory0
  (.CLK(CLK),
   .ADDR(write_mem0_addr),
   .D(write_mem0_d),
   .WE(write_mem0_we),
   .Q(write_mem0_q)
   );
  
  CoramMemory1P
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(3),
    .CORAM_ADDR_LEN(W_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_write_memory1
  (.CLK(CLK),
   .ADDR(write_mem1_addr),
   .D(write_mem1_d),
   .WE(write_mem1_we),
   .Q(write_mem1_q)
   );
  
  CoramChannel
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(W_COMM_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_comm_channel
  (.CLK(CLK),
   .RST(RST),
   .D(comm_d),
   .ENQ(comm_enq),
   .FULL(comm_full),
   .Q(comm_q),
   .DEQ(comm_deq),
   .EMPTY(comm_empty)
   );

endmodule
  
