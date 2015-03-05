//------------------------------------------------------------------------------
// Single-Port CoRAM
//------------------------------------------------------------------------------
module CoramMemory1P(CLK, ADDR, D, WE, Q,
                     coram_clk, coram_addr, coram_d, coram_we, coram_q);
  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_THREAD_ID = 0;
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  parameter CORAM_ADDR_LEN = 10;
  parameter CORAM_DATA_WIDTH = 32;
  localparam CORAM_MEM_SIZE = 2 ** CORAM_ADDR_LEN;

  input                         CLK;
  input  [CORAM_ADDR_LEN-1:0]   ADDR;
  input  [CORAM_DATA_WIDTH-1:0] D;
  input                         WE;
  output [CORAM_DATA_WIDTH-1:0] Q;

  input                         coram_clk;
  input  [CORAM_ADDR_LEN-1:0]   coram_addr;
  input  [CORAM_DATA_WIDTH-1:0] coram_d;
  input                         coram_we;
  output [CORAM_DATA_WIDTH-1:0] coram_q;

  CoramBRAM2 #(.W_A(CORAM_ADDR_LEN), .W_D(CORAM_DATA_WIDTH))
  ram (.CLK0(CLK), .ADDR0(ADDR), .D0(D), .WE0(WE), .Q0(Q),
       .CLK1(coram_clk), .ADDR1(coram_addr), .D1(coram_d), .WE1(coram_we), .Q1(coram_q));
endmodule

module CoramMemoryBE1P(CLK, ADDR, D, WE, MASK, Q,
                       coram_clk, coram_addr, coram_d, coram_we, coram_q);
  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_THREAD_ID = 0;
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  parameter CORAM_ADDR_LEN = 10;
  parameter CORAM_DATA_WIDTH = 32;
  localparam CORAM_MEM_SIZE = 2 ** CORAM_ADDR_LEN;
  localparam CORAM_MASK_WIDTH = CORAM_DATA_WIDTH / 8;

  input                         CLK;
  input  [CORAM_ADDR_LEN-1:0]   ADDR;
  input  [CORAM_DATA_WIDTH-1:0] D;
  input                         WE;
  input  [CORAM_MASK_WIDTH-1:0] MASK;
  output [CORAM_DATA_WIDTH-1:0] Q;

  input                         coram_clk;
  input  [CORAM_ADDR_LEN-1:0]   coram_addr;
  input  [CORAM_DATA_WIDTH-1:0] coram_d;
  input                         coram_we;
  output [CORAM_DATA_WIDTH-1:0] coram_q;

  CoramBRAM2BE #(.W_A(CORAM_ADDR_LEN), .W_D(CORAM_DATA_WIDTH))
  ram (.CLK0(CLK), .ADDR0(ADDR), .D0(D), .WE0(WE), .MASK0(MASK), .Q0(Q),
       .CLK1(coram_clk), .ADDR1(coram_addr), .D1(coram_d), .WE1(coram_we), .MASK1({CORAM_MASK_WIDTH{1'b1}}), .Q1(coram_q));
endmodule

//------------------------------------------------------------------------------
// Dual-Port CoRAM
//------------------------------------------------------------------------------
module CoramMemory2P(CLK, ADDR0, D0, WE0, Q0, ADDR1, D1, WE1, Q1,
                     coram_clk, coram_addr, coram_d, coram_we, coram_q);
  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_THREAD_ID = 0;
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  parameter CORAM_ADDR_LEN = 10;
  parameter CORAM_DATA_WIDTH = 32;
  localparam CORAM_MEM_SIZE = 2 ** CORAM_ADDR_LEN;

  input                         CLK;
  input  [CORAM_ADDR_LEN-1:0]   ADDR0;
  input  [CORAM_DATA_WIDTH-1:0] D0;
  input                         WE0;
  output [CORAM_DATA_WIDTH-1:0] Q0;
  input  [CORAM_ADDR_LEN-1:0]   ADDR1;
  input  [CORAM_DATA_WIDTH-1:0] D1;
  input                         WE1;
  output [CORAM_DATA_WIDTH-1:0] Q1;

  input                         coram_clk;
  input  [CORAM_ADDR_LEN-1:0]   coram_addr;
  input  [CORAM_DATA_WIDTH-1:0] coram_d;
  input                         coram_we;
  output [CORAM_DATA_WIDTH-1:0] coram_q;

  CoramBRAM3 #(.W_A(CORAM_ADDR_LEN), .W_D(CORAM_DATA_WIDTH))
  ram (.CLK0(CLK), .ADDR0(ADDR0), .D0(D0), .WE0(WE0), .Q0(Q0),
       .CLK1(CLK), .ADDR1(ADDR1), .D1(D1), .WE1(WE1), .Q1(Q1),
       .CLK2(coram_clk), .ADDR2(coram_addr), .D2(coram_d), .WE2(coram_we), .Q2(coram_q));
endmodule

module CoramMemoryBE2P(CLK, ADDR0, D0, WE0, MASK0, Q0, ADDR1, D1, WE1, MASK1, Q1,
                       coram_clk, coram_addr, coram_d, coram_we, coram_q);
  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_THREAD_ID = 0;
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  parameter CORAM_ADDR_LEN = 10;
  parameter CORAM_DATA_WIDTH = 32;
  localparam CORAM_MEM_SIZE = 2 ** CORAM_ADDR_LEN;
  localparam CORAM_MASK_WIDTH = CORAM_DATA_WIDTH / 8;

  input                         CLK;
  input  [CORAM_ADDR_LEN-1:0]   ADDR0;
  input  [CORAM_DATA_WIDTH-1:0] D0;
  input                         WE0;
  input  [CORAM_MASK_WIDTH-1:0] MASK0;
  output [CORAM_DATA_WIDTH-1:0] Q0;
  input  [CORAM_ADDR_LEN-1:0]   ADDR1;
  input  [CORAM_DATA_WIDTH-1:0] D1;
  input                         WE1;
  input  [CORAM_MASK_WIDTH-1:0] MASK1;
  output [CORAM_DATA_WIDTH-1:0] Q1;

  input                         coram_clk;
  input  [CORAM_ADDR_LEN-1:0]   coram_addr;
  input  [CORAM_DATA_WIDTH-1:0] coram_d;
  input                         coram_we;
  output [CORAM_DATA_WIDTH-1:0] coram_q;

  CoramBRAM3BE #(.W_A(CORAM_ADDR_LEN), .W_D(CORAM_DATA_WIDTH))
  ram (.CLK0(CLK), .ADDR0(ADDR0), .D0(D0), .WE0(WE0), .MASK0(MASK0), .Q0(Q0),
       .CLK1(CLK), .ADDR1(ADDR1), .D1(D1), .WE1(WE1), .MASK1(MASK1), .Q1(Q1),
       .CLK2(coram_clk), .ADDR2(coram_addr), .D2(coram_d), .WE2(coram_we), .MASK2({CORAM_MASK_WIDTH{1'b1}}), .Q2(coram_q));
endmodule

//------------------------------------------------------------------------------
// CoRAM Input Stream (DRAM -> BRAM) (Non-Transparent FIFO with BlockRAM)
//------------------------------------------------------------------------------
module CoramInStream(CLK, RST, Q, DEQ, EMPTY, ALM_EMPTY,
                     coram_clk, coram_rst, coram_d, coram_enq, coram_full, coram_almost_full, coram_room_enq);
  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_THREAD_ID = 0;
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  parameter CORAM_ADDR_LEN = 10;
  parameter CORAM_DATA_WIDTH = 32;
  localparam CORAM_MEM_SIZE = 2 ** CORAM_ADDR_LEN;

  input                         CLK;
  input                         RST;
  output [CORAM_DATA_WIDTH-1:0] Q;
  input                         DEQ;
  output                        EMPTY;
  output                        ALM_EMPTY;
  
  input                         coram_clk;
  input                         coram_rst;
  input  [CORAM_DATA_WIDTH-1:0] coram_d;
  input                         coram_enq;
  output                        coram_full;
  output                        coram_almost_full;
  output [CORAM_ADDR_LEN:0]     coram_room_enq;

  CoramBramFifo # (.CORAM_ADDR_LEN(CORAM_ADDR_LEN), .CORAM_DATA_WIDTH(CORAM_DATA_WIDTH))
  fifo
    (.CLK0(CLK), .RST0(RST), .Q(Q), .DEQ(DEQ), .EMPTY(EMPTY), .ALM_EMPTY(ALM_EMPTY),
     .CLK1(coram_clk), .RST1(coram_rst), .D(coram_d), .ENQ(coram_enq), .FULL(coram_full), .ALM_FULL(coram_almost_full), .ROOM_ENQ(coram_room_enq));

endmodule

//------------------------------------------------------------------------------
// CoRAM Output Stream (BRAM -> DRAM) (Non-Transparent FIFO with BlockRAM)
//------------------------------------------------------------------------------
module CoramOutStream(CLK, RST, D, ENQ, FULL, ALM_FULL,
                      coram_clk, coram_rst, coram_q, coram_deq, coram_empty, coram_almost_empty);
  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_THREAD_ID = 0;
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  parameter CORAM_ADDR_LEN = 4;
  parameter CORAM_DATA_WIDTH = 32;
  localparam CORAM_MEM_SIZE = 2 ** CORAM_ADDR_LEN;

  input                         CLK;
  input                         RST;
  input  [CORAM_DATA_WIDTH-1:0] D;
  input                         ENQ;
  output                        FULL;
  output                        ALM_FULL;
  
  input                         coram_clk;
  input                         coram_rst;
  output [CORAM_DATA_WIDTH-1:0] coram_q;
  input                         coram_deq;
  output                        coram_empty;
  output                        coram_almost_empty;

  CoramBramFifo # (.CORAM_ADDR_LEN(CORAM_ADDR_LEN), .CORAM_DATA_WIDTH(CORAM_DATA_WIDTH))
  fifo
    (.CLK0(coram_clk), .RST0(coram_rst), .Q(coram_q), .DEQ(coram_deq), .EMPTY(coram_empty), .ALM_EMPTY(coram_almost_empty),
     .CLK1(CLK), .RST1(RST), .D(D), .ENQ(ENQ), .FULL(FULL), .ALM_FULL(ALM_FULL));
  
endmodule

//------------------------------------------------------------------------------
// CoRAM FIFO with Block RAM for InStream and OutStream
//------------------------------------------------------------------------------
module CoramBramFifo(CLK0, RST0, Q, DEQ, EMPTY, ALM_EMPTY, ROOM_DEQ,
                     CLK1, RST1, D, ENQ,  FULL,  ALM_FULL, ROOM_ENQ);
  parameter CORAM_ADDR_LEN = 10;
  parameter CORAM_DATA_WIDTH = 32;
  localparam CORAM_MEM_SIZE = 2 ** CORAM_ADDR_LEN;
`ifdef CORAM_SINGLE_CLOCK
  localparam CORAM_ASYNC = 0;
`else
  localparam CORAM_ASYNC = 1;
`endif
  input                         CLK0;
  input                         RST0;
  output [CORAM_DATA_WIDTH-1:0] Q;
  input                         DEQ;
  output                        EMPTY;
  output                        ALM_EMPTY;
  output [CORAM_ADDR_LEN:0]     ROOM_DEQ;
  
  input                         CLK1;
  input                         RST1;
  input  [CORAM_DATA_WIDTH-1:0] D;
  input                         ENQ;
  output                        FULL;
  output                        ALM_FULL;
  output [CORAM_ADDR_LEN:0]     ROOM_ENQ;

  reg EMPTY;
  reg ALM_EMPTY;
  reg FULL;
  reg ALM_FULL;

  reg [CORAM_ADDR_LEN:0] ROOM_DEQ;
  reg [CORAM_ADDR_LEN:0] ROOM_ENQ;
  
  reg [CORAM_ADDR_LEN-1:0] head;
  reg [CORAM_ADDR_LEN-1:0] tail;

  reg [CORAM_ADDR_LEN-1:0] gray_head_cdc_from;
  reg [CORAM_ADDR_LEN-1:0] gray_tail_cdc_from;

  reg [CORAM_ADDR_LEN-1:0] d_gray_head_cdc_to;
  reg [CORAM_ADDR_LEN-1:0] d_gray_tail_cdc_to;

  reg [CORAM_ADDR_LEN-1:0] dd_gray_head;
  reg [CORAM_ADDR_LEN-1:0] dd_gray_tail;

  reg ENQ_cdc_from;
  reg DEQ_cdc_from;
  
  reg d_ENQ_cdc_to;
  reg d_DEQ_cdc_to;
  
  reg dd_ENQ;
  reg dd_DEQ;
  
  wire ram_we;
  assign ram_we = ENQ && !FULL;
  
  function [CORAM_ADDR_LEN-1:0] to_gray;
    input [CORAM_ADDR_LEN-1:0] in;
    to_gray = in ^ (in >> 1);
  endfunction
  
  function [CORAM_ADDR_LEN-1:0] mask;
    input [CORAM_ADDR_LEN-1:0] in;
    mask = in[CORAM_ADDR_LEN-1:0];
  endfunction
  
  generate if(CORAM_ASYNC) begin
    // Read Pointer
    always @(posedge CLK0) begin
      if(RST0) begin
        head <= 0;
        gray_head_cdc_from <= 0;
        DEQ_cdc_from <= 0;
      end else begin
        if(!EMPTY && DEQ) head <= head == (CORAM_MEM_SIZE-1)? 0 : head + 1;
        if(!EMPTY && DEQ) gray_head_cdc_from <= head == (CORAM_MEM_SIZE-1)? to_gray(0) : to_gray(head + 1);
        DEQ_cdc_from <= !EMPTY && DEQ;
      end
    end
  
    // Write Pointer
    always @(posedge CLK1) begin
      if(RST1) begin
        tail <= 0;
        gray_tail_cdc_from <= 0;
        ENQ_cdc_from <= 0;
      end else begin
        if(!FULL && ENQ) tail <= tail == (CORAM_MEM_SIZE-1)? 0 : tail + 1;
        if(!FULL && ENQ) gray_tail_cdc_from <= tail == (CORAM_MEM_SIZE-1)? to_gray(0) : to_gray(tail + 1);
        ENQ_cdc_from <= !FULL && ENQ;
      end
    end

    // Read Pointer (CLK0 -> CLK1)
    always @(posedge CLK1) begin
      d_gray_head_cdc_to <= gray_head_cdc_from;
      dd_gray_head <= d_gray_head_cdc_to;
      d_DEQ_cdc_to <= DEQ_cdc_from;
      dd_DEQ <= d_DEQ_cdc_to;
    end
    
    // Write Pointer (CLK1 -> CLK0)
    always @(posedge CLK0) begin
      d_gray_tail_cdc_to <= gray_tail_cdc_from;
      dd_gray_tail <= d_gray_tail_cdc_to;
      d_ENQ_cdc_to <= ENQ_cdc_from;
      dd_ENQ <= d_ENQ_cdc_to;
    end

    always @(posedge CLK0) begin
      if(RST0) begin
        EMPTY <= 1'b1;
        ALM_EMPTY <= 1'b1;
        ROOM_DEQ <= 0;
      end else begin
        if(DEQ && !EMPTY) begin
          EMPTY <= (dd_gray_tail == to_gray(head+1));
          ALM_EMPTY <= (dd_gray_tail == to_gray(head+2)) || (dd_gray_tail == to_gray(head+1));
          if(!dd_ENQ) ROOM_DEQ <= ROOM_DEQ - 1;
        end else begin
          EMPTY <= (dd_gray_tail == to_gray(head));
          ALM_EMPTY <= (dd_gray_tail == to_gray(head+1)) || (dd_gray_tail == to_gray(head));
          if(dd_ENQ) ROOM_DEQ <= ROOM_DEQ + 1;
        end
      end
    end

    always @(posedge CLK1) begin
      if(RST1) begin
        FULL <= 1'b0;
        ALM_FULL <= 1'b0;
        ROOM_ENQ <= CORAM_MEM_SIZE;
      end else begin
        if(ENQ && !FULL) begin
          FULL <= (dd_gray_head == to_gray(tail+2));
          ALM_FULL <= (dd_gray_head == to_gray(tail+3)) || (dd_gray_head == to_gray(tail+2));
          if(!dd_DEQ) ROOM_ENQ <= ROOM_ENQ - 1;
        end else begin
          FULL <= (dd_gray_head == to_gray(tail+1));
          ALM_FULL <= (dd_gray_head == to_gray(tail+2)) || (dd_gray_head == to_gray(tail+1));
          if(dd_DEQ) ROOM_ENQ <= ROOM_ENQ + 1;
        end
      end
    end

    CoramBRAM2 #(.W_A(CORAM_ADDR_LEN), .W_D(CORAM_DATA_WIDTH))
    ram (.CLK0(CLK0), .ADDR0(head), .D0('h0), .WE0(1'b0), .Q0(Q), // read
         .CLK1(CLK1), .ADDR1(tail), .D1(D), .WE1(ram_we), .Q1()); // write

  end else begin

    // Read Pointer
    always @(posedge CLK0) begin
      if(RST0) begin
        head <= 0;
      end else begin
        if(!EMPTY && DEQ) head <= head == (CORAM_MEM_SIZE-1)? 0 : head + 1;
      end
    end
  
    // Write Pointer
    always @(posedge CLK0) begin
      if(RST0) begin
        tail <= 0;
      end else begin
        if(!FULL && ENQ) tail <= tail == (CORAM_MEM_SIZE-1)? 0 : tail + 1;
      end
    end

    always @(posedge CLK0) begin
      if(RST0) begin
        EMPTY <= 1'b1;
        ALM_EMPTY <= 1'b1;
        ROOM_DEQ <= 0;
      end else begin
        if(DEQ && !EMPTY) begin
          if(ENQ && !FULL) begin
            EMPTY <= (mask(tail+1) == mask(head+1));
            ALM_EMPTY <= (mask(tail+1) == mask(head+2)) || (mask(tail+1) == mask(head+1));
          end else begin
            EMPTY <= (tail == mask(head+1));
            ALM_EMPTY <= (tail == mask(head+2)) || (tail == mask(head+1));
            ROOM_DEQ <= ROOM_DEQ - 1;
          end
        end else begin
          if(ENQ && !FULL) begin
            EMPTY <= (mask(tail+1) == mask(head));
            ALM_EMPTY <= (mask(tail+1) == mask(head+1)) || (mask(tail+1) == mask(head));
            ROOM_DEQ <= ROOM_DEQ + 1;
          end else begin
            EMPTY <= (tail == mask(head));
            ALM_EMPTY <= (tail == mask(head+1)) || (tail == mask(head));
          end
        end
      end
    end

    always @(posedge CLK0) begin
      if(RST0) begin
        FULL <= 1'b0;
        ALM_FULL <= 1'b0;
        ROOM_ENQ <= CORAM_MEM_SIZE;
      end else begin
        if(ENQ && !FULL) begin
          if(DEQ && !EMPTY) begin
            FULL <= (mask(head+1) == mask(tail+2));
            ALM_FULL <= (mask(head+1) == mask(tail+3)) || (mask(head+1) == mask(tail+2));
          end else begin
            FULL <= (head == mask(tail+2));
            ALM_FULL <= (head == mask(tail+3)) || (head == mask(tail+2));
            ROOM_ENQ <= ROOM_ENQ - 1;
          end
        end else begin
          if(DEQ && !EMPTY) begin
            FULL <= (mask(head+1) == mask(tail+1));
            ALM_FULL <= (mask(head+1) == mask(tail+2)) || (mask(head+1) == mask(tail+1));
            ROOM_ENQ <= ROOM_ENQ + 1;
          end else begin
            FULL <= (head == mask(tail+1));
            ALM_FULL <= (head == mask(tail+2)) || (head == mask(tail+1));
          end
        end
      end
    end

    CoramBRAM2 #(.W_A(CORAM_ADDR_LEN), .W_D(CORAM_DATA_WIDTH))
    ram (.CLK0(CLK0), .ADDR0(head), .D0('h0), .WE0(1'b0), .Q0(Q), // read
         .CLK1(CLK0), .ADDR1(tail), .D1(D), .WE1(ram_we), .Q1()); // write

  end endgenerate

endmodule

//------------------------------------------------------------------------------
// CoRAM Channel (Non-Transparent FIFO with BlockRAM)
//------------------------------------------------------------------------------
module CoramChannel(CLK, RST,
                    D, ENQ, FULL, ALM_FULL,
                    Q, DEQ, EMPTY, ALM_EMPTY,
                    coram_clk, coram_rst,
                    coram_q, coram_deq, coram_empty, coram_almost_empty, 
                    coram_d, coram_enq, coram_full, coram_almost_full);
  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_THREAD_ID = 0;
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  parameter CORAM_ADDR_LEN = 4;
  parameter CORAM_DATA_WIDTH = 32;
  localparam CORAM_MEM_SIZE = 2 ** CORAM_ADDR_LEN;

  input                         CLK;
  input                         RST;
  input  [CORAM_DATA_WIDTH-1:0] D;
  input                         ENQ;
  output                        FULL;
  output                        ALM_FULL;
  output [CORAM_DATA_WIDTH-1:0] Q;
  input                         DEQ;
  output                        EMPTY;
  output                        ALM_EMPTY;

  input                         coram_clk;
  input                         coram_rst;
  output [CORAM_DATA_WIDTH-1:0] coram_q;
  input                         coram_deq;
  output                        coram_empty;
  output                        coram_almost_empty;
  input  [CORAM_DATA_WIDTH-1:0] coram_d;
  input                         coram_enq;
  output                        coram_full;
  output                        coram_almost_full;

  CoramBramFifo # (.CORAM_ADDR_LEN(CORAM_ADDR_LEN), .CORAM_DATA_WIDTH(CORAM_DATA_WIDTH))
  write_fifo
    (.CLK0(coram_clk), .RST0(coram_rst), .Q(coram_q), .DEQ(coram_deq), .EMPTY(coram_empty), .ALM_EMPTY(coram_almost_empty),
     .CLK1(CLK), .RST1(RST), .D(D), .ENQ(ENQ), .FULL(FULL), .ALM_FULL(ALM_FULL));

  CoramBramFifo # (.CORAM_ADDR_LEN(CORAM_ADDR_LEN), .CORAM_DATA_WIDTH(CORAM_DATA_WIDTH))
  read_fifo
    (.CLK0(CLK), .RST0(RST), .Q(Q), .DEQ(DEQ), .EMPTY(EMPTY), .ALM_EMPTY(ALM_EMPTY),
     .CLK1(coram_clk), .RST1(coram_rst), .D(coram_d), .ENQ(coram_enq), .FULL(coram_full), .ALM_FULL(coram_almost_full));
  
endmodule

//------------------------------------------------------------------------------
// CoRAM Register
//------------------------------------------------------------------------------
module CoramRegister(CLK, D, WE, Q,
                     coram_clk, coram_d, coram_we, coram_q);
  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_THREAD_ID = 0;
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  parameter CORAM_ADDR_LEN = 10;
  parameter CORAM_DATA_WIDTH = 32;
  localparam CORAM_MEM_SIZE = 2 ** CORAM_ADDR_LEN;
`ifdef CORAM_SINGLE_CLOCK
  localparam CORAM_ASYNC = 0;
`else
  localparam CORAM_ASYNC = 1;
`endif

  input                         CLK;
  input  [CORAM_DATA_WIDTH-1:0] D;
  input                         WE;
  output [CORAM_DATA_WIDTH-1:0] Q;

  input                         coram_clk;
  input  [CORAM_DATA_WIDTH-1:0] coram_d;
  input                         coram_we;
  output [CORAM_DATA_WIDTH-1:0] coram_q;

  reg [CORAM_DATA_WIDTH-1:0] Q;
  reg [CORAM_DATA_WIDTH-1:0] coram_q;
  
  reg [CORAM_DATA_WIDTH-1:0] D_cdc_from;
  reg                        WE_cdc_from;
  reg [CORAM_DATA_WIDTH-1:0] D_cdc_to;
  reg                        WE_cdc_to;
  reg [CORAM_DATA_WIDTH-1:0] coram_d_cdc_from;
  reg                        coram_we_cdc_from;
  reg [CORAM_DATA_WIDTH-1:0] coram_d_cdc_to;
  reg                        coram_we_cdc_to;

  generate if(CORAM_ASYNC) begin
    always @(posedge CLK) begin
      if(WE) Q <= D;
      if(coram_we_cdc_to) Q <= coram_d_cdc_to;
    end

    always @(posedge coram_clk) begin
      if(WE_cdc_to) coram_q <= D_cdc_to;
      if(coram_we) coram_q <= coram_d;
    end

    always @(posedge CLK) begin
      D_cdc_from <= D;
      WE_cdc_from <= WE;
    end
    always @(posedge coram_clk) begin
      D_cdc_to <= D_cdc_from;
      WE_cdc_to <= WE_cdc_from;
    end

    always @(posedge coram_clk) begin
      coram_d_cdc_from <= coram_d;
      coram_we_cdc_from <= coram_we;
    end
    always @(posedge CLK) begin
      coram_d_cdc_to <= coram_d_cdc_from;
      coram_we_cdc_to <= coram_we_cdc_from;
    end
  end else begin
    always @(posedge CLK) begin
      if(WE) begin
        Q <= D;
        coram_q <= D;
      end
      if(coram_we) begin
        Q <= coram_d;
        coram_q <= coram_d;
      end
    end
  end endgenerate
  
endmodule

//------------------------------------------------------------------------------
// CoRAM Slave Stream (Non-Transparent FIFO with BlockRAM)
//------------------------------------------------------------------------------
module CoramSlaveStream(CLK, RST,
                        D, ENQ, FULL, ALM_FULL,
                        Q, DEQ, EMPTY, ALM_EMPTY,
                        coram_clk, coram_rst,
                        coram_q, coram_deq, coram_empty, coram_almost_empty, 
                        coram_d, coram_enq, coram_full, coram_almost_full);
  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_THREAD_ID = 0;
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  parameter CORAM_ADDR_LEN = 4;
  parameter CORAM_DATA_WIDTH = 32;
  localparam CORAM_MEM_SIZE = 2 ** CORAM_ADDR_LEN;

  input                         CLK;
  input                         RST;
  input  [CORAM_DATA_WIDTH-1:0] D;
  input                         ENQ;
  output                        FULL;
  output                        ALM_FULL;
  output [CORAM_DATA_WIDTH-1:0] Q;
  input                         DEQ;
  output                        EMPTY;
  output                        ALM_EMPTY;

  input                         coram_clk;
  input                         coram_rst;
  output [CORAM_DATA_WIDTH-1:0] coram_q;
  input                         coram_deq;
  output                        coram_empty;
  output                        coram_almost_empty;
  input  [CORAM_DATA_WIDTH-1:0] coram_d;
  input                         coram_enq;
  output                        coram_full;
  output                        coram_almost_full;

  CoramBramFifo # (.CORAM_ADDR_LEN(CORAM_ADDR_LEN), .CORAM_DATA_WIDTH(CORAM_DATA_WIDTH))
  write_fifo
    (.CLK0(coram_clk), .RST0(coram_rst), .Q(coram_q), .DEQ(coram_deq), .EMPTY(coram_empty), .ALM_EMPTY(coram_almost_empty),
     .CLK1(CLK), .RST1(RST), .D(D), .ENQ(ENQ), .FULL(FULL), .ALM_FULL(ALM_FULL));

  CoramBramFifo # (.CORAM_ADDR_LEN(CORAM_ADDR_LEN), .CORAM_DATA_WIDTH(CORAM_DATA_WIDTH))
  read_fifo
    (.CLK0(CLK), .RST0(RST), .Q(Q), .DEQ(DEQ), .EMPTY(EMPTY), .ALM_EMPTY(ALM_EMPTY),
     .CLK1(coram_clk), .RST1(coram_rst), .D(coram_d), .ENQ(coram_enq), .FULL(coram_full), .ALM_FULL(coram_almost_full));
  
endmodule

//------------------------------------------------------------------------------
// Single-port BRAM
//------------------------------------------------------------------------------
module CoramBRAM1(CLK, ADDR, D, WE, Q);
  parameter W_A = 10;
  parameter W_D = 32;
  localparam LEN = 2 ** W_A;
  input            CLK;
  input  [W_A-1:0] ADDR;
  input  [W_D-1:0] D;
  input            WE;
  output [W_D-1:0] Q;
  
  reg [W_A-1:0] d_ADDR;
  reg [W_D-1:0] mem [0:LEN-1];
  
  always @(posedge CLK) begin
    if(WE) mem[ADDR] <= D;
    d_ADDR <= ADDR;
  end
  assign Q = mem[d_ADDR];
endmodule

//------------------------------------------------------------------------------
// Single-port BRAM (with MASK)
//------------------------------------------------------------------------------
module CoramBRAM1BE(CLK, ADDR, D, WE, MASK, Q);
  parameter W_A = 10;
  parameter W_D = 32;
  localparam LEN = 2 ** W_A;
  localparam W_M = W_D / 8;
  input            CLK;
  input  [W_A-1:0] ADDR;
  input  [W_D-1:0] D;
  input            WE;
  input  [W_M-1:0] MASK;
  output [W_D-1:0] Q;
  
  reg [W_A-1:0] d_ADDR;
  reg [W_D-1:0] mem [0:LEN-1];

  always @(posedge CLK) begin
    d_ADDR <= ADDR;
  end
  genvar i;
  generate for(i=0; i<W_M; i=i+1) begin: loop
    always @(posedge CLK) begin
      if(WE && MASK[i]) mem[ADDR][8*(i+1)-1:8*i] <= D[8*(i+1)-1:8*i];
    end
  end endgenerate
  assign Q = mem[d_ADDR];
endmodule

//------------------------------------------------------------------------------
// Dual-port BRAM
//------------------------------------------------------------------------------
module CoramBRAM2(CLK0, ADDR0, D0, WE0, Q0, 
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

//------------------------------------------------------------------------------
// Dual-port BRAM (with MASK)
//------------------------------------------------------------------------------
module CoramBRAM2BE(CLK0, ADDR0, D0, WE0, MASK0, Q0,
                    CLK1, ADDR1, D1, WE1, MASK1, Q1);
  parameter W_A = 10;
  parameter W_D = 32;
  localparam LEN = 2 ** W_A;
  localparam W_M = W_D / 8;
  input            CLK0;
  input  [W_A-1:0] ADDR0;
  input  [W_D-1:0] D0;
  input            WE0;
  input  [W_M-1:0] MASK0;
  output [W_D-1:0] Q0;
  input            CLK1;
  input  [W_A-1:0] ADDR1;
  input  [W_D-1:0] D1;
  input            WE1;
  input  [W_M-1:0] MASK1;
  output [W_D-1:0] Q1;
  
  reg [W_A-1:0] d_ADDR0;
  reg [W_A-1:0] d_ADDR1;
  reg [W_D-1:0] mem [0:LEN-1];

  always @(posedge CLK0) begin
    d_ADDR0 <= ADDR0;
  end
  always @(posedge CLK1) begin
    d_ADDR1 <= ADDR1;
  end
  genvar i;
  generate for(i=0; i<W_M; i=i+1) begin: loop
    always @(posedge CLK0) begin
      if(WE0 && MASK0[i]) mem[ADDR0][8*(i+1)-1:8*i] <= D0[8*(i+1)-1:8*i];
    end
    always @(posedge CLK1) begin
      if(WE1 && MASK1[i]) mem[ADDR1][8*(i+1)-1:8*i] <= D1[8*(i+1)-1:8*i];
    end
  end endgenerate
  assign Q0 = mem[d_ADDR0];
  assign Q1 = mem[d_ADDR1];
endmodule

//------------------------------------------------------------------------------
// Triple-port BRAM
//------------------------------------------------------------------------------
module CoramBRAM3(CLK0, ADDR0, D0, WE0, Q0,
                  CLK1, ADDR1, D1, WE1, Q1,
                  CLK2, ADDR2, D2, WE2, Q2);
  parameter W_A = 10;
  parameter W_D = 32;
  localparam LEN = 2 ** W_A;
  localparam W_M = W_D / 8;
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
  input            CLK2;
  input  [W_A-1:0] ADDR2;
  input  [W_D-1:0] D2;
  input            WE2;
  output [W_D-1:0] Q2;
  
  reg [W_A-1:0] d_ADDR0;
  reg [W_A-1:0] d_ADDR1;
  reg [W_A-1:0] d_ADDR2;
  reg [W_D-1:0] mem [0:LEN-1];
  
  always @(posedge CLK0) begin
    if(WE0) mem[ADDR0] <= D0;
    d_ADDR0 <= ADDR0;
  end
  always @(posedge CLK1) begin
    if(WE1) mem[ADDR1] <= D1;
    d_ADDR1 <= ADDR1;
  end
  always @(posedge CLK2) begin
    if(WE2) mem[ADDR2] <= D2;
    d_ADDR2 <= ADDR2;
  end
  assign Q0 = mem[d_ADDR0];
  assign Q1 = mem[d_ADDR1];
  assign Q2 = mem[d_ADDR2];
endmodule

//------------------------------------------------------------------------------
// Triple-port BRAM (with MASK)
//------------------------------------------------------------------------------
module CoramBRAM3BE(CLK0, ADDR0, D0, WE0, MASK0, Q0, 
                    CLK1, ADDR1, D1, WE1, MASK1, Q1, 
                    CLK2, ADDR2, D2, WE2, MASK2, Q2);
  parameter W_A = 10;
  parameter W_D = 32;
  localparam LEN = 2 ** W_A;
  localparam W_M = W_D / 8;
  input            CLK0;
  input  [W_A-1:0] ADDR0;
  input  [W_D-1:0] D0;
  input            WE0;
  input  [W_M-1:0] MASK0;
  output [W_D-1:0] Q0;
  input            CLK1;
  input  [W_A-1:0] ADDR1;
  input  [W_D-1:0] D1;
  input            WE1;
  input  [W_M-1:0] MASK1;
  output [W_D-1:0] Q1;
  input            CLK2;
  input  [W_A-1:0] ADDR2;
  input  [W_D-1:0] D2;
  input            WE2;
  input  [W_M-1:0] MASK2;
  output [W_D-1:0] Q2;
  
  reg [W_A-1:0] d_ADDR0;
  reg [W_A-1:0] d_ADDR1;
  reg [W_A-1:0] d_ADDR2;
  reg [W_D-1:0] mem [0:LEN-1];
  
  always @(posedge CLK0) begin
    d_ADDR0 <= ADDR0;
  end
  always @(posedge CLK1) begin
    d_ADDR1 <= ADDR1;
  end
  always @(posedge CLK2) begin
    d_ADDR2 <= ADDR2;
  end
  genvar i;
  generate for(i=0; i<W_M; i=i+1) begin: loop
    always @(posedge CLK0) begin
      if(WE0 && MASK0[i]) mem[ADDR0][8*(i+1)-1:8*i] <= D0[8*(i+1)-1:8*i];
    end
    always @(posedge CLK1) begin
      if(WE1 && MASK1[i]) mem[ADDR1][8*(i+1)-1:8*i] <= D1[8*(i+1)-1:8*i];
    end
    always @(posedge CLK2) begin
      if(WE2 && MASK2[i]) mem[ADDR2][8*(i+1)-1:8*i] <= D2[8*(i+1)-1:8*i];
    end
  end endgenerate
  assign Q0 = mem[d_ADDR0];
  assign Q1 = mem[d_ADDR1];
  assign Q2 = mem[d_ADDR2];
endmodule

