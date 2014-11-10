`include "pycoram.v"

module pointer_read_memory #  
  (
   //parameter SIMD_WIDTH = 8,
   //parameter LOG_SIMD_WIDTH = 3,
   //parameter SIMD_WIDTH = 4,
   //parameter LOG_SIMD_WIDTH = 2,
   //parameter SIMD_WIDTH = 2,
   //parameter LOG_SIMD_WIDTH = 1,
   parameter SIMD_WIDTH = 1,
   parameter LOG_SIMD_WIDTH = 0,
   parameter W_D = 32,
   parameter W_A = 12
   )
  (
   input CLK,
   input RST
   );

  pointer_read_memory_main #
    (
     .SIMD_WIDTH(SIMD_WIDTH),
     .LOG_SIMD_WIDTH(LOG_SIMD_WIDTH),
     .W_D(W_D),
     .W_A(W_A)
     )
  inst_pointer_read_memory_main
    (
     .CLK(CLK),
     .RST(RST)
     );
  
endmodule

//------------------------------------------------------------------------------
module pointer_read_memory_main #
  (
   parameter SIMD_WIDTH = 4,
   parameter LOG_SIMD_WIDTH = 2,
   parameter W_D = 32,
   parameter W_A = 12,
   parameter W_COMM_D = 32,
   parameter W_COMM_A = 4
   )
  (
   input CLK,
   input RST
   );

  reg [W_COMM_D-1:0]  comm_d;
  reg                 comm_enq;
  wire                comm_full;
  wire [W_COMM_D-1:0] comm_q;
  reg                 comm_deq;
  wire                comm_empty;

  reg [W_A-1:0] mem_addr;
  reg [W_D*SIMD_WIDTH-1:0] mem_d;
  reg mem_we;
  wire [W_D*SIMD_WIDTH-1:0] mem_q; // unused

  reg [W_D-1:0] read_size;
  reg [W_D-1:0] next_addr;
  
  reg [7:0] state;
  reg [63:0] cyclecount;
  
  always @(posedge CLK) begin
    if(RST) begin
      cyclecount <= 0;
    end else begin
      if(state == 'h0) begin
        cyclecount <= 0;
      end else begin
        cyclecount <= cyclecount + 1;
      end
    end
  end

  always @(posedge CLK) begin
    if(RST) begin
      state <= 'h0;
      comm_d <= 0;
      comm_deq <= 0;
      comm_enq <= 0;
      mem_addr <= 0;
      mem_we <= 0;
      mem_d <= 0;
      read_size <= 0;
      next_addr <= 0;
    end else begin
      comm_deq <= 0;
      comm_enq <= 0;
      mem_we <= 0;
      mem_d <= 0;
      case(state)
        'h0: begin
          if(!comm_empty) begin
            comm_deq <= 1;
            state <= 'h1;
          end
        end
        'h1: begin
          state <= 'h2;
        end
        'h2: begin
          if(!comm_empty) begin
            comm_deq <= 1;
            state <= 'h3;
          end
        end
        'h3: begin
          if(comm_q == 0) begin // finish
            state <= 'h10;
          end else begin // computation
            read_size <= comm_q;
            mem_addr <= 0;
            state <= 'h4;
          end
        end
        'h4: begin
          mem_addr <= 0;
          state <= 'h5;
        end
        'h5: begin
          mem_addr <= mem_addr + 1;
          if(mem_addr == 0) next_addr <= mem_q;
          //read_data <= mem_q;
          if(mem_addr == read_size-1) state <= 'h6;
        end
        'h6: begin
          //read_data <= mem_q;
          state <= 'h7;
        end
        'h7: begin
          if(!comm_full) begin
            comm_d <= next_addr;
            comm_enq <= 1;
            state <= 'h8;
          end
        end
        'h8: begin
          state <= 'h2;
        end
        // Finish
        'h10: begin
          if(!comm_full) begin
            comm_enq <= 1;
            comm_d <= cyclecount;
            state <= 'h0;
          end
        end
      endcase
    end
  end
  
  CoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_pointer_read_memory"),
     .CORAM_ID(0),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_A),
     .CORAM_DATA_WIDTH(W_D*SIMD_WIDTH)
     )
  inst_memory0
    (
     .CLK(CLK),
     .ADDR(mem_addr),
     .D(mem_d),
     .WE(mem_we),
     .Q(mem_q)
     );
  
  CoramChannel #
    (
     .CORAM_THREAD_NAME("cthread_pointer_read_memory"),
     .CORAM_ID(0),
     .CORAM_ADDR_LEN(W_COMM_A),
     .CORAM_DATA_WIDTH(W_COMM_D)
     )
  inst_comm_channel
    (
     .CLK(CLK),
     .RST(RST),
     .D(comm_d),
     .ENQ(comm_enq),
     .FULL(comm_full),
     .Q(comm_q),
     .DEQ(comm_deq),
     .EMPTY(comm_empty)
     );

endmodule
  
