
module axi_lite_slave_interface #
  (
   //----------------------------------------------------------------------------
   // AXI Parameter
   //----------------------------------------------------------------------------
   parameter integer C_S_AXI_ADDR_WIDTH            = 32,
   parameter integer C_S_AXI_DATA_WIDTH            = 32
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
   output wire                          awvalid,
   output wire [C_S_AXI_ADDR_WIDTH-1:0] awaddr,
   output wire [8-1:0]                  awlen,
   input wire                           awready,
  
   // Write Data
   output wire [C_S_AXI_DATA_WIDTH-1:0] wdata,
   output wire                          wlast,
   output wire                          wvalid,
   input wire                           wready,

   // Write Response
   input wire                           bvalid,
   output wire                          bready,
   
   // Read Address
   output wire                          arvalid,
   output wire [C_S_AXI_ADDR_WIDTH-1:0] araddr,
   output wire [8-1:0]                  arlen,
   input wire                           arready,

   // Read Data
   input wire  [C_S_AXI_DATA_WIDTH-1:0] rdata,
   input wire                           rlast,
   input wire                           rvalid,
   output wire                          rready,

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

  localparam RESP_OKAY   = 2'b00;
  localparam RESP_EXOKAY = 2'b01;
  localparam RESP_SLVERR = 2'b10;
  localparam RESP_DECERR = 2'b11;
  
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
  // bresp, rresp
  //----------------------------------------------------------------------------
  wire [2-1:0]               bresp;
  wire [2-1:0]               rresp;
  
  //----------------------------------------------------------------------------
  // Write Address (AW)
  //----------------------------------------------------------------------------
  // Single threaded
  assign awvalid = S_AXI_AWVALID;
  assign awaddr = S_AXI_AWADDR;
  assign awlen = 0; // single data
  assign S_AXI_AWREADY = awready;

  //----------------------------------------------------------------------------
  // Write Data(W)
  //----------------------------------------------------------------------------
  assign wdata = S_AXI_WDATA;
  assign wlast = 1'b1; // single data
  assign wvalid = S_AXI_WVALID;
  assign S_AXI_WREADY = wready;
  
  //----------------------------------------------------------------------------
  // Write Response (B)
  //----------------------------------------------------------------------------
  assign S_AXI_BRESP = bresp;
  assign S_AXI_BVALID = bvalid;
  assign bready = S_AXI_BREADY;

  //----------------------------------------------------------------------------  
  // Read Address (AR)
  //----------------------------------------------------------------------------
  assign arvalid = S_AXI_ARVALID;
  assign araddr = S_AXI_ARADDR;
  assign arlen = 0; // single data
  assign S_AXI_ARREADY = arready;

  //----------------------------------------------------------------------------    
  // Read and Read Response (R)
  //----------------------------------------------------------------------------    
  assign S_AXI_RDATA = rdata;
  assign S_AXI_RRESP = rresp;
  assign S_AXI_RVALID = rvalid;
  assign rready = S_AXI_RREADY;
  
  assign bresp = RESP_OKAY; // always OK
  assign rresp = RESP_OKAY; // always OK
  
endmodule

