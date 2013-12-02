//`include "pycoram.v"

////////////////////////////////////////////////////////////
// CORAM1 - single-ported CoRAM
//
// Uses standard dual-ported read-write blockRAM
// port A ~ user logic clock domain
// port B ~ system clock domain (CoRAM back-end)
////////////////////////////////////////////////////////////

module PYCORAM1 (CLK, CLK_2X, clk_s, rst_n_s, clk_t, rst_n_t, RST_N, 
               en, wen, addr, din, dout, do_en);

  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_THREAD_ID = 0;
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  parameter CORAM_ADDR_LEN = 10;
  parameter CORAM_DATA_WIDTH = 32;
  
    parameter THREAD	  = "undefined";
    parameter THREAD_ID   = -1;
    parameter OBJECT_ID   = -1;
 
    parameter WIDTH       = 36;
    parameter DEPTH       = 512;
    parameter INDEXWIDTH  = 9;

    // VERY IMPORTANT: SUB_IDs must be placed AFTER the required parameters
    parameter SUB_ID      = -1;
    parameter SUBSUB_ID   = -1;
    parameter SUBSUBSUB_ID  = -1;
    parameter SUBSUBSUBSUB_ID  = -1;
    parameter SUBSUBSUBSUBSUB_ID  = -1;

    input   CLK;
    input   CLK_2X;
    input   clk_s;
    input   rst_n_s;
    input   clk_t;
    input   rst_n_t;
    input   RST_N, en, wen;

    input   [INDEXWIDTH-1:0]  addr;
    input   [WIDTH-1:0] din;
    output  [WIDTH-1:0] dout;
    input   do_en; /* for bluespec */

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
   .ADDR(addr),
   .D(din),
   .WE(wen),
   .Q(dout)
   );
  
endmodule

  
////////////////////////////////////////////////////////////
// CORAM2 - dual-ported CoRAM
//
// Uses triple-ported read-write BlockRAM
// port A/B ~ user logic clock domain (double-pumped)
// port C ~ system clock domain (CoRAM back-end)
////////////////////////////////////////////////////////////

module PYCORAM2 (CLK, CLK_2X, clk_s, rst_n_s, clk_t, rst_n_t, RST_N, 
               en_a, en_b, wen_a, wen_b,
	             addr_a, addr_b, di_a, di_b, do_a, do_a_en, do_b, do_b_en);

  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_THREAD_ID = 0;
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  parameter CORAM_ADDR_LEN = 10;
  parameter CORAM_DATA_WIDTH = 32;
  
    parameter THREAD	  = "undefined";
    parameter THREAD_ID   = -1;
    parameter OBJECT_ID   = -1;

    parameter WIDTH       = 36;
    parameter DEPTH       = 512;
    parameter INDEXWIDTH  = 9;

    // VERY IMPORTANT: SUB_IDs must be placed AFTER the required parameters
    parameter SUB_ID      = -1;
    parameter SUBSUB_ID   = -1;
    parameter SUBSUBSUB_ID  = -1;
    parameter SUBSUBSUBSUB_ID  = -1;
    parameter SUBSUBSUBSUBSUB_ID  = -1; 

    input   CLK;
    input   CLK_2X; // edge-aligned double-pumped clock
    input   clk_s;
    input   rst_n_s;
    input   RST_N, en_a, en_b, wen_a, wen_b;
    input   clk_t;
    input   rst_n_t; 

    input   [INDEXWIDTH-1:0]  addr_a, addr_b;
    input   [WIDTH-1:0] di_a, di_b;
    output  [WIDTH-1:0] do_a, do_b;
    input   do_a_en, do_b_en; /*for bluespec*/

  CoramMemory2P
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
   .ADDR0(addr_a),
   .D0(di_a),
   .WE0(wen_a),
   .Q0(do_a),
   .ADDR1(addr_b),
   .D1(di_b),
   .WE1(wen_b),
   .Q1(do_b)
   );
  
endmodule


////////////////////////////////////////////////////////////
// ChannelFIFO
// User logic decoupled from CoRAM back-end clock domain
////////////////////////////////////////////////////////////

module PYChannelFIFO (CLK, RST_N, clk_t, rst_n_t,
                    din, din_rdy, din_en, dout, dout_rdy, dout_en);

  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_THREAD_ID = 0;
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  parameter CORAM_ADDR_LEN = 10;
  parameter CORAM_DATA_WIDTH = 64;
  
    parameter THREAD	  = "undefined";
    parameter THREAD_ID   = -1;
    parameter OBJECT_ID   = -1;
 
    parameter WIDTH       = 64;
    parameter DEPTH       = 16;
    parameter LOGDEPTH    = 4;

    // VERY IMPORTANT: SUB_IDs must be placed AFTER the required parameters
    parameter SUB_ID      = -1;
    parameter SUBSUB_ID   = -1;
    parameter SUBSUBSUB_ID  = -1;
    parameter SUBSUBSUBSUB_ID  = -1;
    parameter SUBSUBSUBSUBSUB_ID  = -1; 

    input		    CLK;
    input		    clk_t;
    input		    RST_N;
    input		    rst_n_t;

    /////////////// TO CONTROL THREAD ////////////////
    
    input		    dout_en;
    input [WIDTH-1:0]	    dout; // write by user
    output		    dout_rdy;

    /////////////// FROM CONTROL THREAD ////////////////
    
    input		    din_en;
    output [WIDTH-1:0]	    din; // from thread to user
    output		    din_rdy;

  wire not_dout_rdy;
  wire not_din_rdy;
  assign dout_rdy = !not_dout_rdy;
  assign din_rdy = !not_din_rdy;
  
  CoramChannel
  #(
    .CORAM_THREAD_NAME(CORAM_THREAD_NAME),
    .CORAM_THREAD_ID(CORAM_THREAD_ID),
    .CORAM_ID(CORAM_ID),
    .CORAM_SUB_ID(CORAM_SUB_ID),
    .CORAM_ADDR_LEN(CORAM_ADDR_LEN),
    .CORAM_DATA_WIDTH(CORAM_DATA_WIDTH)
    )
  inst_comm_channel
  (.CLK(CLK),
   .RST(!RST_N),
   .D(dout),
   .ENQ(dout_en),
   .FULL(not_dout_rdy),
   .Q(din),
   .DEQ(din_en),
   .EMPTY(not_din_rdy)
   );
endmodule


////////////////////////////////////////////////////////////
// ChannelReg
// User logic decoupled from CoRAM back-end clock domain
//////////////////////////////////////////////////////////// 

module PYChannelReg (CLK, RST_N, clk_t, rst_n_t,
                   din, din_en, dout);

  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_THREAD_ID = 0;
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  parameter CORAM_ADDR_LEN = 10;
  parameter CORAM_DATA_WIDTH = 64;
  
    parameter THREAD	  = "undefined";
    parameter THREAD_ID   = -1;
    parameter OBJECT_ID   = -1;
    parameter WIDTH       = 64;

    // VERY IMPORTANT: SUB_IDs must be placed AFTER the required parameters
    parameter SUB_ID      = -1;
    parameter SUBSUB_ID   = -1;
    parameter SUBSUBSUB_ID  = -1;
    parameter SUBSUBSUBSUB_ID  = -1;
    parameter SUBSUBSUBSUBSUB_ID  = -1;  

    input		    CLK;
    input		    RST_N;
    input		    clk_t;
    input		    rst_n_t;

    // From client
    input   [WIDTH-1:0]	    din;	    // write interface for client
    input		    din_en;	    // ''
    reg [WIDTH-1:0]         din_reg;

    // From control thread
    output [WIDTH-1:0]	    dout;	    // read interface for the client

  CoramRegister
  #(
    .CORAM_THREAD_NAME(CORAM_THREAD_NAME),
    .CORAM_THREAD_ID(CORAM_THREAD_ID),
    .CORAM_ID(CORAM_ID),
    .CORAM_SUB_ID(CORAM_SUB_ID),
    .CORAM_ADDR_LEN(CORAM_ADDR_LEN),
    .CORAM_DATA_WIDTH(CORAM_DATA_WIDTH)
    )
  inst_comm_channel
  (.CLK(CLK),
   .D(din),
   .WE(din_en),
   .Q(dout)
   );
  
endmodule

