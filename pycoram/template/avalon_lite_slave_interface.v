
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
  reg write_busy;
  
  reg [C_AVS_DATA_WIDTH-1:0] write_data;
  reg [C_AVS_DATA_WIDTH/8-1:0] write_strb;
  reg has_write_data;

  // Write Address
  assign awvalid = avs_write && !write_busy;
  assign awaddr = avs_address;

  // Write Data
  assign wdata = has_write_data? write_data : avs_writedata;
  assign wstrb = has_write_data? write_strb : avs_byteenable;
  assign wvalid = avs_write || has_write_data;

  // Read Address
  assign arvalid = avs_read;
  assign araddr = avs_address;

  // Read Data
  assign rready = 1'b1;
  
  //------------------------------------------------------------------------------
  // Avalon Interface
  //------------------------------------------------------------------------------
  // Common
  assign avs_waitrequest = (!write_busy && !awready) ||
                           (write_busy && has_write_data) ||
                           (write_busy && !wready) ||
                           (arvalid && !arready);
    
  // Read
  assign avs_readdata = rdata;
  assign avs_readdatavalid = rvalid;
  
  //------------------------------------------------------------------------------
  always @(posedge ACLK) begin
    if (aresetn_rrr == 0) begin
      write_busy <= 0;
      write_data <= 0;
      write_strb <= 0;
      has_write_data <= 0;
    end else if(write_busy) begin
      if(has_write_data && wready) begin
        has_write_data <= 0;
        write_busy <= 0;
      end
    end else begin
      if(avs_write && awready) begin
        if(!wready) begin
          write_data <= avs_writedata;
          write_strb <= avs_byteenable;
          has_write_data <= 1;
          write_busy <= 1;
        end else begin
          has_write_data <= 0;
          write_busy <= 0;
        end
      end
    end
  end
  
endmodule

