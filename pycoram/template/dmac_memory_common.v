module dmac_memory_cmd_queue #
  (
   parameter W_EXT_A = 32,
   parameter FIFO_ADDR_WIDTH = 4,
   parameter ASYNC = 1
   )
  (
   // input clock / reset
   input                    tail_clk,
   input                    tail_rst,

   // output clock / reset
   input                    head_clk,
   input                    head_rst,
   
   // input data
   input [W_EXT_A-1:0]      tail_ext_addr, // byte addressing
   input [W_EXT_A-1:0]      tail_core_addr, // word addressing
   input                    tail_read_enable,
   input                    tail_write_enable,
   input [W_EXT_A:0]        tail_word_size, // word

   // output data
   output [W_EXT_A-1:0]     head_ext_addr, // byte addressoutg
   output [W_EXT_A-1:0]     head_core_addr, // word addressoutg
   output                   head_read_enable,
   output                   head_write_enable,
   output [W_EXT_A:0]       head_word_size, // word

   // input enq
   input                    enq,
   output                   full,
   output                   almost_full,

   // output deq
   input                    deq,
   output                   empty,
   output                   almost_empty
   );

  localparam FIFO_DATA_WIDTH = (W_EXT_A) + (W_EXT_A) + (1) + (1) + (W_EXT_A + 1);

  wire [FIFO_DATA_WIDTH-1:0] data_in;
  wire [FIFO_DATA_WIDTH-1:0] data_out;
  
  assign data_in = {tail_ext_addr, tail_core_addr,
                    tail_read_enable, tail_write_enable,
                    tail_word_size};
  assign {head_ext_addr, head_core_addr,
          head_read_enable, head_write_enable,
          head_word_size} = data_out;

  dmac_memory_fifo #
    (
     .ADDR_LEN(FIFO_ADDR_WIDTH),
     .DATA_WIDTH(FIFO_DATA_WIDTH),
     .ASYNC(ASYNC)
     )
  inst_dmac_memory_fifo
    (
     .CLK0(head_clk),
     .RST0(head_rst),
     .Q(data_out),
     .DEQ(deq),
     .EMPTY(empty),
     .ALM_EMPTY(almost_empty),
     .CLK1(tail_clk),
     .RST1(tail_rst),
     .D(data_in),
     .ENQ(enq),
     .FULL(full),
     .ALM_FULL(almost_full)
     );
  
endmodule  

module dmac_memory_issued_cmd_queue #
  (
   parameter W_EXT_A = 32,
   parameter FIFO_ADDR_WIDTH = 4
   )
  (
   // input clock / reset
   input                    clk,
   input                    rst,

   // input data
   input [W_EXT_A-1:0]      tail_core_addr, // word addressing
   input                    tail_read_enable,
   input                    tail_write_enable,
   input                    tail_burst_trunc,
   input [W_EXT_A:0]        tail_word_size, // word

   // output data
   output [W_EXT_A-1:0]     head_core_addr, // word addressoutg
   output                   head_read_enable,
   output                   head_write_enable,
   output                   head_burst_trunc,
   output [W_EXT_A:0]       head_word_size, // word

   // input enq
   input                    enq,
   output                   full,
   output                   almost_full,

   // output deq
   input                    deq,
   output                   empty,
   output                   almost_empty
   );

  localparam FIFO_DATA_WIDTH = (W_EXT_A) + (1) + (1) + (1) + (W_EXT_A + 1);

  wire [FIFO_DATA_WIDTH-1:0] data_in;
  wire [FIFO_DATA_WIDTH-1:0] data_out;
  
  assign data_in = {tail_core_addr,
                    tail_read_enable, tail_write_enable, tail_burst_trunc,
                    tail_word_size};
  assign {head_core_addr,
          head_read_enable, head_write_enable, head_burst_trunc,
          head_word_size} = data_out;

  dmac_memory_fifo #
    (
     .ADDR_LEN(FIFO_ADDR_WIDTH),
     .DATA_WIDTH(FIFO_DATA_WIDTH),
     .ASYNC(0)
     )
  inst_dmac_memory_fifo
    (
     .CLK0(clk),
     .RST0(rst),
     .Q(data_out),
     .DEQ(deq),
     .EMPTY(empty),
     .ALM_EMPTY(almost_empty),
     .CLK1(clk),
     .RST1(rst),
     .D(data_in),
     .ENQ(enq),
     .FULL(full),
     .ALM_FULL(almost_full)
     );
  
endmodule  

module dmac_memory_fifo(CLK0, RST0, Q, DEQ, EMPTY, ALM_EMPTY,
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

    dmac_memory_fifo_ram #(.W_A(ADDR_LEN), .W_D(DATA_WIDTH))
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

    dmac_memory_fifo_ram #(.W_A(ADDR_LEN), .W_D(DATA_WIDTH))
    ram (.CLK0(CLK0), .ADDR0(head), .D0('h0), .WE0(1'b0), .Q0(Q), // read
         .CLK1(CLK0), .ADDR1(tail), .D1(D), .WE1(ram_we), .Q1()); // write

  end endgenerate

endmodule

module dmac_memory_fifo_ram(CLK0, ADDR0, D0, WE0, Q0,
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

