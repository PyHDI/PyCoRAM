
module axi_lite_master_interface #
  (
   //----------------------------------------------------------------------------
   // AXI Parameter
   //----------------------------------------------------------------------------
   parameter integer C_M_AXI_ADDR_WIDTH            = 32,
   parameter integer C_M_AXI_DATA_WIDTH            = 32,
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
   input wire                             awvalid,
   output wire                            awready,
  
   // Write Data
   input wire  [C_M_AXI_DATA_WIDTH-1:0]   wdata,
   input wire  [C_M_AXI_DATA_WIDTH/8-1:0] wstrb,
   input wire                             wvalid,
   output wire                            wready,

   // Read Address
   input wire  [C_M_AXI_ADDR_WIDTH-1:0]   araddr,
   input wire                             arvalid,
   output wire                            arready,

   // Read Data
   output wire [C_M_AXI_DATA_WIDTH-1:0]   rdata,
   output wire                            rvalid,
   input wire                             rready,

   // Error
   output reg                             error,
   
   //----------------------------------------------------------------------------
   // AXI Master Interface
   //----------------------------------------------------------------------------
   // Master Interface Write Address
   output wire [C_M_AXI_ADDR_WIDTH-1:0]      M_AXI_AWADDR,
   output wire [3-1:0]                       M_AXI_AWPROT,
   output wire                               M_AXI_AWVALID,
   input  wire                               M_AXI_AWREADY,
   
   // Master Interface Write Data
   output wire [C_M_AXI_DATA_WIDTH-1:0]      M_AXI_WDATA,
   output wire [C_M_AXI_DATA_WIDTH/8-1:0]    M_AXI_WSTRB,
   output wire                               M_AXI_WVALID,
   input  wire                               M_AXI_WREADY,
   
   // Master Interface Write Response
   input  wire [2-1:0]                       M_AXI_BRESP,
   input  wire                               M_AXI_BVALID,
   output wire                               M_AXI_BREADY,
   
   // Master Interface Read Address
   output wire [C_M_AXI_ADDR_WIDTH-1:0]      M_AXI_ARADDR,
   output wire [3-1:0]                       M_AXI_ARPROT,
   output wire                               M_AXI_ARVALID,
   input  wire                               M_AXI_ARREADY,
   
   // Master Interface Read Data 
   input  wire [C_M_AXI_DATA_WIDTH-1:0]      M_AXI_RDATA,
   input  wire [2-1:0]                       M_AXI_RRESP,
   input  wire                               M_AXI_RVALID,
   output wire                               M_AXI_RREADY
   );

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
  assign M_AXI_AWADDR = C_M_AXI_TARGET + awaddr;
  assign M_AXI_AWPROT = 3'h0;
  assign M_AXI_AWVALID = awvalid;
  assign awready = M_AXI_AWREADY;
  
  //----------------------------------------------------------------------------
  // Write Data(W)
  //----------------------------------------------------------------------------
  assign M_AXI_WDATA = wdata;
  assign M_AXI_WSTRB = wstrb;
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
  assign M_AXI_ARADDR = C_M_AXI_TARGET + araddr;
  assign M_AXI_ARPROT = 3'h0;
  assign M_AXI_ARVALID = arvalid;
  assign arready = M_AXI_ARREADY;

  //----------------------------------------------------------------------------    
  // Read and Read Response (R)
  //----------------------------------------------------------------------------    
  assign rdata = M_AXI_RDATA;
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

