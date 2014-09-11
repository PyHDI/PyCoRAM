
`define AXIF_C_LOG_2(n) (\
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

module axi_master_fifo #
  (
   //----------------------------------------------------------------------------
   // User Parameter
   //----------------------------------------------------------------------------
   parameter integer FIFO_ADDR_WIDTH = 4,

   //----------------------------------------------------------------------------
   // AXI Parameter
   //----------------------------------------------------------------------------
   parameter integer C_M_AXI_THREAD_ID_WIDTH       = 1,
   parameter integer C_M_AXI_ADDR_WIDTH            = 32,
   parameter integer C_M_AXI_DATA_WIDTH            = 32,
   parameter integer C_M_AXI_AWUSER_WIDTH          = 1,
   parameter integer C_M_AXI_ARUSER_WIDTH          = 1,
   parameter integer C_M_AXI_WUSER_WIDTH           = 1,
   parameter integer C_M_AXI_RUSER_WIDTH           = 1,
   parameter integer C_M_AXI_BUSER_WIDTH           = 1,
   
   /* Disabling these parameters will remove any throttling.
    The resulting ERROR flag will not be useful */ 
   parameter integer C_M_AXI_SUPPORTS_WRITE        = 1,
   parameter integer C_M_AXI_SUPPORTS_READ         = 1,
   
   // Example design parameters
   // Base address of targeted slave
   parameter C_M_AXI_TARGET = 'h00000000
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
   input                            user_write_enq,
   input [C_M_AXI_DATA_WIDTH-1:0]   user_write_data,
   output                           user_write_almost_full,
   input                            user_read_deq,
   output [C_M_AXI_DATA_WIDTH-1:0]  user_read_data,
   output                           user_read_empty,

   // Command Channel
   input [C_M_AXI_ADDR_WIDTH-1:0]   user_addr,
   input                            user_read_enable,
   input                            user_write_enable,
   input [8:0]                      user_word_size,
   output reg                       user_done,
   
   output wire                      ERROR,
   
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

  //------------------------------------------------------------------------------
  // Internal Constant
  //------------------------------------------------------------------------------
  localparam integer C_M_AXI_BURST_COUNT_WIDTH = C_M_AXI_ADDR_WIDTH + 1;
  localparam integer ADDRMASK_WIDTH = `AXIF_C_LOG_2(C_M_AXI_DATA_WIDTH / 8);

  //------------------------------------------------------------------------------
  // Data Channel (Read FIFO / Write FIFO)
  //------------------------------------------------------------------------------
  wire                          axi_write_deq;
  wire [C_M_AXI_DATA_WIDTH-1:0] axi_write_data;
  wire                          axi_write_empty;

  reg                           axi_read_enq;
  reg  [C_M_AXI_DATA_WIDTH-1:0] axi_read_data;
  wire                          axi_read_almost_full;

  // Write
  axi_data_fifo 
  #(
    .DATA_WIDTH(C_M_AXI_DATA_WIDTH),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    )
  inst_write_fifo
  (
   .ACLK(ACLK), .ARESETN(ARESETN),
   .enq(user_write_enq), .data_in(user_write_data), .almost_full(user_write_almost_full),
   .deq(axi_write_deq), .data_out(axi_write_data), .empty(axi_write_empty)
   );

  // Read
  axi_data_fifo 
  #(
    .DATA_WIDTH(C_M_AXI_DATA_WIDTH),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    )
  inst_read_fifo
  (
   .ACLK(ACLK), .ARESETN(ARESETN),
   .enq(axi_read_enq), .data_in(axi_read_data), .almost_full(axi_read_almost_full), 
   .deq(user_read_deq), .data_out(user_read_data), .empty(user_read_empty)
   );
  
  //------------------------------------------------------------------------------
  // Internal Signal
  //------------------------------------------------------------------------------
  // Write Address
  reg [C_M_AXI_ADDR_WIDTH-1:0] awaddr_offset;
  reg                          awvalid;
  // Write Data
  reg [C_M_AXI_DATA_WIDTH-1:0] wdata;
  reg                          wlast;
  reg                          wvalid;
  // Read Address
  reg [C_M_AXI_ADDR_WIDTH-1:0] araddr_offset;
  reg                          arvalid;

  reg error_reg;
  wire write_resp_error;
  wire read_resp_error; 

  reg [C_M_AXI_ADDR_WIDTH-1:0] user_addr_buf;
  reg [C_M_AXI_ADDR_WIDTH-1:0] user_word_size_buf;
  reg [C_M_AXI_ADDR_WIDTH-1:0] user_word_size_buf_m1;

  reg read_busy;
  reg read_addr_done;
  reg [C_M_AXI_BURST_COUNT_WIDTH-1:0] read_cnt;

  reg write_busy;
  reg write_addr_done;
  reg [C_M_AXI_BURST_COUNT_WIDTH-1:0] write_cnt;
  
  //----------------------------------------------------------------------------
  // Write Address (AW)
  //----------------------------------------------------------------------------
  // Single threaded   
  assign M_AXI_AWID = 'b0;   
  
  // The AXI address is a concatenation of the target base address + active offset range
  assign M_AXI_AWADDR = C_M_AXI_TARGET + awaddr_offset;
  
  // Burst LENgth is number of transaction beats, minus 1
  assign M_AXI_AWLEN = user_word_size_buf_m1;
  
  // Size should be C_M_AXI_DATA_WIDTH, in 2^SIZE bytes, otherwise narrow bursts are used
  assign M_AXI_AWSIZE = `AXIF_C_LOG_2(C_M_AXI_DATA_WIDTH/8);
  
  // INCR burst type is usually used, except for keyhole bursts
  assign M_AXI_AWBURST = 2'b01;
  assign M_AXI_AWLOCK = 1'b0;
  assign M_AXI_AWCACHE = 4'b0011;
  assign M_AXI_AWPROT = 3'h0;
  assign M_AXI_AWQOS = 4'h0;
  assign M_AXI_AWUSER = 'b0;
  assign M_AXI_AWVALID = awvalid;
  
  //----------------------------------------------------------------------------
  // Write Data(W)
  //----------------------------------------------------------------------------
  assign M_AXI_WDATA = wdata;

  // Mask Signal
  //All bursts are complete and aligned in this example
  assign M_AXI_WSTRB = {(C_M_AXI_DATA_WIDTH/8){1'b1}}; 
  assign M_AXI_WLAST = wlast;
  assign M_AXI_WUSER = 'b0;
  assign M_AXI_WVALID = wvalid;
  
  //----------------------------------------------------------------------------
  // Write Response (B)
  //----------------------------------------------------------------------------
  assign M_AXI_BREADY = C_M_AXI_SUPPORTS_WRITE;

  //----------------------------------------------------------------------------  
  // Read Address (AR)
  //----------------------------------------------------------------------------
  assign M_AXI_ARID = 'b0;   
  assign M_AXI_ARADDR = C_M_AXI_TARGET + araddr_offset;
  
  //Burst LENgth is number of transaction beats, minus 1
  assign M_AXI_ARLEN = user_word_size_buf_m1;

  // Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
  assign M_AXI_ARSIZE = `AXIF_C_LOG_2(C_M_AXI_DATA_WIDTH/8);
  
  // INCR burst type is usually used, except for keyhole bursts
  assign M_AXI_ARBURST = 2'b01;
  assign M_AXI_ARLOCK = 1'b0;
  assign M_AXI_ARCACHE = 4'b0011;
  assign M_AXI_ARPROT = 3'h0;
  assign M_AXI_ARQOS = 4'h0;
  assign M_AXI_ARUSER = 'b0;
  assign M_AXI_ARVALID = arvalid;

  //----------------------------------------------------------------------------    
  // Read and Read Response (R)
  //----------------------------------------------------------------------------    
  assign M_AXI_RREADY = !axi_read_almost_full;

  //----------------------------------------------------------------------------
  // Error state
  //----------------------------------------------------------------------------
  assign ERROR = error_reg;
  
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
  // User State Machine
  //----------------------------------------------------------------------------
  function [C_M_AXI_ADDR_WIDTH-1:0] addrmask;
    input [C_M_AXI_ADDR_WIDTH-1:0] in;
    addrmask = { in[C_M_AXI_ADDR_WIDTH-1:ADDRMASK_WIDTH], {ADDRMASK_WIDTH{1'b0}} };
  endfunction

  assign axi_write_deq = write_busy && 
                         (write_addr_done || (awvalid && M_AXI_AWREADY)) &&
                         write_cnt < user_word_size_buf &&
                         (!wvalid || (wvalid && M_AXI_WREADY)) &&
                         !axi_write_empty;
  
  always @(posedge ACLK) begin
    if(aresetn_rrr == 0) begin
      arvalid <= 0;
      awvalid <= 0;
      wlast <= 0;
      wvalid <= 0;
      wdata <= 0;
      araddr_offset <= 0;
      awaddr_offset <= 0;
      axi_read_enq <= 0;
      axi_read_data <= 0;
      read_busy <= 0;
      write_busy <= 0;
      read_addr_done <= 0;
      write_addr_done <= 0;
      read_cnt <= 0;
      write_cnt <= 0;
      user_done <= 0;
      user_addr_buf <= 0;
      user_word_size_buf <= 0;
      user_word_size_buf_m1 <= 0;
    end else begin
      //default
      arvalid <= 0;
      awvalid <= 0;
      wlast <= 0;
      wvalid <= 0;
      axi_read_enq <= 0;
      user_done <= 0;

      //----------------------------------------------------------------------
      if(read_busy) begin
        
        if(!read_addr_done) begin
          araddr_offset <= user_addr_buf;
          arvalid <= 1;
          if(arvalid && M_AXI_ARREADY) begin
            read_addr_done <= 1;
            arvalid <= 0;
          end
        end
        
        if(M_AXI_RVALID) begin
          axi_read_data <= M_AXI_RDATA;
          axi_read_enq <= 1;
          read_cnt <= read_cnt + 1;
          if(read_cnt == user_word_size_buf_m1) begin
            read_busy <= 0;
            user_done <= 1;
          end
        end

      end
      //----------------------------------------------------------------------
      else if(write_busy) begin
        
        if(!write_addr_done) begin
          awaddr_offset <= user_addr_buf;
          awvalid <= 1;
          if(awvalid && M_AXI_AWREADY) begin
            write_addr_done <= 1;
            awvalid <= 0;
          end
        end

        if((write_addr_done || (awvalid && M_AXI_AWREADY)) &&
           write_cnt < user_word_size_buf) begin

          if(wvalid && !M_AXI_WREADY) begin
            wvalid <= 1;
          end else if((!wvalid || (wvalid && M_AXI_WREADY)) &&
                      !axi_write_empty) begin
            wvalid <= 1;
            wdata <= axi_write_data;
            write_cnt <= write_cnt + 1;
          end
          
          if(write_cnt == user_word_size_buf_m1) begin
            wlast <= 1;
          end
        end
        
        if(write_cnt == user_word_size_buf && wvalid && !M_AXI_WREADY) begin
          wvalid <= 1;
          wlast <= 1;
        end
        
        if(M_AXI_BVALID) begin
          write_busy <= 0;
          user_done <= 1;
        end

      end
      //----------------------------------------------------------------------
      else if(!user_done && user_read_enable) begin // user_done is ack
        user_addr_buf <= addrmask(user_addr);
        user_word_size_buf <= user_word_size;
        user_word_size_buf_m1 <= user_word_size - 1;
        read_busy <= 1;
        read_addr_done <= 0;
        read_cnt <= 0;
      end
      //----------------------------------------------------------------------
      else if(!user_done && user_write_enable) begin // user_done is ack
        user_addr_buf <= addrmask(user_addr);
        user_word_size_buf <= user_word_size;
        user_word_size_buf_m1 <= user_word_size - 1;
        write_busy <= 1;
        write_addr_done <= 0;
        write_cnt <= 0;
      end 
      //----------------------------------------------------------------------

    end
  end
  
  //----------------------------------------------------------------------------
  // Error register
  //----------------------------------------------------------------------------
  assign write_resp_error = C_M_AXI_SUPPORTS_WRITE & M_AXI_BVALID & M_AXI_BRESP[1];
  assign read_resp_error = C_M_AXI_SUPPORTS_READ & M_AXI_RVALID & M_AXI_RRESP[1];

  always @(posedge ACLK) begin
     if (ARESETN == 0)
       error_reg <= 1'b0;
     else if (write_resp_error || read_resp_error)
       error_reg <= 1'b1;
     else
       error_reg <= error_reg;
  end

endmodule

//------------------------------------------------------------------------------
module axi_data_fifo #
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

  wire [ADDR_WIDTH-1:0] ram_addr0;
  wire                  ram_we0;
  wire [DATA_WIDTH-1:0] ram_data_in0;
  wire [DATA_WIDTH-1:0] ram_data_out0;
  wire [ADDR_WIDTH-1:0] ram_addr1;
  wire [DATA_WIDTH-1:0] ram_data_out1;
  assign ram_addr0 = head;
  assign ram_we0 = enq && !full;
  assign ram_data_in0 = data_in;
  assign ram_addr1 = tail;
  assign data_out = ram_data_out1;
  
  axi_data_fifo_ram
  #(.DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
    )
  inst_ram
  (
   .ACLK(ACLK),
   .addr0(ram_addr0), .data_in0(ram_data_in0), .write_enable0(ram_we0),
   .data_out0(ram_data_out0),
   .addr1(ram_addr1), .data_in1('h0), .write_enable1(1'b0),
   .data_out1(ram_data_out1)
   );
    
endmodule

//------------------------------------------------------------------------------
module axi_data_fifo_ram #
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

