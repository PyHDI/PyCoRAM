
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
   output wire                        awvalid,
   output wire [C_AVS_ADDR_WIDTH-1:0] awaddr,
   output wire [8-1:0]                awlen,
   input wire                         awready,
  
   // Write Data
   output wire [C_AVS_DATA_WIDTH-1:0] wdata,
   output wire                        wlast,
   output wire                        wvalid,
   input wire                         wready,

   // Write Response
   input wire                         bvalid,
   output wire                        bready,
   
   // Read Address
   output wire                        arvalid,
   output wire [C_AVS_ADDR_WIDTH-1:0] araddr,
   output wire [8-1:0]                arlen,
   input wire                         arready,

   // Read Data
   input wire  [C_AVS_DATA_WIDTH-1:0] rdata,
   input wire                         rlast,
   input wire                         rvalid,
   output wire                        rready,

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
  // Avalon Interface
  //------------------------------------------------------------------------------
  // Common
  assign avs_waitrequest = ((awvalid || wvalid) && !(awready && wready)) ||
                           (arvalid && !arready);
    
  // Read
  assign avs_readdata = rdata;
  assign avs_readdatavalid = rvalid;
  
  //------------------------------------------------------------------------------
  // User-logic Interface
  //------------------------------------------------------------------------------
  // Write Address
  assign awvalid = avs_write;
  assign awaddr = avs_address;
  assign awlen = 0;

  // Write Data
  assign wdata = avs_writedata;
  assign wlast = 1'b0; // Unused in DMAC_IOCHANNEL
  assign wvalid = avs_write;

  // Write Response
  assign bready = 1'b1;

  // Read Address
  assign arvalid = avs_read;
  assign araddr = avs_address;
  assign arlen = 0;

  // Read Data
  assign rready = 1'b1;
  
endmodule

