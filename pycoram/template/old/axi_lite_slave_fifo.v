module axi_lite_slave_fifo #
  (
   //----------------------------------------------------------------------------
   // User Parameter
   //----------------------------------------------------------------------------
   parameter integer FIFO_ADDR_WIDTH = 4,
   parameter integer USER_ADDR_WIDTH = 8,

   //----------------------------------------------------------------------------
   // AXI Parameter
   //----------------------------------------------------------------------------
   parameter integer C_S_AXI_ADDR_WIDTH            = 32,
   parameter integer C_S_AXI_DATA_WIDTH            = 32
   )
  (
   //----------------------------------------------------------------------------
   // System Signals
   //----------------------------------------------------------------------------
   input wire ACLK,
   input wire ARESETN,

   //----------------------------------------------------------------------------
   // User Interface
   //----------------------------------------------------------------------------
   // Data Channel
   input                              user_write_deq,
   output [C_S_AXI_DATA_WIDTH-1:0]    user_write_data,
   output                             user_write_empty,
   input                              user_read_enq,
   input [C_S_AXI_DATA_WIDTH-1:0]     user_read_data,
   output                             user_read_almost_full,

   // Command Channel
   output reg [USER_ADDR_WIDTH-1:0]   user_addr,
   output reg                         user_read_enable,
   output reg                         user_write_enable,
   input                              user_done,
   
   //----------------------------------------------------------------------------
   // AXI Slave Interface
   //----------------------------------------------------------------------------
   // Slave Interface Write Address Ports
   input  wire [C_S_AXI_ADDR_WIDTH-1:0]   S_AXI_AWADDR,
   input  wire [3-1:0]                    S_AXI_AWPROT,
   input  wire                            S_AXI_AWVALID,
   output wire                            S_AXI_AWREADY,

   // Slave Interface Write Data Ports
   input  wire [C_S_AXI_DATA_WIDTH-1:0]   S_AXI_WDATA,
   input  wire [C_S_AXI_DATA_WIDTH/8-1:0] S_AXI_WSTRB,
   input  wire                            S_AXI_WVALID,
   output wire                            S_AXI_WREADY,

   // Slave Interface Write Response Ports
   output wire [2-1:0]                    S_AXI_BRESP,
   output wire                            S_AXI_BVALID,
   input  wire                            S_AXI_BREADY,

   // Slave Interface Read Address Ports
   input  wire [C_S_AXI_ADDR_WIDTH-1:0]   S_AXI_ARADDR,
   input  wire [3-1:0]                    S_AXI_ARPROT,
   input  wire                            S_AXI_ARVALID,
   output wire                            S_AXI_ARREADY,

   // Slave Interface Read Data Ports
   output wire [C_S_AXI_DATA_WIDTH-1:0]   S_AXI_RDATA,
   output wire [2-1:0]                    S_AXI_RRESP,
   output wire                            S_AXI_RVALID,
   input  wire                            S_AXI_RREADY
   );

  //------------------------------------------------------------------------------
  // Internal Constant
  //------------------------------------------------------------------------------
  localparam BURST_FIXED = 2'b00;
  localparam BURST_INCR  = 2'b01;
  localparam BURST_WRAP  = 2'b10;

  localparam RESP_OKAY   = 2'b00;
  localparam RESP_EXOKAY = 2'b01;
  localparam RESP_SLVERR = 2'b10;
  localparam RESP_DECERR = 2'b11;
  
  //------------------------------------------------------------------------------
  // Data Channel (Read FIFO / Write FIFO)
  //------------------------------------------------------------------------------
  reg                           axi_write_enq;
  reg [C_S_AXI_DATA_WIDTH-1:0]  axi_write_data;
  wire                          axi_write_almost_full;

  wire                          axi_read_deq;
  wire [C_S_AXI_DATA_WIDTH-1:0] axi_read_data;
  wire                          axi_read_empty;

  // Write (AXI -> FIFO)
  axi_lite_slave_data_fifo 
  #(
    .DATA_WIDTH(C_S_AXI_DATA_WIDTH),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    )
  inst_write_fifo
  (
   .ACLK(ACLK), .ARESETN(ARESETN),
   .enq(axi_write_enq), .data_in(axi_write_data), .almost_full(axi_write_almost_full),
   .deq(user_write_deq), .data_out(user_write_data), .empty(user_write_empty)
   );

  // Read (FIFO -> AXI)
  axi_lite_slave_data_fifo 
  #(
    .DATA_WIDTH(C_S_AXI_DATA_WIDTH),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    )
  inst_read_fifo
  (
   .ACLK(ACLK), .ARESETN(ARESETN),
   .enq(user_read_enq), .data_in(user_read_data), .almost_full(user_read_almost_full), 
   .deq(axi_read_deq), .data_out(axi_read_data), .empty(axi_read_empty)
   );
  
  //------------------------------------------------------------------------------
  // Internal Signal
  //------------------------------------------------------------------------------
  reg                            awready;
  reg                            wready;
  reg [2-1:0]                    bresp;
  reg                            bvalid;
  reg                            arready;
  reg [C_S_AXI_DATA_WIDTH-1:0]   rdata;
  reg [2-1:0]                    rresp;
  reg                            rvalid;

  reg read_busy;
  reg write_busy;
  
  //----------------------------------------------------------------------------
  // Write Address (AW)
  //----------------------------------------------------------------------------
  assign S_AXI_AWREADY = awready;

  //----------------------------------------------------------------------------
  // Write Data (W)
  //----------------------------------------------------------------------------
  assign S_AXI_WREADY = wready;

  //----------------------------------------------------------------------------
  // Write Response (B)
  //----------------------------------------------------------------------------
  assign S_AXI_BRESP = bresp;
  assign S_AXI_BVALID = bvalid;

  //----------------------------------------------------------------------------
  // Read Address (AR)
  //----------------------------------------------------------------------------
  assign S_AXI_ARREADY = arready;

  //----------------------------------------------------------------------------
  // Read and Read Response (R)
  //----------------------------------------------------------------------------
  assign S_AXI_RDATA = rdata;
  assign S_AXI_RRESP = rresp;
  assign S_AXI_RVALID = rvalid;
  
  //----------------------------------------------------------------------------
  // Reset Logic
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
  // User State Machine
  //----------------------------------------------------------------------------
  assign axi_read_deq = read_busy && !rvalid && !axi_read_empty;

  always @(posedge ACLK) begin
    if(aresetn_rrr == 0) begin
      arready <= 0;
      awready <= 0;
      wready <= 0;
      bvalid <= 0;
      bresp <= 0;
      rvalid <= 0;
      rdata <= 0;
      rresp <= 0;
      axi_write_enq <= 0;
      axi_write_data <= 0;
      read_busy <= 0;
      write_busy <= 0;
      user_addr <= 0;
      user_read_enable <= 0;
      user_write_enable <= 0;
    end else begin
      //default
      bresp <= RESP_OKAY;
      rresp <= RESP_OKAY;
      arready <= 0;
      awready <= 0;
      wready <= 0;
      bvalid <= 0;
      rvalid <= 0;
      axi_write_enq <= 0;
      user_read_enable <= 0;
      user_write_enable <= 0;

      //----------------------------------------------------------------------
      if(read_busy) begin
        if(rvalid && S_AXI_RREADY) begin
          read_busy <= 0;
        end
        if(rvalid && !S_AXI_RREADY) begin
          rvalid <= 1;
        end
        if(!rvalid && !axi_read_empty) begin
          rvalid <= 1;
          rdata <= axi_read_data;
        end
      //----------------------------------------------------------------------
      end else if(write_busy) begin
        if(S_AXI_WVALID && !axi_write_almost_full) begin
          wready <= 1;
          bvalid <= 1;
          axi_write_enq <= 1;
          axi_write_data <= S_AXI_WDATA;
          write_busy <= 0;
        end
      //----------------------------------------------------------------------
      end else if(S_AXI_ARVALID && !user_done) begin // user_done is ack
        read_busy <= 1;
        arready <= 1;
        user_addr <= S_AXI_ARADDR[USER_ADDR_WIDTH-1:0];
        user_read_enable <= 1;
      //----------------------------------------------------------------------
      end else if(S_AXI_AWVALID && !user_done) begin // user_done is ack
        write_busy <= 1;
        awready <= 1;
        user_addr <= S_AXI_ARADDR[USER_ADDR_WIDTH-1:0];
        user_write_enable <= 1;
      end
      //----------------------------------------------------------------------
      
    end
  end
  
endmodule

//------------------------------------------------------------------------------
module axi_lite_slave_data_fifo #
  (
   parameter integer DATA_WIDTH = 32,
   parameter integer ADDR_WIDTH = 4,
   parameter integer ALMOST_FULL_THRESHOLD = 3,
   parameter integer ALMOST_EMPTY_THRESHOLD = 1
   )
  (
   input                   ACLK,
   input                   ARESETN,
   input [DATA_WIDTH-1:0]  data_in,
   input                   enq,
   output reg              full,
   output reg              almost_full,
   output [DATA_WIDTH-1:0] data_out,
   input                   deq,
   output reg              empty,
   output reg              almost_empty
   );

  // Reset logic
  reg aresetn_r;
  reg aresetn_rr;
  reg aresetn_rrr;

  always @(posedge ACLK) begin
    aresetn_r <= ARESETN;
    aresetn_rr <= aresetn_r;
    aresetn_rrr <= aresetn_rr;
  end
  
  reg [ADDR_WIDTH-1:0] head;
  reg [ADDR_WIDTH-1:0] tail;
  reg [ADDR_WIDTH  :0] count;
  
  always @(posedge ACLK) begin
    if(aresetn_rrr == 0) begin
      head  <= 0;
      tail  <= 0;
      count <= 0;
      full <= 0;
      almost_full <= 0;
      empty <= 1;
      almost_empty <= 1;
    end else begin
      if(enq && deq) begin
        if(count == 2**ADDR_WIDTH) begin
          count <= count - 1;
          tail <= (tail == 2**ADDR_WIDTH-1)? 0 : tail + 1;
          almost_full <= (count >= 2**ADDR_WIDTH - ALMOST_FULL_THRESHOLD + 1);
          full <= 0;
        end else if(count == 0) begin
          count <= count + 1;
          head <= (head == 2**ADDR_WIDTH-1)? 0 : head + 1;
          almost_empty <= (count <= ALMOST_EMPTY_THRESHOLD - 1);
          empty <= 0;
        end else begin
          count <= count;
          head <= (head == 2**ADDR_WIDTH-1)? 0 : head + 1;
          tail <= (tail == 2**ADDR_WIDTH-1)? 0 : tail + 1;        
        end
      end else if(enq) begin
        if(count < 2**ADDR_WIDTH) begin
          count <= count + 1;
          head <= (head == 2**ADDR_WIDTH-1)? 0 : head + 1;
          almost_empty <= (count <= ALMOST_EMPTY_THRESHOLD - 1);
          empty <= 0;
          almost_full <= (count >= 2**ADDR_WIDTH - ALMOST_FULL_THRESHOLD - 1);
          full <= (count >= 2**ADDR_WIDTH -1);
        end
      end else if(deq) begin
        if(count > 0) begin
          count <= count - 1;
          tail <= (tail == 2**ADDR_WIDTH-1)? 0 : tail + 1;
          almost_full <= (count >= 2**ADDR_WIDTH - ALMOST_FULL_THRESHOLD + 1);
          full <= 0;
          almost_empty <= (count <= ALMOST_EMPTY_THRESHOLD + 1);
          empty <= (count <= 1);
        end
      end
    end
  end

  wire [ADDR_WIDTH-1:0] bram_addr0;
  wire                  bram_we0;
  wire [DATA_WIDTH-1:0] bram_data_in0;
  wire [DATA_WIDTH-1:0] bram_data_out0;
  wire [ADDR_WIDTH-1:0] bram_addr1;
  wire [DATA_WIDTH-1:0] bram_data_out1;
  assign bram_addr0 = head;
  assign bram_we0 = enq && !full;
  assign bram_data_in0 = data_in;
  assign bram_addr1 = tail;
  assign data_out = bram_data_out1;
  
  axi_lite_slave_data_fifo_ram
  #(.DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
    )
  inst_ram
  (
   .ACLK(ACLK),
   .addr0(bram_addr0), .data_in0(bram_data_in0), .write_enable0(bram_we0),
   .data_out0(bram_data_out0),
   .addr1(bram_addr1), .data_in1('h0), .write_enable1(1'b0),
   .data_out1(bram_data_out1)
   );
    
endmodule

//------------------------------------------------------------------------------
module axi_lite_slave_data_fifo_ram #
  (
   parameter integer DATA_WIDTH = 32,
   parameter integer ADDR_WIDTH = 4
   )
  (
   input                   ACLK,
   input  [ADDR_WIDTH-1:0] addr0,
   input  [DATA_WIDTH-1:0] data_in0,
   input                   write_enable0,
   output [DATA_WIDTH-1:0] data_out0,
   input  [ADDR_WIDTH-1:0] addr1,
   input  [DATA_WIDTH-1:0] data_in1,
   input                   write_enable1,
   output [DATA_WIDTH-1:0] data_out1
   );
  
  localparam LENGTH = 2 ** ADDR_WIDTH;
  reg [DATA_WIDTH-1:0] mem [0:LENGTH-1];

  always @(posedge ACLK) begin
    if(write_enable0) mem[addr0] <= data_in0;
    if(write_enable1) mem[addr1] <= data_in1;
  end
  assign data_out0 = mem[addr0];
  assign data_out1 = mem[addr1];
endmodule
//------------------------------------------------------------------------------
