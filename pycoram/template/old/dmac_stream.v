module DMAC_STREAM #
  (
   //---------------------------------------------------------------------------
   // parameters
   //---------------------------------------------------------------------------
   parameter W_A = 10, // word addressing
   parameter W_D = 32, // should be 2^n
   parameter CORE_ADDR_OFFSET = 2, //log(W_D/8)

   parameter W_EXT_A = 32, // byte addressing
   parameter W_BOUNDARY_A = 12, // for 4KB boundary limitation of AXI
   parameter W_BLEN = 9, //log(MAX_BURST_LEN) + 1
   parameter MAX_BURST_LEN = 256, // burst length

   parameter CMD_FIFO_ADDR_WIDTH = 4,
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
   output     [W_D-1:0]     ext_write_data,
   output                   ext_write_enq,
   input                    ext_write_almost_full,
   input      [W_D-1:0]     ext_read_data,
   output                   ext_read_deq,
   input                    ext_read_empty,
   
   //---------------------------------------------------------------------------
   // External (Address Channel)
   //---------------------------------------------------------------------------
   output reg [W_EXT_A-1:0] ext_addr, // byte addressing
   output reg               ext_read_enable,
   output reg               ext_write_enable,
   output reg [W_BLEN-1:0]  ext_word_size, // in word
   input                    ext_ready,

   //---------------------------------------------------------------------------
   // BRAM 
   //---------------------------------------------------------------------------
   output                   core_read_enable,
   input      [W_D-1:0]     core_read_data,
   input                    core_read_empty,
   output                   core_write_enable, 
   output     [W_D-1:0]     core_write_data,
   input                    core_write_almost_full,

   //---------------------------------------------------------------------------
   // Request Interface from Control Thread (Synchronized to Another clock)
   //---------------------------------------------------------------------------
   input                    req_clk,
   input                    req_rst,
   input [W_EXT_A-1:0]      req_ext_addr, // byte addressing
   input                    req_read_enable,
   input                    req_write_enable,
   input [W_EXT_A:0]        req_word_size, // word
   output                   req_ready,
   output                   req_busy
   );

  //----------------------------------------------------------------------------
  // State Machine 
  //----------------------------------------------------------------------------
  localparam ST_IDLE = 0;
  localparam ST_WRITE_TO_BRAM = 1;
  localparam ST_READ_FROM_BRAM = 2;
  reg [2:0] state;

  //----------------------------------------------------------------------------
  // Command Queue
  //----------------------------------------------------------------------------
  // newest command
  wire [W_EXT_A-1:0] req_tail_ext_addr;
  wire               req_tail_read_enable;
  wire               req_tail_write_enable;
  wire [W_EXT_A:0]   req_tail_word_size;
  
  // oldest command
  wire [W_EXT_A-1:0] req_head_ext_addr;
  wire               req_head_read_enable;
  wire               req_head_write_enable;
  wire [W_EXT_A:0]   req_head_word_size;

  // clock: req_clk
  wire req_enq;
  wire req_full;
  wire req_almost_full;

  // clock: CLK
  reg  req_deq;
  wire req_empty;
  wire req_almost_empty;

  reg local_busy_cdc_from; // CLK
  reg req_busy_reg_cdc_to; // req_clk

  function [W_EXT_A-1:0] addrmask;
    input [W_EXT_A-1:0] in;
    addrmask = { in[W_EXT_A-1:CORE_ADDR_OFFSET], {CORE_ADDR_OFFSET{1'b0}} };
  endfunction
  
  function [W_EXT_A-1:0] get_rest_for_boundary;
    input [W_EXT_A-1:0] addr;
    get_rest_for_boundary = (1 << (W_BOUNDARY_A-CORE_ADDR_OFFSET)) - {1'b0, addr[W_BOUNDARY_A-1:CORE_ADDR_OFFSET]};
  endfunction

  function [W_EXT_A-1:0] min3;
    input [W_EXT_A-1:0] in0;
    input [W_EXT_A-1:0] in1;
    input [W_EXT_A-1:0] in2;
    begin
      min3 = in0;
      if(in1 < min3) min3 = in1;
      if(in2 < min3) min3 = in2;
    end
  endfunction
  
  assign req_enq = req_read_enable || req_write_enable;
  assign req_tail_ext_addr = req_ext_addr;
  assign req_tail_read_enable = req_read_enable;
  assign req_tail_write_enable = req_write_enable;
  assign req_tail_word_size = req_word_size;

  always @(posedge CLK) begin // CLK
    local_busy_cdc_from <= !(state == ST_IDLE) || !req_empty;
  end
  
  always @(posedge req_clk) begin // req_clk
    req_busy_reg_cdc_to <= local_busy_cdc_from;
  end

  generate if(ASYNC) begin
    assign req_busy = req_busy_reg_cdc_to; // req_clk
  end else begin
    assign req_busy = local_busy_cdc_from;
  end endgenerate
  assign req_ready = !req_almost_full; // req_clk
  
  dmac_stream_cmd_queue #
   (
    .W_EXT_A(W_EXT_A),
    .FIFO_ADDR_WIDTH(CMD_FIFO_ADDR_WIDTH),
    .ASYNC(ASYNC)
   )
  inst_dmac_stream_cmd_queue
   (
    .tail_clk(req_clk),
    .tail_rst(req_rst),
    
    .head_clk(CLK),
    .head_rst(RST),

    .tail_ext_addr(req_tail_ext_addr),
    .tail_read_enable(req_tail_read_enable),
    .tail_write_enable(req_tail_write_enable),
    .tail_word_size(req_tail_word_size),

    .head_ext_addr(req_head_ext_addr),
    .head_read_enable(req_head_read_enable),
    .head_write_enable(req_head_write_enable),
    .head_word_size(req_head_word_size),

    .enq(req_enq),
    .full(req_full),
    .almost_full(req_almost_full),

    .deq(req_deq),
    .empty(req_empty),
    .almost_empty(req_almost_empty)
   );

  //----------------------------------------------------------------------------
  // Internal Registers
  //----------------------------------------------------------------------------
  reg               d_core_read_enable;
  
  reg [W_EXT_A-1:0] cur_ext_addr;
  reg [W_EXT_A-1:0] cur_word_size;
  reg               read_wait;
  reg               write_wait;
  reg [W_EXT_A:0]   read_count;
  reg [W_EXT_A:0]   write_count;

  assign core_read_enable = write_wait && !ext_write_almost_full && write_count > 0 &&
                            !core_read_empty; // Transparent
  assign core_write_enable = read_wait && !ext_read_empty && read_count > 0 && 
                             !core_write_almost_full; // Transparent
  assign core_write_data = ext_read_data;
  assign ext_read_deq = (state == ST_WRITE_TO_BRAM) && 
                        read_wait && !ext_read_empty && (read_count > 0) &&
                        !core_write_almost_full;
  assign ext_write_enq = write_wait && d_core_read_enable;
  assign ext_write_data = core_read_data;

  //----------------------------------------------------------------------------
  always @(posedge CLK) begin
    if(RST) begin
      state <= ST_IDLE;
      req_deq <= 0;
      ext_addr <= 0;
      ext_read_enable <= 0;
      ext_write_enable <= 0;
      cur_ext_addr <= 0;
      cur_word_size <= 0;
      read_wait <= 0;
      write_wait <= 0;
      read_count <= 0;
      write_count <= 0;
    end else begin
      // default value
      req_deq <= 0;
      // state machine
      case(state)
        //----------------------------------------------------------------------
        ST_IDLE: begin
          if(!req_deq && !req_empty) begin
            req_deq <= 1;
          end
          if(req_deq && req_head_write_enable) begin
            if(req_head_word_size == 0) begin
              // do nothing
            end else begin
              state <= ST_WRITE_TO_BRAM;
            end
            cur_ext_addr <= addrmask(req_head_ext_addr);
            cur_word_size <= req_head_word_size;
            read_wait <= 0;
            write_wait <= 0;
          end else if(req_deq && req_head_read_enable) begin
            if(req_head_word_size == 0) begin
              // do nothing
            end else begin
              state <= ST_READ_FROM_BRAM;
            end
            cur_ext_addr <= addrmask(req_head_ext_addr);
            cur_word_size <= req_head_word_size;
            read_wait <= 0;
            write_wait <= 0;
          end
        end
        //----------------------------------------------------------------------
        ST_WRITE_TO_BRAM: begin
          if(!read_wait) begin
            ext_addr <= cur_ext_addr;
            ext_read_enable <= 1;
            ext_word_size <= min3(cur_word_size, get_rest_for_boundary(cur_ext_addr), MAX_BURST_LEN);
            read_count <= min3(cur_word_size, get_rest_for_boundary(cur_ext_addr), MAX_BURST_LEN);
            read_wait <= 1;
          end
          if(read_wait && !ext_read_empty && read_count > 0 &&
             !core_write_almost_full) begin
            read_count <= read_count - 1;
          end
          if(read_wait && ext_ready) begin
            ext_read_enable <= 0;
            cur_ext_addr <= cur_ext_addr + (ext_word_size << CORE_ADDR_OFFSET);
            cur_word_size <= cur_word_size - ext_word_size;
          end
          if(read_wait && !ext_read_enable && read_count == 0) begin
            if(cur_word_size == 0) begin
              state <= ST_IDLE;
            end else begin
              state <= ST_WRITE_TO_BRAM;
              read_wait <= 0;
            end
          end
        end
        //----------------------------------------------------------------------
        ST_READ_FROM_BRAM: begin
          d_core_read_enable <= core_read_enable;
          if(!write_wait) begin
            ext_addr <= cur_ext_addr;
            ext_write_enable <= 1;
            ext_word_size <= min3(cur_word_size, get_rest_for_boundary(cur_ext_addr), MAX_BURST_LEN);
            write_count <= min3(cur_word_size, get_rest_for_boundary(cur_ext_addr), MAX_BURST_LEN);
            write_wait <= 1;
          end
          if(write_wait && !ext_write_almost_full && write_count > 0 &&
             !core_read_empty) begin
            write_count <= write_count - 1;
          end
          if(write_wait && ext_ready) begin
            ext_write_enable <= 0;
            cur_ext_addr <= cur_ext_addr + (ext_word_size << CORE_ADDR_OFFSET);
            cur_word_size <= cur_word_size - ext_word_size;
          end
          if(write_wait && !ext_write_enable && write_count == 0) begin
            if(cur_word_size == 0) begin
              state <= ST_IDLE;
            end else begin
              state <= ST_READ_FROM_BRAM;
              write_wait <= 0;
            end
          end
        end
      endcase
    end
  end
  
endmodule
  
module dmac_stream_cmd_queue #
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
   input                    tail_read_enable,
   input                    tail_write_enable,
   input [W_EXT_A:0]        tail_word_size, // word

   // output data
   output [W_EXT_A-1:0]     head_ext_addr, // byte addressoutg
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

  localparam FIFO_DATA_WIDTH = (W_EXT_A) + (1) + (1) + (W_EXT_A + 1);

  wire [FIFO_DATA_WIDTH-1:0] data_in;
  wire [FIFO_DATA_WIDTH-1:0] data_out;
  
  assign data_in = {tail_ext_addr,
                    tail_read_enable, tail_write_enable,
                    tail_word_size};
  assign {head_ext_addr,
          head_read_enable, head_write_enable,
          head_word_size} = data_out;

  dmac_stream_cmd_fifo #
    (
     .ADDR_LEN(FIFO_ADDR_WIDTH),
     .DATA_WIDTH(FIFO_DATA_WIDTH),
     .ASYNC(ASYNC)
     )
  inst_dmac_stream_cmd_fifo
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

module dmac_stream_cmd_fifo(CLK0, RST0, Q, DEQ, EMPTY, ALM_EMPTY,
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

    dmac_stream_cmd_fifo_ram #(.W_A(ADDR_LEN), .W_D(DATA_WIDTH))
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

    dmac_stream_cmd_fifo_ram #(.W_A(ADDR_LEN), .W_D(DATA_WIDTH))
    ram (.CLK0(CLK0), .ADDR0(head), .D0('h0), .WE0(1'b0), .Q0(Q), // read
         .CLK1(CLK0), .ADDR1(tail), .D1(D), .WE1(ram_we), .Q1()); // write

  end endgenerate

endmodule

module dmac_stream_cmd_fifo_ram(CLK0, ADDR0, D0, WE0, Q0,
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

