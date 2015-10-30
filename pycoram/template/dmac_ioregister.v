module DMAC_IOREGISTER #
  (
   //----------------------------------------------------------------------------
   // User Parameter
   //----------------------------------------------------------------------------
   parameter W_D = 32, // power of 2
   parameter W_A = 5, // # entries = 2 ^ W_A
   parameter W_EXT_A = 32, // byte addressing
   parameter ADDRMASK_WIDTH = 2, // log2(W_D/8)
   
   parameter W_BOUNDARY_A = 12, // for 4KB boundary limitation of AXI
   parameter W_BLEN = 8, //log(MAX_BURST_LEN)
   parameter MAX_BURST_LEN = 256, // burst length

   parameter FIFO_ADDR_WIDTH = 4,
   parameter ASYNC = 1
   )
  (
   //---------------------------------------------------------------------------
   // Bus Clock
   //---------------------------------------------------------------------------
   input wire ACLK,
   input wire ARESETN,

   //---------------------------------------------------------------------------
   // Control Thread
   //---------------------------------------------------------------------------
   input                    coram_clk,
   input                    coram_rst,

   input      [W_A-1:0]     coram_addr,
   input      [W_D-1:0]     coram_d,
   input                    coram_we,
   output     [W_D-1:0]     coram_q,

   //----------------------------------------------------------------------------
   // Bus Interface
   //----------------------------------------------------------------------------
   // Write Address
   input wire               awvalid,
   input wire [W_EXT_A-1:0] awaddr,
   input wire [W_BLEN-1:0]  awlen,
   output reg               awready,
  
   // Write Data
   input wire               wvalid,
   input wire [W_D-1:0]     wdata,
   input wire [(W_D/8)-1:0] wstrb,
   input wire               wlast,
   output wire              wready,

   // Read Address
   input wire               arvalid,
   input wire [W_EXT_A-1:0] araddr,
   input wire [W_BLEN-1:0]  arlen,
   output reg               arready,

   // Read Data
   output reg               rvalid,
   output     [W_D-1:0]     rdata,
   output wire              rlast,
   input wire               rready
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
  // Data
  //----------------------------------------------------------------------------
  reg [W_A-1:0] addr_buf;
  
  reg [W_A-1:0] waddr_cdc_from;
  reg [W_D-1:0] wdata_cdc_from;
  reg wvalid_cdc_from;
  
  reg [W_A-1:0] waddr_cdc_to;
  reg [W_D-1:0] wdata_cdc_to;
  reg wvalid_cdc_to;
  
  reg [W_A-1:0] coram_addr_cdc_from;
  reg [W_D-1:0] coram_d_cdc_from;
  reg coram_we_cdc_from;
  
  reg [W_A-1:0] coram_addr_cdc_to;
  reg [W_D-1:0] coram_d_cdc_to;
  reg coram_we_cdc_to;

  generate if(ASYNC) begin : async
    dmac_ioregister_ram # (.W_A(W_A), .W_D(W_D))
    inst_ram_coram (.CLK(coram_clk), 
                    .ADDR0(coram_addr), .D0(coram_d), .WE0(coram_we), .Q0(coram_q),
                    .ADDR1(waddr_cdc_to), .D1(wdata_cdc_to), .WE1(wvalid_cdc_to), .Q1());
  
    dmac_ioregister_ram # (.W_A(W_A), .W_D(W_D))
    inst_ram_bus (.CLK(ACLK), 
                  .ADDR0(coram_addr_cdc_to), .D0(coram_d_cdc_to), .WE0(coram_we_cdc_to), .Q0(),
                  .ADDR1(addr_buf), .D1(wdata), .WE1(wvalid), .Q1(rdata));
  
    always @(posedge ACLK) begin
      //if(wvalid) rdata <= wdata;
      //if(coram_we_cdc_to) rdata <= coram_d_cdc_to;
    end

    always @(posedge coram_clk) begin
      //if(wvalid_cdc_to) coram_q <= wdata_cdc_to;
      //if(coram_we) coram_q <= coram_d;
    end
    
    always @(posedge ACLK) begin
      wvalid_cdc_from <= wvalid;
      wdata_cdc_from <= wdata;
      waddr_cdc_from <= addr_buf;
    end
    always @(posedge coram_clk) begin
      wvalid_cdc_to <= wvalid_cdc_from;
      wdata_cdc_to <= wdata_cdc_from;
      waddr_cdc_to <= waddr_cdc_from;
    end

    always @(posedge coram_clk) begin
      coram_we_cdc_from <= coram_we;
      coram_d_cdc_from <= coram_d;
      coram_addr_cdc_from <= coram_addr;
    end
    always @(posedge ACLK) begin
      coram_we_cdc_to <= coram_we_cdc_from;
      coram_d_cdc_to <= coram_d_cdc_from;
      coram_addr_cdc_to <= coram_addr_cdc_from;
    end
  end else begin : sync
    dmac_ioregister_ram # (.W_A(W_A), .W_D(W_D))
    inst_ram (.CLK(ACLK), 
              .ADDR0(coram_addr), .D0(coram_d), .WE0(coram_we), .Q0(coram_q),
              .ADDR1(addr_buf), .D1(wdata), .WE1(wvalid), .Q1(rdata));
  
    always @(posedge ACLK) begin
      if(coram_we) begin
        //rdata <= coram_d;
        //coram_q <= coram_d;
      end
      if(wvalid) begin
        //rdata <= wdata;
        //coram_q <= wdata;
      end
    end
  end endgenerate

  //----------------------------------------------------------------------------
  // Command
  //----------------------------------------------------------------------------
  reg read_busy;
  reg write_busy;
  
  reg [W_EXT_A:0] read_count;
  reg [W_EXT_A:0] write_count;

  always @(posedge ACLK) begin
    if(aresetn_rrr == 0) begin
      awready <= 0;
      arready <= 0;
      rvalid <= 0;
      addr_buf <= 0;
      read_busy <= 0;
      write_busy <= 0;
      read_count <= 0;
      write_count <= 0;

    //------------------------------------------------------------------------------
    // Read Mode (BRAM -> Off-chip)
    //------------------------------------------------------------------------------
    end else if(read_busy) begin
      awready <= 0;
      arready <= 0;
      rvalid <= 1;
      if(rready) begin
        read_count <= read_count - 1;
        addr_buf <= addr_buf + 1;
        if(read_count == 1) begin
          rvalid <= 0;
          read_busy <= 0;
        end
      end
      
    //------------------------------------------------------------------------------
    // Write Mode (Off-chip -> BRAM)
    //------------------------------------------------------------------------------
    end else if(write_busy) begin
      awready <= 0;
      arready <= 0;
      rvalid <= 0;
      if(wvalid) begin
        write_count <= write_count - 1;
        addr_buf <= addr_buf + 1;
        if(write_count == 1) begin
          write_busy <= 0;
        end
      end
      
    //------------------------------------------------------------------------------
    // New Command
    //------------------------------------------------------------------------------
    end else begin
      awready <= 0;
      arready <= 0;
      rvalid <= 0;
      read_count <= 0;
      write_count <= 0;
      if(awvalid) begin
        write_busy <= 1;
        awready <= 1;
        addr_buf <= awaddr >> ADDRMASK_WIDTH;
        write_count <= awlen + 1;
      end else if(arvalid) begin
        read_busy <= 1;
        arready <= 1;
        rvalid <= 1;
        addr_buf <= araddr >> ADDRMASK_WIDTH;
        read_count <= arlen + 1;
      end
    end
  end

  //----------------------------------------------------------------------------
  // Data
  //----------------------------------------------------------------------------
  assign wready = write_busy;
  assign rlast = (read_count == 0);
  
endmodule

module dmac_ioregister_ram(CLK, 
                           ADDR0, D0, WE0, Q0,
                           ADDR1, D1, WE1, Q1);
  parameter W_A = 10;
  parameter W_D = 32;
  localparam LEN = 2 ** W_A;
  input            CLK;
  input  [W_A-1:0] ADDR0;
  input  [W_D-1:0] D0;
  input            WE0;
  output [W_D-1:0] Q0;
  input  [W_A-1:0] ADDR1;
  input  [W_D-1:0] D1;
  input            WE1;
  output [W_D-1:0] Q1;
  
  reg [W_D-1:0] mem [0:LEN-1];
  
  always @(posedge CLK) begin
    if(WE0) mem[ADDR0] <= D0;
    if(WE1) mem[ADDR1] <= D1;
  end
  assign Q0 = mem[ADDR0];
  assign Q1 = mem[ADDR1];
endmodule

