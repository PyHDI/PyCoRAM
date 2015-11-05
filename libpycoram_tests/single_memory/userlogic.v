`include "pycoram.v"

`define THREAD_NAME "ctrl_thread"

module userlogic #  
  (
   parameter W_A = 10,
   parameter W_COMM_A = 4,
   parameter W_D = 32,
   parameter SIZE = 128
   )
  (
   input CLK,
   input RST,
   output reg [31:0] sum
   );

  reg [W_A-1:0] mem_addr;
  reg [W_D-1:0] mem_d;
  reg           mem_we;
  wire [W_D-1:0] mem_q;
  
  reg [W_D-1:0]  comm_d;
  reg            comm_enq;
  wire           comm_full;
  wire [W_D-1:0] comm_q;
  reg            comm_deq;
  wire           comm_empty;
  
  reg [3:0] state;

  
  
  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      mem_we <= 0;
      comm_deq <= 0;
      comm_enq <= 0;
    end else begin
      // default value
      comm_enq <= 0;
      comm_deq <= 0;
      
      if(state == 0) begin
        sum <= 0;
        mem_d <= 0;
        mem_we <= 0;
        mem_addr <= 0;
        if(!comm_empty) begin
          comm_deq <= 1;
          state <= 1;
        end
      end else if(state == 1) begin
        state <= 2;
        mem_addr <= 0;
      end else if(state == 2) begin
        state <= 3;
        mem_addr <= mem_addr + 1;
      end else if(state == 3) begin
        mem_addr <= mem_addr + 1;
        sum <= sum + mem_q;
        if(mem_addr == SIZE-2) begin
          state <= 4;
        end
      end else if(state == 4) begin
        state <= 5;
        sum <= sum + mem_q;
      end else if(state == 5) begin
        state <= 6;
        sum <= sum + mem_q;
      end else if(state == 6) begin
        if(!comm_full) begin
          comm_d <= sum;
          comm_enq <= 1;
          state <= 7;
        end
      end else if(state == 7) begin
        comm_enq <= 0;
        if(!comm_empty) begin
          comm_deq <= 1;
          state <= 1;
        end
      end
    end
  end

  CoramMemory1P
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(0),
    .CORAM_SUB_ID(0),
    .CORAM_ADDR_LEN(W_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_data_memory
  (.CLK(CLK),
   .ADDR(mem_addr),
   .D(mem_d),
   .WE(mem_we),
   .Q(mem_q)
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
  
