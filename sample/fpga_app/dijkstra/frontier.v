//`include "pycoram.v"

`define W_D (32)
`define CMP(__x, __y) (__x[`W_D-1:0] < __y[`W_D-1:0])
`include "heap.v"

`default_nettype none

module frontier #
  (
   parameter W_D = 32,
   parameter W_A = 10,
   parameter W_OCM_A = 8,
   parameter W_COMM_A = 6,
   parameter W_FIFO_A = 8
   )
  (
   input CLK,
   input RST,

   input [W_D-1:0] offset,
   
   input read_req_valid,
   output read_req_ready,
   output read_data_valid,
   output [W_D-1:0] read_node_addr,
   output [W_D-1:0] read_cost,
   output read_empty,
   
   input write_valid,
   output write_ready,
   input [W_D-1:0] write_node_addr,
   input [W_D-1:0] write_cost,

   input reset_state
   );

  wire [W_D*2-1:0] fifo_write_data;
  wire [W_D*2-1:0] fifo_read_data;
  wire fifo_deq;
  wire fifo_empty;
  wire fifo_almost_empty;
  wire fifo_enq;
  wire fifo_full;
  wire fifo_almost_full;
  
  wire heap_read_req_valid;
  wire heap_read_req_ready;
  wire heap_read_data_valid;
  wire [W_D*2-1:0] heap_read_data;
  wire heap_read_empty;
  
  wire [W_D*2-1:0] heap_write_data;
  wire heap_write_valid;
  wire heap_write_ready;

  reg [W_D*2-1:0] d_fifo_read_data;
  reg d_fifo_deq;
  reg d_heap_write_valid;
  reg d_heap_write_ready;
  
  assign heap_read_req_valid = read_req_valid && fifo_empty && !heap_write_valid && !d_heap_write_valid;
  assign read_req_ready = heap_read_req_ready && fifo_empty && !heap_write_valid && !d_heap_write_valid;
  assign read_data_valid = heap_read_data_valid;
  assign {read_node_addr, read_cost} = heap_read_data;
  assign read_empty = heap_read_empty && fifo_empty && !heap_write_valid && !d_heap_write_valid;
  
  assign fifo_write_data = {write_node_addr, write_cost};
  assign fifo_enq = write_valid && !fifo_almost_full;
  assign write_ready = !fifo_almost_full;

  assign heap_write_data = d_heap_write_ready? fifo_read_data : d_fifo_read_data;
  assign heap_write_valid = d_fifo_deq || (d_heap_write_valid && !d_heap_write_ready);
  assign fifo_deq = !fifo_empty && ((heap_write_valid && heap_write_ready) || !heap_write_valid);

  always @(posedge CLK) begin
    if(RST) begin
      d_fifo_read_data <= 0;
      d_fifo_deq <= 0;
      d_heap_write_valid <= 0;
      d_heap_write_ready <= 0;
    end else begin
      if(d_fifo_deq) d_fifo_read_data <= fifo_read_data;
      d_fifo_deq <= fifo_deq;
      d_heap_write_valid <= heap_write_valid;
      d_heap_write_ready <= heap_write_ready;
    end
  end
  
  frontier_fifo #
  (
   .DATA_WIDTH(W_D*2),
   .ADDR_LEN(W_FIFO_A)
   )
  inst_frontier_fifo
  (
   .CLK(CLK),
   .RST(RST),

   .Q(fifo_read_data),
   .DEQ(fifo_deq),
   .EMPTY(fifo_empty),
   .ALM_EMPTY(fifo_almost_empty),

   .D(fifo_write_data),
   .ENQ(fifo_enq),
   .FULL(fifo_full),
   .ALM_FULL(fifo_almost_full)
   );
  
  heap #  
  (
   .W_D(W_D * 2),
   .W_A(W_A),
   .W_OCM_A(W_OCM_A),
   .W_COMM_A(W_COMM_A)
   )
  inst_frontier_heap
  (
   .CLK(CLK),
   .RST(RST),

   .offset({{W_D{1'b0}}, offset}),
   
   .read_req_valid(heap_read_req_valid),
   .read_req_ready(heap_read_req_ready),
   .read_data_valid(heap_read_data_valid),
   .read_data(heap_read_data),
   .read_empty(heap_read_empty),
   
   .write_valid(heap_write_valid),
   .write_ready(heap_write_ready),
   .write_data(heap_write_data),

   .reset_state(reset_state)
  );
endmodule

module frontier_fifo(CLK, RST,
                     Q, DEQ, EMPTY, ALM_EMPTY,
                     D, ENQ,  FULL,  ALM_FULL);
  parameter ADDR_LEN = 10;
  parameter DATA_WIDTH = 32;
  localparam MEM_SIZE = 2 ** ADDR_LEN;
  input                         CLK;
  input                         RST;
  output [DATA_WIDTH-1:0] Q;
  input                         DEQ;
  output                        EMPTY;
  output                        ALM_EMPTY;
  input  [DATA_WIDTH-1:0] D;
  input                         ENQ;
  output                        FULL;
  output                        ALM_FULL;

  reg EMPTY;
  reg ALM_EMPTY;
  reg FULL;
  reg ALM_FULL;

  reg [ADDR_LEN-1:0] head;
  reg [ADDR_LEN-1:0] tail;

  wire ram_we;
  assign ram_we = ENQ && !FULL;
  
  function [ADDR_LEN-1:0] to_gray;
    input [ADDR_LEN-1:0] in;
    to_gray = in ^ (in >> 1);
  endfunction
  
  function [ADDR_LEN-1:0] mask;
    input [ADDR_LEN-1:0] in;
    mask = in[ADDR_LEN-1:0];
  endfunction
  
  // Read Pointer
  always @(posedge CLK) begin
    if(RST) begin
      head <= 0;
    end else begin
      if(!EMPTY && DEQ) head <= head == (MEM_SIZE-1)? 0 : head + 1;
    end
  end
  
  // Write Pointer
  always @(posedge CLK) begin
    if(RST) begin
      tail <= 0;
    end else begin
      if(!FULL && ENQ) tail <= tail == (MEM_SIZE-1)? 0 : tail + 1;
    end
  end
  
  always @(posedge CLK) begin
    if(RST) begin
      EMPTY <= 1'b1;
      ALM_EMPTY <= 1'b1;
    end else begin
      if(DEQ && !EMPTY) begin
        if(ENQ && !FULL) begin
          EMPTY <= (mask(tail+1) == mask(head+1));
          ALM_EMPTY <= (mask(tail+1) == mask(head+2)) || (mask(tail+1) == mask(head+1));
        end else begin
          EMPTY <= (tail == mask(head+1));
          ALM_EMPTY <= (tail == mask(head+2)) || (tail == mask(head+1));
        end
      end else begin
        if(ENQ && !FULL) begin
          EMPTY <= (mask(tail+1) == mask(head));
          ALM_EMPTY <= (mask(tail+1) == mask(head+1)) || (mask(tail+1) == mask(head));
        end else begin
          EMPTY <= (tail == mask(head));
          ALM_EMPTY <= (tail == mask(head+1)) || (tail == mask(head));
        end
      end
    end
  end
  
  always @(posedge CLK) begin
    if(RST) begin
      FULL <= 1'b0;
      ALM_FULL <= 1'b0;
    end else begin
      if(ENQ && !FULL) begin
        if(DEQ && !EMPTY) begin
          FULL <= (mask(head+1) == mask(tail+2));
          ALM_FULL <= (mask(head+1) == mask(tail+3)) || (mask(head+1) == mask(tail+2));
        end else begin
          FULL <= (head == mask(tail+2));
          ALM_FULL <= (head == mask(tail+3)) || (head == mask(tail+2));
        end
      end else begin
        if(DEQ && !EMPTY) begin
          FULL <= (mask(head+1) == mask(tail+1));
          ALM_FULL <= (mask(head+1) == mask(tail+2)) || (mask(head+1) == mask(tail+1));
        end else begin
          FULL <= (head == mask(tail+1));
          ALM_FULL <= (head == mask(tail+2)) || (head == mask(tail+1));
        end
      end
    end
  end
  
  frontier_bram2 #(.W_A(ADDR_LEN), .W_D(DATA_WIDTH))
  ram (.CLK0(CLK), .ADDR0(head), .D0('h0), .WE0(1'b0), .Q0(Q), // read
       .CLK1(CLK), .ADDR1(tail), .D1(D), .WE1(ram_we), .Q1()); // write
  
endmodule

module frontier_bram2(CLK0, ADDR0, D0, WE0, Q0, 
                      CLK1, ADDR1, D1, WE1, Q1);
  parameter W_A = 10;
  parameter W_D = 32;
  localparam LEN = 2 ** W_A;
  input            CLK0;
  input  [W_A-1:0] ADDR0;
  input  [W_D-1:0] D0;
  input            WE0;
  output [W_D-1:0] Q0;
  input            CLK1;
  input  [W_A-1:0] ADDR1;
  input  [W_D-1:0] D1;
  input            WE1;
  output [W_D-1:0] Q1;
  
  reg [W_A-1:0] d_ADDR0;
  reg [W_A-1:0] d_ADDR1;
  reg [W_D-1:0] mem [0:LEN-1];
  
  always @(posedge CLK0) begin
    if(WE0) mem[ADDR0] <= D0;
    d_ADDR0 <= ADDR0;
  end
  always @(posedge CLK1) begin
    if(WE1) mem[ADDR1] <= D1;
    d_ADDR1 <= ADDR1;
  end
  assign Q0 = mem[d_ADDR0];
  assign Q1 = mem[d_ADDR1];
endmodule

`default_nettype wire
