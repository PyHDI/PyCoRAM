
module avalon_master_interface #
  (
   //------------------------------------------------------------------------------
   // Avalon Parameter
   //------------------------------------------------------------------------------
   parameter integer C_AVM_ADDR_WIDTH = 32,
   parameter integer C_AVM_DATA_WIDTH = 32,
   parameter C_AVM_TARGET = 'h00000000
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
   input wire                         awvalid,
   input wire  [C_AVM_ADDR_WIDTH-1:0] awaddr,
   input wire  [8-1:0]                awlen,
   output wire                        awready,
  
   // Write Data
   input wire  [C_AVM_DATA_WIDTH-1:0] wdata,
   input wire                         wlast,
   input wire                         wvalid,
   output wire                        wready,

   // Write Response
   output wire                        bvalid,
   input wire                         bready,
   
   // Read Address
   input wire                         arvalid,
   input wire  [C_AVM_ADDR_WIDTH-1:0] araddr,
   input wire  [8-1:0]                arlen,
   output wire                        arready,

   // Read Data
   output wire [C_AVM_DATA_WIDTH-1:0] rdata,
   output wire                        rlast,
   output wire                        rvalid,
   input wire                         rready,

   // Error
   output wire                        error,
   
   //----------------------------------------------------------------------------
   // Avalon Master Interface
   //----------------------------------------------------------------------------
   // Common
   output wire [C_AVM_ADDR_WIDTH-1:0]   avm_address,
   input  wire                          avm_waitrequest,
   output wire [C_AVM_DATA_WIDTH/8-1:0] avm_byteenable,
   output wire [8-1:0]                  avm_burstcount,
   
   // Read
   output wire                          avm_read,
   input  wire [C_AVM_DATA_WIDTH-1:0]   avm_readdata,
   input  wire                          avm_readdatavalid,

   // Write
   output wire                          avm_write,
   output wire [C_AVM_DATA_WIDTH-1:0]   avm_writedata
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
  reg [8:0] write_count;

  // Write Address
  assign awready = !avm_waitrequest && wvalid && awvalid && !write_busy;
  
  // Write Data
  assign wready = !avm_waitrequest && wvalid && (awvalid || write_busy);
  
  // Write Response
  assign bvalid = !avm_waitrequest && avm_write && write_busy && (write_count == 1);
  
  // Read Address
  assign arready = !avm_waitrequest && arvalid && !write_busy;
  
  // Read Data
  assign rdata = avm_readdata;
  assign rlast = 1'b0; // Unused in DMAC_MEMORY
  assign rvalid = avm_readdatavalid;

  //------------------------------------------------------------------------------
  // Avalon Interface
  //------------------------------------------------------------------------------
  // Common
  assign avm_address = awvalid? awaddr + C_AVM_TARGET : araddr + C_AVM_TARGET;
  assign avm_byteenable = {(C_AVM_ADDR_WIDTH/8){1'b1}};
  assign avm_burstcount = awvalid? awlen + 1 : arlen + 1;
  
  // Read
  assign avm_read = arvalid;
  
  // Write
  assign avm_write = (awvalid || write_busy) && wvalid;
  assign avm_writedata = wdata;

  //------------------------------------------------------------------------------  
  always @(posedge ACLK) begin
    if (aresetn_rrr == 0) begin
      write_busy <= 0;
      write_count <= 0;
    end else if(write_busy) begin
      if(!avm_waitrequest && avm_write) begin
        write_count <= write_count - 1;
        if(write_count == 1) begin
          write_busy <= 0;
        end
      end
    end else begin
      if(!avm_waitrequest && awvalid && wvalid) begin
        write_count <= awlen;
        if(awlen == 0) write_busy <= 0;
        else write_busy <= 1;
      end
    end
  end

  //------------------------------------------------------------------------------  
  // Error
  //------------------------------------------------------------------------------  
  assign error = 1'b0;
  
endmodule

