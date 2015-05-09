
module avalon_lite_slave_interface #
  (
   //------------------------------------------------------------------------------
   // Avalon Parameter
   //------------------------------------------------------------------------------
   parameter integer C_AVS_ADDR_WIDTH = 32,
   parameter integer C_AVS_DATA_WIDTH = 32
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
   output wire [C_AVS_ADDR_WIDTH-1:0]   awaddr,
   output wire                          awvalid,
   input wire                           awready,
  
   // Write Data
   output wire [C_AVS_DATA_WIDTH-1:0]   wdata,
   output wire [C_AVS_DATA_WIDTH/8-1:0] wstrb,
   output wire                          wvalid,
   input wire                           wready,

   // Read Address
   output wire [C_AVS_ADDR_WIDTH-1:0]   araddr,
   output wire                          arvalid,
   input wire                           arready,

   // Read Data
   input wire  [C_AVS_DATA_WIDTH-1:0]   rdata,
   input wire                           rvalid,
   output wire                          rready,

   //----------------------------------------------------------------------------
   // Avalon Slave Interface
   //----------------------------------------------------------------------------
   // Common
   input  wire [C_AVS_ADDR_WIDTH-1:0]   avs_address,
   output wire                          avs_waitrequest,
   input  wire [C_AVS_DATA_WIDTH/8-1:0] avs_byteenable,
   
   // Read
   input  wire                          avs_read,
   output wire [C_AVS_DATA_WIDTH-1:0]   avs_readdata,
   output wire                          avs_readdatavalid,

   // Write
   input  wire                          avs_write,
   input  wire [C_AVS_DATA_WIDTH-1:0]   avs_writedata
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

  //------------------------------------------------------------------------------
  // User-logic Interface
  //------------------------------------------------------------------------------
  // Write Address
  assign awvalid = avs_write;
  assign awaddr = avs_address;

  // Write Data
  assign wdata = avs_writedata;
  assign wstrb = avs_byteenable;
  assign wlast = 1'b0;
  assign wvalid = avs_write;

  // Read Address
  assign arvalid = avs_read;
  assign araddr = avs_address;

  // Read Data
  assign rready = 1'b1;
  
  //------------------------------------------------------------------------------
  // Avalon Interface
  //------------------------------------------------------------------------------
  // Common
  assign avs_waitrequest = ((awvalid || wvalid) && !(awready && wready)) ||
                           (arvalid && !arready);
    
  // Read
  assign avs_readdata = rdata;
  assign avs_readdatavalid = rvalid;
  
endmodule

