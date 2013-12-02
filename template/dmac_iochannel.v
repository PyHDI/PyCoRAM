module DMAC_IOCHANNEL #
  (
   //---------------------------------------------------------------------------
   // parameters
   //---------------------------------------------------------------------------
   parameter W_D = 32, // should be 2^n

   parameter W_EXT_A = 32, // byte addressing
   parameter W_BOUNDARY_A = 12, // for 4KB boundary limitation of AXI
   parameter W_BLEN = 9, //log(MAX_BURST_LEN) + 1
   parameter MAX_BURST_LEN = 256, // burst length

   parameter FIFO_ADDR_WIDTH = 4,
   parameter ASYNC = 1
   )
  (
   //---------------------------------------------------------------------------
   // System I/O
   //---------------------------------------------------------------------------
   input CLK,
   input RST,

   //---------------------------------------------------------------------------
   // External (Data Channel) (Transparent FIFO)
   //---------------------------------------------------------------------------
   input      [W_D-1:0]     ext_write_data,
   output                   ext_write_deq,
   input                    ext_write_empty,
   output     [W_D-1:0]     ext_read_data,
   output                   ext_read_enq,
   input                    ext_read_almost_full,
   
   //---------------------------------------------------------------------------
   // External (Address Channel)
   //---------------------------------------------------------------------------
   input [W_EXT_A-1:0]      ext_addr, // byte addressing
   input                    ext_read_enable,
   input                    ext_write_enable,
   input [W_BLEN-1:0]       ext_word_size, // in word
   output reg               ext_ready,

   //---------------------------------------------------------------------------
   // Control Thread
   //---------------------------------------------------------------------------
   input                    coram_clk,
   input                    coram_rst,
   
   input                    coram_deq,
   output     [W_D-1:0]     coram_q,
   output                   coram_empty,
   output                   coram_almost_empty,
   
   input                    coram_enq,
   input      [W_D-1:0]     coram_d,
   output                   coram_full,
   output                   coram_almost_full
   );

  //----------------------------------------------------------------------------
  // FIFO
  //----------------------------------------------------------------------------
  reg d_fifo_read_deq;
  wire fifo_read_deq;
  wire [W_D-1:0] fifo_read_data;
  wire fifo_read_empty;
  wire fifo_read_almost_empty;

  wire fifo_write_enq;
  wire [W_D-1:0] fifo_write_data;
  wire fifo_write_full;
  wire fifo_write_almost_full;

  //----------------------------------------------------------------------------
  assign ext_write_deq = !ext_write_empty && !fifo_write_almost_full; // Transparent
  assign fifo_write_enq = !ext_write_empty && !fifo_write_almost_full; // Transparent
  assign fifo_write_data = ext_write_data;
  assign fifo_read_deq = !ext_read_almost_full && !fifo_read_empty;
  assign ext_read_data = fifo_read_data;
  assign ext_read_enq = d_fifo_read_deq;
  
  //----------------------------------------------------------------------------
  always @(posedge CLK) begin
    if(RST) begin
      d_fifo_read_deq <= 0;
      ext_ready <= 0;
    end else begin
      d_fifo_read_deq <= fifo_read_deq;
      ext_ready <= 0;
      if(ext_read_enable) begin
        ext_ready <= 1;
      end else if(ext_read_enable) begin
        ext_ready <= 1;
      end
    end
  end
  
  //----------------------------------------------------------------------------
  dmac_iochannel_fifo # (.ADDR_LEN(FIFO_ADDR_WIDTH), .DATA_WIDTH(W_D), .ASYNC(ASYNC))
  write_fifo
    (.CLK0(coram_clk), .RST0(coram_rst), .Q(coram_q), .DEQ(coram_deq), .EMPTY(coram_empty), .ALM_EMPTY(coram_almost_empty),
     .CLK1(CLK), .RST1(RST), .D(fifo_write_data), .ENQ(fifo_write_enq), .FULL(fifo_write_full), .ALM_FULL(fifo_write_almost_full));

  dmac_iochannel_fifo # (.ADDR_LEN(FIFO_ADDR_WIDTH), .DATA_WIDTH(W_D), .ASYNC(ASYNC))
  read_fifo
    (.CLK0(CLK), .RST0(RST), .Q(fifo_read_data), .DEQ(fifo_read_deq), .EMPTY(fifo_read_empty), .ALM_EMPTY(fifo_read_almost_empty),
     .CLK1(coram_clk), .RST1(coram_rst), .D(coram_d), .ENQ(coram_enq), .FULL(coram_full), .ALM_FULL(coram_almost_full));

endmodule

module dmac_iochannel_fifo(CLK0, RST0, Q, DEQ, EMPTY, ALM_EMPTY,
                             CLK1, RST1, D, ENQ,  FULL,  ALM_FULL);
  parameter ADDR_LEN = 10;
  parameter DATA_WIDTH = 32;
  parameter ASYNC = 1;
  localparam MEM_SIZE = 2 ** ADDR_LEN;

  input                   CLK0;
  input                   RST0;
  output [DATA_WIDTH-1:0] Q;
  input                   DEQ;
  output                  EMPTY;
  output                  ALM_EMPTY;
  
  input                   CLK1;
  input                   RST1;
  input  [DATA_WIDTH-1:0] D;
  input                   ENQ;
  output                  FULL;
  output                  ALM_FULL;

  reg EMPTY;
  reg ALM_EMPTY;
  reg FULL;
  reg ALM_FULL;

  reg [ADDR_LEN-1:0] head;
  reg [ADDR_LEN-1:0] tail;

  reg [ADDR_LEN-1:0] gray_head_cdc_from;
  reg [ADDR_LEN-1:0] gray_tail_cdc_from;

  reg [ADDR_LEN-1:0] d_gray_head_cdc_to;
  reg [ADDR_LEN-1:0] d_gray_tail_cdc_to;

  reg [ADDR_LEN-1:0] dd_gray_head;
  reg [ADDR_LEN-1:0] dd_gray_tail;

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
  
  generate if(ASYNC) begin
    // Read Pointer
    always @(posedge CLK0) begin
      if(RST0) begin
        head <= 0;
        gray_head_cdc_from <= 0;
      end else begin
        if(!EMPTY && DEQ) head <= head == (MEM_SIZE-1)? 0 : head + 1;
        if(!EMPTY && DEQ) gray_head_cdc_from <= head == (MEM_SIZE-1)? to_gray(0) : to_gray(head + 1);
      end
    end
  
    // Write Pointer
    always @(posedge CLK1) begin
      if(RST1) begin
        tail <= 0;
        gray_tail_cdc_from <= 0;
      end else begin
        if(!FULL && ENQ) tail <= tail == (MEM_SIZE-1)? 0 : tail + 1;
        if(!FULL && ENQ) gray_tail_cdc_from <= tail == (MEM_SIZE-1)? to_gray(0) : to_gray(tail + 1);
      end
    end

    // Read Pointer (CLK0 -> CLK1)
    always @(posedge CLK1) begin
      d_gray_head_cdc_to <= gray_head_cdc_from;
      dd_gray_head <= d_gray_head_cdc_to;
    end
    
    // Write Pointer (CLK1 -> CLK0)
    always @(posedge CLK0) begin
      d_gray_tail_cdc_to <= gray_tail_cdc_from;
      dd_gray_tail <= d_gray_tail_cdc_to;
    end

    always @(posedge CLK0) begin
      if(RST0) begin
        EMPTY <= 1'b1;
        ALM_EMPTY <= 1'b1;
      end else begin
        if(DEQ && !EMPTY) begin
          EMPTY <= (dd_gray_tail == to_gray(head+1));
          ALM_EMPTY <= (dd_gray_tail == to_gray(head+2)) || (dd_gray_tail == to_gray(head+1));
        end else begin
          EMPTY <= (dd_gray_tail == to_gray(head));
          ALM_EMPTY <= (dd_gray_tail == to_gray(head+1)) || (dd_gray_tail == to_gray(head));
        end
      end
    end

    always @(posedge CLK1) begin
      if(RST1) begin
        FULL <= 1'b0;
        ALM_FULL <= 1'b0;
      end else begin
        if(ENQ && !FULL) begin
          FULL <= (dd_gray_head == to_gray(tail+2));
          ALM_FULL <= (dd_gray_head == to_gray(tail+3)) || (dd_gray_head == to_gray(tail+2));
        end else begin
          FULL <= (dd_gray_head == to_gray(tail+1));
          ALM_FULL <= (dd_gray_head == to_gray(tail+2)) || (dd_gray_head == to_gray(tail+1));
        end
      end
    end

    dmac_iochannel_fifo_ram #(.W_A(ADDR_LEN), .W_D(DATA_WIDTH))
    ram (.CLK0(CLK0), .ADDR0(head), .D0('h0), .WE0(1'b0), .Q0(Q), // read
         .CLK1(CLK1), .ADDR1(tail), .D1(D), .WE1(ram_we), .Q1()); // write

  end else begin

    // Read Pointer
    always @(posedge CLK0) begin
      if(RST0) begin
        head <= 0;
      end else begin
        if(!EMPTY && DEQ) head <= head == (MEM_SIZE-1)? 0 : head + 1;
      end
    end
  
    // Write Pointer
    always @(posedge CLK0) begin
      if(RST0) begin
        tail <= 0;
      end else begin
        if(!FULL && ENQ) tail <= tail == (MEM_SIZE-1)? 0 : tail + 1;
      end
    end

    always @(posedge CLK0) begin
      if(RST0) begin
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

    always @(posedge CLK0) begin
      if(RST0) begin
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

    dmac_iochannel_fifo_ram #(.W_A(ADDR_LEN), .W_D(DATA_WIDTH))
    ram (.CLK0(CLK0), .ADDR0(head), .D0('h0), .WE0(1'b0), .Q0(Q), // read
         .CLK1(CLK0), .ADDR1(tail), .D1(D), .WE1(ram_we), .Q1()); // write

  end endgenerate

endmodule

module dmac_iochannel_fifo_ram(CLK0, ADDR0, D0, WE0, Q0,
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

