
`define AXII_C_LOG_2(n) (\
(n) <= (1<<0) ? 0 : (n) <= (1<<1) ? 1 :\
(n) <= (1<<2) ? 2 : (n) <= (1<<3) ? 3 :\
(n) <= (1<<4) ? 4 : (n) <= (1<<5) ? 5 :\
(n) <= (1<<6) ? 6 : (n) <= (1<<7) ? 7 :\
(n) <= (1<<8) ? 8 : (n) <= (1<<9) ? 9 :\
(n) <= (1<<10) ? 10 : (n) <= (1<<11) ? 11 :\
(n) <= (1<<12) ? 12 : (n) <= (1<<13) ? 13 :\
(n) <= (1<<14) ? 14 : (n) <= (1<<15) ? 15 :\
(n) <= (1<<16) ? 16 : (n) <= (1<<17) ? 17 :\
(n) <= (1<<18) ? 18 : (n) <= (1<<19) ? 19 :\
(n) <= (1<<20) ? 20 : (n) <= (1<<21) ? 21 :\
(n) <= (1<<22) ? 22 : (n) <= (1<<23) ? 23 :\
(n) <= (1<<24) ? 24 : (n) <= (1<<25) ? 25 :\
(n) <= (1<<26) ? 26 : (n) <= (1<<27) ? 27 :\
(n) <= (1<<28) ? 28 : (n) <= (1<<29) ? 29 :\
(n) <= (1<<30) ? 30 : (n) <= (1<<31) ? 31 : 32)

module axi_master_interface #
  (
   //----------------------------------------------------------------------------
   // AXI Parameter
   //----------------------------------------------------------------------------
   parameter integer C_M_AXI_ADDR_WIDTH            = 32,
   parameter integer C_M_AXI_DATA_WIDTH            = 32,
   parameter integer C_M_AXI_THREAD_ID_WIDTH       = 1,
   parameter integer C_M_AXI_AWUSER_WIDTH          = 1,
   parameter integer C_M_AXI_ARUSER_WIDTH          = 1,
   parameter integer C_M_AXI_WUSER_WIDTH           = 1,
   parameter integer C_M_AXI_RUSER_WIDTH           = 1,
   parameter integer C_M_AXI_BUSER_WIDTH           = 1,
   parameter integer C_M_AXI_SUPPORTS_WRITE        = 1,
   parameter integer C_M_AXI_SUPPORTS_READ         = 1,
   parameter C_M_AXI_TARGET = 'h00000000
   )
  (
   //----------------------------------------------------------------------------
   // Common Clock
   //----------------------------------------------------------------------------
   input wire ACLK,
   input wire ARESETN,

   //----------------------------------------------------------------------------
   // User Bus Interface
   //----------------------------------------------------------------------------
   // Write Address
   input wire  [C_M_AXI_ADDR_WIDTH-1:0]   awaddr,
   input wire  [8-1:0]                    awlen,
   input wire                             awvalid,
   output wire                            awready,
  
   // Write Data
   input wire  [C_M_AXI_DATA_WIDTH-1:0]   wdata,
   input wire  [C_M_AXI_DATA_WIDTH/8-1:0] wstrb,
   input wire                             wlast,
   input wire                             wvalid,
   output wire                            wready,
   
   // Read Address
   input wire  [C_M_AXI_ADDR_WIDTH-1:0]   araddr,
   input wire  [8-1:0]                    arlen,
   input wire                             arvalid,
   output wire                            arready,

   // Read Data
   output wire [C_M_AXI_DATA_WIDTH-1:0]   rdata,
   output wire                            rlast,
   output wire                            rvalid,
   input wire                             rready,

   // Error
   output reg                             error,
   
   //----------------------------------------------------------------------------
   // AXI Master Interface
   //----------------------------------------------------------------------------
   // Master Interface Write Address
   output wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_AWID,
   output wire [C_M_AXI_ADDR_WIDTH-1:0]      M_AXI_AWADDR,
   output wire [8-1:0]                       M_AXI_AWLEN,
   output wire [3-1:0]                       M_AXI_AWSIZE,
   output wire [2-1:0]                       M_AXI_AWBURST,
   output wire                               M_AXI_AWLOCK,
   output wire [4-1:0]                       M_AXI_AWCACHE,
   output wire [3-1:0]                       M_AXI_AWPROT,
   output wire [4-1:0]                       M_AXI_AWQOS,
   output wire [C_M_AXI_AWUSER_WIDTH-1:0]    M_AXI_AWUSER,
   output wire                               M_AXI_AWVALID,
   input  wire                               M_AXI_AWREADY,
   
   // Master Interface Write Data
   output wire [C_M_AXI_DATA_WIDTH-1:0]      M_AXI_WDATA,
   output wire [C_M_AXI_DATA_WIDTH/8-1:0]    M_AXI_WSTRB,
   output wire                               M_AXI_WLAST,
   output wire [C_M_AXI_WUSER_WIDTH-1:0]     M_AXI_WUSER,
   output wire                               M_AXI_WVALID,
   input  wire                               M_AXI_WREADY,
   
   // Master Interface Write Response
   input  wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_BID,
   input  wire [2-1:0]                       M_AXI_BRESP,
   input  wire [C_M_AXI_BUSER_WIDTH-1:0]     M_AXI_BUSER,
   input  wire                               M_AXI_BVALID,
   output wire                               M_AXI_BREADY,
   
   // Master Interface Read Address
   output wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_ARID,
   output wire [C_M_AXI_ADDR_WIDTH-1:0]      M_AXI_ARADDR,
   output wire [8-1:0]                       M_AXI_ARLEN,
   output wire [3-1:0]                       M_AXI_ARSIZE,
   output wire [2-1:0]                       M_AXI_ARBURST,
   output wire [2-1:0]                       M_AXI_ARLOCK,
   output wire [4-1:0]                       M_AXI_ARCACHE,
   output wire [3-1:0]                       M_AXI_ARPROT,
   output wire [4-1:0]                       M_AXI_ARQOS,
   output wire [C_M_AXI_ARUSER_WIDTH-1:0]    M_AXI_ARUSER,
   output wire                               M_AXI_ARVALID,
   input  wire                               M_AXI_ARREADY,
   
   // Master Interface Read Data 
   input  wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_RID,
   input  wire [C_M_AXI_DATA_WIDTH-1:0]      M_AXI_RDATA,
   input  wire [2-1:0]                       M_AXI_RRESP,
   input  wire                               M_AXI_RLAST,
   input  wire [C_M_AXI_RUSER_WIDTH-1:0]     M_AXI_RUSER,
   input  wire                               M_AXI_RVALID,
   output wire                               M_AXI_RREADY
   );

  localparam integer C_M_AXI_ADDRMASK_WIDTH = `AXII_C_LOG_2(C_M_AXI_DATA_WIDTH / 8);

  localparam BURST_FIXED = 2'b00;
  localparam BURST_INCR  = 2'b01;
  localparam BURST_WRAP  = 2'b10;

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
  // Write Address (AW)
  //----------------------------------------------------------------------------
  // Single threaded
  assign M_AXI_AWID = 'b0;   
  assign M_AXI_AWADDR = C_M_AXI_TARGET + awaddr;
  assign M_AXI_AWLEN = awlen;
  assign M_AXI_AWSIZE = C_M_AXI_ADDRMASK_WIDTH;
  assign M_AXI_AWBURST = BURST_INCR;
  assign M_AXI_AWLOCK = 1'b0;
  assign M_AXI_AWCACHE = 4'b0011;
  assign M_AXI_AWPROT = 3'h0;
  assign M_AXI_AWQOS = 4'h0;
  assign M_AXI_AWUSER = 'b0;
  assign M_AXI_AWVALID = awvalid;
  assign awready = M_AXI_AWREADY;
  
  //----------------------------------------------------------------------------
  // Write Data(W)
  //----------------------------------------------------------------------------
  assign M_AXI_WDATA = wdata;
  assign M_AXI_WSTRB = wstrb;
  assign M_AXI_WLAST = wlast;
  assign M_AXI_WUSER = 'b0;
  assign M_AXI_WVALID = wvalid;
  assign wready = M_AXI_WREADY;
  
  //----------------------------------------------------------------------------
  // Write Response (B)
  //----------------------------------------------------------------------------
  assign M_AXI_BREADY = C_M_AXI_SUPPORTS_WRITE;

  //----------------------------------------------------------------------------  
  // Read Address (AR)
  //----------------------------------------------------------------------------
  // Single threaded   
  assign M_AXI_ARID = 'b0;   
  assign M_AXI_ARADDR = C_M_AXI_TARGET + araddr;
  assign M_AXI_ARLEN = arlen;
  assign M_AXI_ARSIZE = C_M_AXI_ADDRMASK_WIDTH;
  assign M_AXI_ARBURST = BURST_INCR;
  assign M_AXI_ARLOCK = 1'b0;
  assign M_AXI_ARCACHE = 4'b0011;
  assign M_AXI_ARPROT = 3'h0;
  assign M_AXI_ARQOS = 4'h0;
  assign M_AXI_ARUSER = 'b0;
  assign M_AXI_ARVALID = arvalid;
  assign arready = M_AXI_ARREADY;

  //----------------------------------------------------------------------------    
  // Read and Read Response (R)
  //----------------------------------------------------------------------------    
  assign rdata = M_AXI_RDATA;
  assign rlast = M_AXI_RLAST;
  assign rvalid = M_AXI_RVALID;
  assign M_AXI_RREADY = rready;

  //------------------------------------------------------------------------------
  // Error
  //------------------------------------------------------------------------------
  wire write_resp_error;
  wire read_resp_error; 
  assign write_resp_error = C_M_AXI_SUPPORTS_WRITE & M_AXI_BVALID & M_AXI_BRESP[1];
  assign read_resp_error = C_M_AXI_SUPPORTS_READ & M_AXI_RVALID & M_AXI_RRESP[1];

  always @(posedge ACLK) begin
    if (aresetn_rrr == 0) begin
      error <= 1'b0;
    end else if (write_resp_error || read_resp_error) begin
      error <= 1'b1;
    end else begin
      error <= error;
    end
  end
  
endmodule

