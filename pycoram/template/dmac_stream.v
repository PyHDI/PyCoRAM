module DMAC_STREAM #
  (
   //----------------------------------------------------------------------------
   // User Parameter
   //----------------------------------------------------------------------------
   parameter W_A = 10, // word addressing
   parameter W_D = 32, // power of 2
   parameter W_EXT_A = 32, // byte addressing
   parameter W_EXT_D = 32, // power of 2, should equal to W_D
   parameter ADDRMASK_WIDTH = 2, //log(W_D/8)

   parameter W_BOUNDARY_A = 12, // for 4KB boundary limitation of AXI
   parameter W_BLEN = 8, //log(MAX_BURST_LEN)
   parameter MAX_BURST_LEN = 256, // burst length

   parameter CMD_FIFO_ADDR_WIDTH = 4, // Command Buffer
   parameter ASYNC = 1, // control-thread uses a different clock
   parameter SUPPORTS_WRITE = 1,

   parameter BUS_TYPE = "axi" // "axi", "avalon", "general"
   )
  (

   //----------------------------------------------------------------------------
   // Bus Clock
   //----------------------------------------------------------------------------
   input wire ACLK,
   input wire ARESETN,

   //---------------------------------------------------------------------------
   // User-logic BRAM 
   //---------------------------------------------------------------------------
   output wire              core_read_enable,
   input wire [W_D-1:0]     core_read_data,
   input wire               core_read_empty,
   output wire              core_write_enable, 
   output wire [W_D-1:0]    core_write_data,
   input wire               core_write_almost_full,
   input wire [W_A:0]       core_write_room_enq,

   //---------------------------------------------------------------------------
   // DMA Request from Control Thread
   //---------------------------------------------------------------------------
   input wire               req_clk,
   input wire               req_rst,
   input wire [W_EXT_A-1:0] req_ext_addr, // byte addressing
   input wire               req_read_enable,
   input wire               req_write_enable,
   input wire [W_EXT_A:0]   req_word_size, // word
   output wire              req_ready,
   output wire              req_busy,

   //----------------------------------------------------------------------------
   // Bus Interface
   //----------------------------------------------------------------------------
   // Write Address
   output reg [W_EXT_A-1:0]      awaddr,
   output reg [W_BLEN-1:0]       awlen,
   output reg                    awvalid,
   input wire                    awready,
  
   // Write Data
   output wire [W_EXT_D-1:0]     wdata,
   output wire [(W_EXT_D/8)-1:0] wstrb,
   output wire                   wlast,
   output wire                   wvalid,
   input wire                    wready,

   // Read Address
   output reg [W_EXT_A-1:0]      araddr,
   output reg [W_BLEN-1:0]       arlen,
   output reg                    arvalid,
   input wire                    arready,

   // Read Data
   input wire [W_EXT_D-1:0]     rdata,
   input wire                   rlast,
   input wire                   rvalid,
   output wire                  rready
   );

  //----------------------------------------------------------------------------
  // Reset logic
  //----------------------------------------------------------------------------
  reg aresetn_r;
  reg aresetn_rr;
  reg aresetn_rrr;

  always @(posedge ACLK) begin
    aresetn_r <= ARESETN;
    aresetn_rr <= aresetn_r;
    aresetn_rrr <= aresetn_rr;
  end

  //----------------------------------------------------------------------------
  // mode
  //----------------------------------------------------------------------------
  reg read_offchip_busy;
  reg write_offchip_busy;

  //----------------------------------------------------------------------------
  // Request Queue
  //----------------------------------------------------------------------------
  // newest command (clock: req_clk)
  wire [W_EXT_A-1:0] req_tail_ext_addr;
  wire               req_tail_read_enable;
  wire               req_tail_write_enable;
  wire [W_EXT_A:0]   req_tail_word_size;
  
  // oldest command (clock: ACLK)
  wire [W_EXT_A-1:0] req_head_ext_addr;
  wire               req_head_read_enable;
  wire               req_head_write_enable;
  wire [W_EXT_A:0]   req_head_word_size;

  // clock: req_clk
  wire req_enq;
  wire req_full;
  wire req_almost_full;

  // clock: ACLK
  wire req_deq;
  wire req_empty;
  wire req_almost_empty;

  //----------------------------------------------------------------------------
  // Issued Queue
  //----------------------------------------------------------------------------
  // newest command
  wire               issued_tail_read_enable;
  wire               issued_tail_write_enable;
  wire               issued_tail_burst_trunc;
  wire [W_EXT_A:0]   issued_tail_word_size;
  
  // oldest command
  wire               issued_head_read_enable;
  wire               issued_head_write_enable;
  wire               issued_head_burst_trunc;
  wire [W_EXT_A:0]   issued_head_word_size;

  reg  issued_enq_condition;
  wire issued_enq;
  wire issued_full;
  wire issued_almost_full;

  wire issued_deq;
  wire issued_empty;
  wire issued_almost_empty;
  reg d_issued_deq;

  //------------------------------------------------------------------------------
  // Burst size management
  //------------------------------------------------------------------------------
  reg [2:0] req_state;
  reg [W_EXT_A-1:0] d_req_head_ext_addr;
  reg [W_EXT_A:0]   d_req_head_word_size;
  reg d_req_head_read_enable;
  reg d_req_head_write_enable;
  reg [W_EXT_A:0] rest_for_boundary;
  reg [W_EXT_A:0] size_cap;
  reg burst_trunc;
  
  //------------------------------------------------------------------------------
  reg local_busy_cdc_from; // ACLK
  reg req_busy_reg_cdc_to; // req_clk

  always @(posedge ACLK) begin // clock: ACLK
    local_busy_cdc_from <= read_offchip_busy || write_offchip_busy || !req_empty || !issued_empty || d_issued_deq || (req_state > 0);
  end
  
  always @(posedge req_clk) begin // clock: req_clk
    req_busy_reg_cdc_to <= local_busy_cdc_from;
  end

  generate if(ASYNC) begin
    assign req_busy = req_busy_reg_cdc_to; // clock: req_clk
  end else begin
    assign req_busy = local_busy_cdc_from;
  end endgenerate

  //----------------------------------------------------------------------------
  assign req_ready = !req_almost_full; // clock: req_clk

  assign req_enq = req_read_enable || req_write_enable;
  assign req_tail_ext_addr = req_ext_addr;
  assign req_tail_read_enable = req_read_enable;
  assign req_tail_write_enable = req_write_enable;
  assign req_tail_word_size = req_word_size;
  
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
    
    .head_clk(ACLK),
    .head_rst(~ARESETN),

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
  assign issued_tail_read_enable = awvalid;
  assign issued_tail_write_enable = arvalid;
  assign issued_tail_burst_trunc = burst_trunc;
  assign issued_tail_word_size = arlen + 1;
  //assign issued_enq = (req_state == 3) && ((arvalid && arready) || (awvalid && awready));
  assign issued_enq = (req_state == 3) && issued_enq_condition;
  
  dmac_stream_issued_cmd_queue #
   (
    .W_EXT_A(W_EXT_A),
    .FIFO_ADDR_WIDTH(CMD_FIFO_ADDR_WIDTH)
   )
  inst_issued_cmd_queue
   (
    .clk(ACLK),
    .rst(~ARESETN),

    .tail_read_enable(issued_tail_read_enable),
    .tail_write_enable(issued_tail_write_enable),
    .tail_burst_trunc(issued_tail_burst_trunc),
    .tail_word_size(issued_tail_word_size),

    .head_read_enable(issued_head_read_enable),
    .head_write_enable(issued_head_write_enable),
    .head_burst_trunc(issued_head_burst_trunc),
    .head_word_size(issued_head_word_size),

    .enq(issued_enq),
    .full(issued_full),
    .almost_full(issued_almost_full),

    .deq(issued_deq),
    .empty(issued_empty),
    .almost_empty(issued_almost_empty)
   );
  
  //----------------------------------------------------------------------------
  // Command
  //----------------------------------------------------------------------------
  function [W_EXT_A-1:0] addrmask;
    input [W_EXT_A-1:0] in;
    addrmask = { in[W_EXT_A-1:ADDRMASK_WIDTH], {ADDRMASK_WIDTH{1'b0}} };
  endfunction

  function [W_EXT_A-1:0] get_rest_for_boundary;
    input [W_EXT_A-1:0] addr;
    get_rest_for_boundary = (1 << (W_BOUNDARY_A-ADDRMASK_WIDTH)) - 
                            {1'b0, addr[W_BOUNDARY_A-1:ADDRMASK_WIDTH]};
  endfunction

  assign req_deq = !req_empty && !issued_full && req_state == 0;
  
  always @(posedge ACLK) begin
    if(aresetn_rrr == 0) begin
      arvalid <= 0;
      araddr <= 0;
      arlen <= 0;
      awvalid <= 0;
      awaddr <= 0;
      awlen <= 0;
      d_req_head_ext_addr <= 0;
      d_req_head_read_enable <= 0;
      d_req_head_write_enable <= 0;
      d_req_head_word_size <= 0;
      rest_for_boundary <= 0;
      size_cap <= 0;
      burst_trunc <= 0;
      req_state <= 0;
      issued_enq_condition <= 0;
    end else begin
      issued_enq_condition <= 0;
      case(req_state)
        0: begin // Init
          arvalid <= 0;
          awvalid <= 0;
          burst_trunc <= 0;
          if(req_deq) begin
            req_state <= 1;
          end
        end
        1: begin // Boundary check
          arvalid <= 0;
          awvalid <= 0;
          d_req_head_ext_addr <= addrmask(req_head_ext_addr);
          d_req_head_read_enable <= req_head_read_enable;
          d_req_head_write_enable <= req_head_write_enable;
          d_req_head_word_size <= req_head_word_size;
          rest_for_boundary <= get_rest_for_boundary(req_head_ext_addr);
          if(BUS_TYPE == "avalon")
            size_cap <= (!req_head_write_enable)? 
                        ((req_head_word_size <= MAX_BURST_LEN)? req_head_word_size : MAX_BURST_LEN):
                        ((core_write_room_enq <= MAX_BURST_LEN)?
                         ((req_head_word_size <= core_write_room_enq)? req_head_word_size : core_write_room_enq) :
                         ((req_head_word_size <= MAX_BURST_LEN)? req_head_word_size : MAX_BURST_LEN));
          else
            size_cap <= (req_head_word_size <= MAX_BURST_LEN)? req_head_word_size : MAX_BURST_LEN;
          if(req_head_word_size == 0) req_state <= 0;
          else req_state <= 2;
        end
        2: begin // Issue
          arvalid <= d_req_head_write_enable; // Off-chip -> BRAM 
          araddr <= d_req_head_ext_addr;
          arlen <= (size_cap <= rest_for_boundary)? size_cap -1 : rest_for_boundary -1;
          awvalid <= d_req_head_read_enable; // BRAM -> Off-chip
          awaddr <= d_req_head_ext_addr;
          awlen <= (size_cap <= rest_for_boundary)? size_cap -1 : rest_for_boundary -1;
          req_state <= 3;
          issued_enq_condition <= 1;
        end
        3: begin // Wait
          if((arvalid && arready) || (awvalid && awready)) begin
            arvalid <= 0;
            awvalid <= 0;
            d_req_head_word_size <= d_req_head_word_size - arlen - 1;
            d_req_head_ext_addr <= araddr + ((arlen + 1) << ADDRMASK_WIDTH);
            if(arlen + 1 == d_req_head_word_size) req_state <= 0;
            else req_state <= 4;
          end
        end
        4: begin // Boundary check
          arvalid <= 0;
          awvalid <= 0;
          rest_for_boundary <= get_rest_for_boundary(d_req_head_ext_addr);
          size_cap <= (d_req_head_word_size <= MAX_BURST_LEN)? d_req_head_word_size : MAX_BURST_LEN;
          burst_trunc <= 1;
          req_state <= 2;
        end
      endcase
    end
  end  

  //----------------------------------------------------------------------------
  // Data
  //----------------------------------------------------------------------------
  reg [W_EXT_A:0] read_count;
  reg [W_EXT_A:0] write_count;

  reg d_core_read_enable;
  reg d_wvalid;
  reg d_wready;
  reg [W_EXT_D-1:0] d_wdata;
  
  assign issued_deq = !issued_empty && !d_issued_deq && !read_offchip_busy && !write_offchip_busy;
  
  always @(posedge ACLK) begin
    if(aresetn_rrr == 0) begin
      d_issued_deq <= 0;
      d_core_read_enable <= 0;
      d_wvalid <= 0;
      d_wready <= 0;
      d_wdata <= 0;
    end else begin
      d_issued_deq <= issued_deq;
      d_core_read_enable <= core_read_enable;
      d_wvalid <= wvalid;
      d_wready <= wready;
      d_wdata <= wdata;
    end
  end

  assign rready = !core_write_almost_full && read_offchip_busy;
  assign core_write_enable = rvalid && !core_write_almost_full;
  assign core_write_data = rdata;
  assign core_read_enable = write_offchip_busy && (!wvalid || (wvalid && wready)) &&
                            write_count > 0 && !core_read_empty;
  assign wvalid = write_offchip_busy && (d_core_read_enable || (d_wvalid && !d_wready));
  assign wdata = d_core_read_enable? core_read_data : d_wdata;
  assign wstrb = {(W_EXT_D/8){1'b1}};
  assign wlast = write_count == 0;
  
  always @(posedge ACLK) begin
    if(aresetn_rrr == 0) begin
      read_offchip_busy <= 0;
      write_offchip_busy <= 0;
      read_count <= 0;
      write_count <= 0;

    //------------------------------------------------------------------------------
    // Off-chip -> BRAM
    //------------------------------------------------------------------------------
    end else if(read_offchip_busy) begin
      if(rvalid && core_write_enable) begin
        read_count <= read_count - 1;
        if(read_count == 1) begin
          read_offchip_busy <= 0;
        end
      end

    //------------------------------------------------------------------------------
    // BRAM -> Off-chip
    //------------------------------------------------------------------------------
    end else if(write_offchip_busy) begin
      if(core_read_enable) begin
        write_count <= write_count - 1;
      end
      if(wvalid && wready && wlast) begin
        write_offchip_busy <= 0;
      end

    //------------------------------------------------------------------------------
    // New Command
    //------------------------------------------------------------------------------
    end else if(d_issued_deq) begin
      // Off-chip -> BRAM
      if(issued_head_write_enable) begin
        read_offchip_busy <= 1;
        read_count <= issued_head_word_size;
      end else 
      // BRAM -> Off-chip
      if(issued_head_read_enable) begin
        write_offchip_busy <= 1;
        write_count <= issued_head_word_size;
      end
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

  dmac_stream_fifo #
    (
     .ADDR_LEN(FIFO_ADDR_WIDTH),
     .DATA_WIDTH(FIFO_DATA_WIDTH),
     .ASYNC(ASYNC)
     )
  inst_dmac_stream_fifo
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

module dmac_stream_issued_cmd_queue #
  (
   parameter W_EXT_A = 32,
   parameter FIFO_ADDR_WIDTH = 4
   )
  (
   // input clock / reset
   input                    clk,
   input                    rst,

   // input data
   input                    tail_read_enable,
   input                    tail_write_enable,
   input                    tail_burst_trunc,
   input [W_EXT_A:0]        tail_word_size, // word

   // output data
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

  localparam FIFO_DATA_WIDTH = (1) + (1) + (1) + (W_EXT_A + 1);

  wire [FIFO_DATA_WIDTH-1:0] data_in;
  wire [FIFO_DATA_WIDTH-1:0] data_out;
  
  assign data_in = {tail_read_enable, tail_write_enable, tail_burst_trunc,
                    tail_word_size};
  assign {head_read_enable, head_write_enable, head_burst_trunc,
          head_word_size} = data_out;

  dmac_stream_fifo #
    (
     .ADDR_LEN(FIFO_ADDR_WIDTH),
     .DATA_WIDTH(FIFO_DATA_WIDTH),
     .ASYNC(0)
     )
  inst_dmac_stream_fifo
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

module dmac_stream_fifo(CLK0, RST0, Q, DEQ, EMPTY, ALM_EMPTY,
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

    dmac_stream_fifo_ram #(.W_A(ADDR_LEN), .W_D(DATA_WIDTH))
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

    dmac_stream_fifo_ram #(.W_A(ADDR_LEN), .W_D(DATA_WIDTH))
    ram (.CLK0(CLK0), .ADDR0(head), .D0('h0), .WE0(1'b0), .Q0(Q), // read
         .CLK1(CLK0), .ADDR1(tail), .D1(D), .WE1(ram_we), .Q1()); // write

  end endgenerate

endmodule

module dmac_stream_fifo_ram(CLK0, ADDR0, D0, WE0, Q0,
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

