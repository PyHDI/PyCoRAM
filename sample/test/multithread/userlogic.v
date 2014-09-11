`include "pycoram.v"
`define THREAD0 "ctrl_thread_0"
`define THREAD1 "ctrl_thread_1"

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
   output reg [31:0] sum
   );

  reg [W_A-1:0] mem0_addr;
  reg [W_D-1:0] mem0_d;
  reg           mem0_we;
  wire [W_D-1:0] mem0_q;
  reg [31:0] sum0;
  
  reg [W_A-1:0] mem1_addr;
  reg [W_D-1:0] mem1_d;
  reg           mem1_we;
  wire [W_D-1:0] mem1_q;
  reg [31:0] sum1;
  
  reg [W_D-1:0]  comm0_d;
  reg            comm0_enq;
  wire           comm0_full;
  wire [W_D-1:0] comm0_q;
  reg            comm0_deq;
  wire           comm0_empty;

  reg [W_D-1:0]  comm1_d;
  reg            comm1_enq;
  wire           comm1_full;
  wire [W_D-1:0] comm1_q;
  reg            comm1_deq;
  wire           comm1_empty;
  
  reg [3:0] state;
  
  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      mem0_we <= 0;
      mem1_we <= 0;
      comm0_deq <= 0;
      comm0_enq <= 0;
      comm1_deq <= 0;
      comm1_enq <= 0;
    end else begin
      // default value
      comm0_enq <= 0;
      comm0_deq <= 0;
      comm1_enq <= 0;
      comm1_deq <= 0;
      
      if(state == 0) begin
        sum0 <= 0;
        sum1 <= 0;
        sum <= 0;
        mem0_d <= 0;
        mem0_we <= 0;
        mem0_addr <= 0;
        mem1_d <= 0;
        mem1_we <= 0;
        mem1_addr <= 0;
        if(!comm0_empty && !comm1_empty) begin
          comm0_deq <= 1;
          comm1_deq <= 1;
          state <= 1;
        end
      end else if(state == 1) begin
        state <= 2;
        mem0_addr <= 0;
        mem1_addr <= 0;
      end else if(state == 2) begin
        state <= 3;
        mem0_addr <= mem0_addr + 1;
        mem1_addr <= mem1_addr + 1;
      end else if(state == 3) begin
        mem0_addr <= mem0_addr + 1;
        mem1_addr <= mem1_addr + 1;
        sum0 <= sum0 + mem0_q;
        sum1 <= sum1 + mem1_q;
        if(mem0_addr == SIZE-2) begin
          state <= 4;
        end
      end else if(state == 4) begin
        state <= 5;
        sum0 <= sum0 + mem0_q;
        sum1 <= sum1 + mem1_q;
      end else if(state == 5) begin
        state <= 6;
        sum0 <= sum0 + mem0_q;
        sum1 <= sum1 + mem1_q;
      end else if(state == 6) begin
        if(!comm0_full && !comm1_full) begin
          sum <= sum0 + sum1;
          comm0_d <= sum0 + sum1;
          comm0_enq <= 1;
          comm1_d <= sum0 + sum1;
          comm1_enq <= 1;
          state <= 7;
        end
      end else if(state == 7) begin
        comm0_enq <= 0;
        comm1_enq <= 0;
        if(!comm0_empty && !comm1_empty) begin
          comm0_deq <= 1;
          comm1_deq <= 1;
          state <= 1;
        end
      end
    end
  end

  CoramMemory1P
  #(
    .CORAM_THREAD_NAME(`THREAD0),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(W_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_data_memory0
  (.CLK(CLK),
   .ADDR(mem0_addr),
   .D(mem0_d),
   .WE(mem0_we),
   .Q(mem0_q)
   );

  CoramMemory1P
  #(
    .CORAM_THREAD_NAME(`THREAD1),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(W_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_data_memory1
  (.CLK(CLK),
   .ADDR(mem1_addr),
   .D(mem1_d),
   .WE(mem1_we),
   .Q(mem1_q)
   );

  CoramChannel
  #(
    .CORAM_THREAD_NAME(`THREAD0),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(W_COMM_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_comm_channel0
  (.CLK(CLK),
   .RST(RST),
   .D(comm0_d),
   .ENQ(comm0_enq),
   .FULL(comm0_full),
   .Q(comm0_q),
   .DEQ(comm0_deq),
   .EMPTY(comm0_empty)
   );

  CoramChannel
  #(
    .CORAM_THREAD_NAME(`THREAD1),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(W_COMM_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_comm_channel1
  (.CLK(CLK),
   .RST(RST),
   .D(comm1_d),
   .ENQ(comm1_enq),
   .FULL(comm1_full),
   .Q(comm1_q),
   .DEQ(comm1_deq),
   .EMPTY(comm1_empty)
   );

endmodule
  
