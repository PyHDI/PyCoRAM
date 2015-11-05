`include "pycoram.v"

module vectorsum #  
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
   parameter W_A = 10
   )
  (
   input CLK,
   input RST
   );

  vectorsum_main #
    (
     .SIMD_WIDTH(SIMD_WIDTH),
     .LOG_SIMD_WIDTH(LOG_SIMD_WIDTH),
     .W_D(W_D),
     .W_A(W_A)
     )
  inst_vectorsum_main
    (
     .CLK(CLK),
     .RST(RST)
     );
  
endmodule

//------------------------------------------------------------------------------
module vectorsum_main #
  (
   parameter SIMD_WIDTH = 4,
   parameter LOG_SIMD_WIDTH = 2,
   parameter W_D = 32,
   parameter W_A = 10,
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

  reg [7:0] state;
  reg [63:0] read_size;
  
  reg [63:0] mem_addr;
  wire [W_D*SIMD_WIDTH-1:0] mem_q;
  wire mem_deq;
  reg d_mem_deq;
  wire mem_empty;
  
  reg [63:0] sum;
  reg [63:0] cyclecount;

  reg [63:0] sum_array [0:SIMD_WIDTH-1];
  reg [7:0] pos;
  
  genvar i;
  generate for(i=0; i<SIMD_WIDTH; i=i+1) begin: loop
    wire [W_D-1:0] mem_q_bank;
    assign mem_q_bank = mem_q[W_D*(i+1)-1:W_D*i];
    always @(posedge CLK) begin
      if(RST) begin
        sum_array[i] <= 0;
      end else begin
        if(state == 'h1) begin
          sum_array[i] <= 0;
        end else if(state == 'h3 && d_mem_deq) begin
          sum_array[i] <= sum_array[i] + mem_q_bank;
        end else if(state == 'h4 && d_mem_deq) begin
          sum_array[i] <= sum_array[i] + mem_q_bank;
        end else if(state == 'h5 && d_mem_deq) begin
          sum_array[i] <= sum_array[i] + mem_q_bank;
        end
      end
    end
  end endgenerate

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

  assign mem_deq = !mem_empty && (state >= 'h2) && (state <= 'h4);
  
  always @(posedge CLK) begin
    if(RST) begin
      state <= 'h0;
      read_size <= 0;
      comm_d <= 0;
      comm_deq <= 0;
      comm_enq <= 0;
      mem_addr <= 0;
      d_mem_deq <= 0;
      sum <= 0;
    end else begin
      comm_deq <= 0;
      comm_enq <= 0;
      d_mem_deq <= mem_deq;
      case(state)
        'h0: begin
          sum <= 0;
          mem_addr <= 0;
          if(!comm_empty) begin
            comm_deq <= 1;
            state <= 'h1;
          end
        end
        'h1: begin
          read_size <= comm_q;
          mem_addr <= 0;
          state <= 'h2;
        end
        'h2: begin
          if(!mem_empty) begin
            mem_addr <= mem_addr + 1;
            state <= 'h3;
          end
        end
        'h3: begin
          if(!mem_empty) begin
            mem_addr <= mem_addr + 1;
            // add here
            if(mem_addr == read_size -2) begin
              state <= 'h4;
            end
          end
        end
        'h4: begin
          if(!mem_empty) begin
            // add here
            state <= 'h5;
          end
        end
        'h5: begin
          // add here
          pos <= 0;
          state <= 'h6;
        end
        'h6: begin
          sum <= sum + sum_array[pos];
          pos <= pos + 1;
          if(pos == SIMD_WIDTH-1) begin
            state <= 'h7;
          end
        end
        'h7: begin
          if(!comm_full) begin
            comm_enq <= 1;
            comm_d <= sum;
            state <= 'h8;
          end
        end
        'h8: begin
          if(!comm_empty) begin
            comm_deq <= 1;
            state <= 'h9;
          end
        end
        'h9: begin
          read_size <= comm_q;
          if(comm_q == 0) begin
            state <= 'h10;
          end else begin
            state <= 'h1;
          end
        end
        'h10: begin
          if(!comm_full) begin
            comm_enq <= 1;
            comm_d <= cyclecount;
            state <= 'h11;
          end
        end
        'h11: begin
          state <= 'h0;
        end
      endcase
    end
  end
  
  CoramInStream #
    (
     .CORAM_THREAD_NAME("cthread_vectorsum"),
     .CORAM_ID(0),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_A),
     .CORAM_DATA_WIDTH(W_D*SIMD_WIDTH)
     )
  inst_instream
    (
     .CLK(CLK),
     .RST(RST),
     .Q(mem_q),
     .DEQ(mem_deq),
     .EMPTY(mem_empty),
     .ALM_EMPTY()
     );
  
  CoramChannel #
    (
     .CORAM_THREAD_NAME("cthread_vectorsum"),
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
  
