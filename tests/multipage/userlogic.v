`include "pycoram.v"

`define THREAD_NAME "ctrl_thread"
`define NUM_BANKS 8

module userlogic #  
  (
   parameter W_A = 7,
   parameter W_COMM_A = 4,
   parameter W_D = 32,
   parameter SIZE = 128
   )
  (
   input CLK,
   input RST,
   output reg [31:0] sum_all
   );

  reg [W_D-1:0]  comm_d;
  reg            comm_enq;
  wire           comm_full;
  wire [W_D-1:0] comm_q;
  reg            comm_deq;
  wire           comm_empty;
  
  reg [3:0] state;

  reg [`NUM_BANKS-1:0] sum_read_pos;
  wire [W_D-1:0] sum_read [0:`NUM_BANKS-1];
  
  genvar i;
  generate for(i=0; i<`NUM_BANKS; i=i+1) begin: loop
    reg [W_A-1:0] mem_addr;
    reg [W_D-1:0] mem_d;
    reg           mem_we;
    wire [W_D-1:0] mem_q;
    reg [W_D-1:0] sum;
    assign sum_read[i] = sum;
    
    always @(posedge CLK) begin
      if(RST) begin
        mem_we <= 0;
      end else begin
        if(state == 0) begin
          sum <= 0;
          mem_d <= 0;
          mem_we <= 0;
          mem_addr <= 0;
        end else if(state == 1) begin
          mem_addr <= 0;
        end else if(state == 2) begin
          mem_addr <= mem_addr + 1;
        end else if(state == 3) begin
          mem_addr <= mem_addr + 1;
          sum <= sum + mem_q;
        end else if(state == 4) begin
          sum <= sum + mem_q;
        end else if(state == 5) begin
          sum <= sum + mem_q;
        end
      end
    end

    WrapperCoramMemory1P
    //CoramMemory1P
      #(
        .CORAM_THREAD_NAME(`THREAD_NAME),
        .CORAM_ID(0),
        .CORAM_SUB_ID(i),
        .CORAM_ADDR_LEN(W_A),
        .CORAM_DATA_WIDTH(W_D)
        )
    inst_data_memory
      (
       .CLK(CLK),
       .ADDR(mem_addr),
       .D(mem_d),
       .WE(mem_we),
       .Q(mem_q)
       );

  end endgenerate

  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      comm_deq <= 0;
      comm_enq <= 0;
      sum_read_pos <= 0;
    end else begin
      // default value
      comm_enq <= 0;
      comm_deq <= 0;
      if(state == 0) begin
        sum_all <= 0;
        if(!comm_empty) begin
          comm_deq <= 1;
          state <= 1;
        end
      end else if(state == 1) begin
        state <= 2;
      end else if(state == 2) begin
        state <= 3;
      end else if(state == 3) begin
        if(loop[0].mem_addr == SIZE-2) begin
          state <= 4;
        end
      end else if(state == 4) begin
        state <= 5;
      end else if(state == 5) begin
        state <= 6;
        sum_read_pos <= 0;
        sum_all <= 0;
      end else if(state == 6) begin
        sum_all <= sum_all + sum_read[sum_read_pos] ;
        sum_read_pos <= sum_read_pos + 1;
        if(sum_read_pos == `NUM_BANKS-1) begin
          state <= 7;
        end
      end else if(state == 7) begin
        if(!comm_full) begin
          comm_d <= sum_all;
          comm_enq <= 1;
          state <= 8;
        end
      end else if(state == 8) begin
        comm_enq <= 0;
        if(!comm_empty) begin
          comm_deq <= 1;
          state <= 1;
        end
      end
    end
  end
  
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
  
module WrapperCoramMemory1P(CLK, ADDR, D, WE, Q);
  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_THREAD_ID = 0;
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  parameter CORAM_ADDR_LEN = 10;
  parameter CORAM_DATA_WIDTH = 32;

  input                         CLK;
  input  [CORAM_ADDR_LEN-1:0]   ADDR;
  input  [CORAM_DATA_WIDTH-1:0] D;
  input                         WE;
  output [CORAM_DATA_WIDTH-1:0] Q;

  CoramMemory1P
  #(
    .CORAM_THREAD_NAME(CORAM_THREAD_NAME),
    .CORAM_THREAD_ID(CORAM_THREAD_ID),
    .CORAM_ID(CORAM_ID),
    .CORAM_SUB_ID(CORAM_SUB_ID),
    .CORAM_ADDR_LEN(CORAM_ADDR_LEN),
    .CORAM_DATA_WIDTH(CORAM_DATA_WIDTH)
    )
  inst_coram
  (.CLK(CLK),
   .ADDR(ADDR),
   .D(D),
   .WE(WE),
   .Q(Q)
   );
  
endmodule
