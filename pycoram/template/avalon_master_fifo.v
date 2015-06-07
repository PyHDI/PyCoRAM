
`define AVMF_C_LOG_2(n) (\
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

module avalon_master_fifo #
  (
   //----------------------------------------------------------------------------
   // User Parameter
   //----------------------------------------------------------------------------
   parameter integer FIFO_ADDR_WIDTH = 4,

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
   // User Interface
   //----------------------------------------------------------------------------
   // Data Channel
   input                         user_write_enq,
   input [C_AVM_DATA_WIDTH-1:0]  user_write_data,
   output                        user_write_almost_full,
   input                         user_read_deq,
   output [C_AVM_DATA_WIDTH-1:0] user_read_data,
   output                        user_read_empty,

   // Command Channel
   input [C_AVM_ADDR_WIDTH-1:0]  user_addr,
   input                         user_read_enable,
   input                         user_write_enable,
   input [8:0]                   user_word_size,
   output reg                    user_done,
   
   //----------------------------------------------------------------------------
   // Avalon Master Interface
   //----------------------------------------------------------------------------
   // Common
   output wire [C_AVM_ADDR_WIDTH-1:0]   avm_address,
   input  wire                          avm_waitrequest,
   output wire [C_AVM_DATA_WIDTH/8-1:0] avm_byteenable,
   output wire [8:0]                    avm_burstcount,
   
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
  // Internal Constant
  //------------------------------------------------------------------------------
  localparam integer BURST_COUNT_WIDTH = C_AVM_ADDR_WIDTH + 1;
  localparam integer ADDRMASK_WIDTH = `AVMF_C_LOG_2(C_AVM_DATA_WIDTH / 8);

  //------------------------------------------------------------------------------
  // Data Channel (Read FIFO / Write FIFO)
  //------------------------------------------------------------------------------
  wire                        write_deq;
  wire [C_AVM_DATA_WIDTH-1:0] write_data;
  wire                        write_empty;

  reg                         read_enq;
  reg  [C_AVM_DATA_WIDTH-1:0] read_data;
  wire                        read_almost_full;

  // Write
  avm_data_fifo 
  #(
    .DATA_WIDTH(C_AVM_DATA_WIDTH),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    )
  inst_write_fifo
  (
   .ACLK(ACLK), .ARESETN(ARESETN),
   .enq(user_write_enq), .data_in(user_write_data), .almost_full(user_write_almost_full),
   .deq(write_deq), .data_out(write_data), .empty(write_empty)
   );

  // Read
  avm_data_fifo 
  #(
    .DATA_WIDTH(C_AVM_DATA_WIDTH),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    )
  inst_read_fifo
  (
   .ACLK(ACLK), .ARESETN(ARESETN),
   .enq(read_enq), .data_in(read_data), .almost_full(read_almost_full), 
   .deq(user_read_deq), .data_out(user_read_data), .empty(user_read_empty)
   );
  
  //------------------------------------------------------------------------------
  // Internal
  //------------------------------------------------------------------------------
  reg [C_AVM_ADDR_WIDTH-1:0] user_word_size_buf;

  reg read_busy;
  reg read_addr_done;
  reg [BURST_COUNT_WIDTH-1:0] read_cnt;

  reg write_busy;
  reg write_addr_done;
  reg [BURST_COUNT_WIDTH-1:0] write_cnt;
  
  //----------------------------------------------------------------------------
  // Avalon
  //----------------------------------------------------------------------------
  assign avm_address = C_AVM_TARGET + addrmask(user_addr);
  assign avm_byteenable = {(C_AVM_DATA_WIDTH/8){1'b1}};
  assign avm_burstcount = user_word_size;

  assign avm_read = !user_done && user_read_enable && !read_addr_done;
  assign avm_write = (!user_done && user_write_enable && !write_empty) ||
                     (write_busy && !write_empty);
  assign avm_writedata = write_data;

  assign write_deq = (write_busy || (!user_done && user_write_enable)) && 
                     !avm_waitrequest && !write_empty;

  //----------------------------------------------------------------------------
  // State Machine
  //----------------------------------------------------------------------------
  function [C_AVM_ADDR_WIDTH-1:0] addrmask;
    input [C_AVM_ADDR_WIDTH-1:0] in;
    addrmask = { in[C_AVM_ADDR_WIDTH-1:ADDRMASK_WIDTH], {ADDRMASK_WIDTH{1'b0}} };
  endfunction

  always @(posedge ACLK) begin
    if(aresetn_rrr == 0) begin
      read_busy <= 0;
      read_addr_done <= 0;
      write_busy <= 0;
      read_enq <= 0;
      read_data <= 0;
      read_cnt <= 0;
      write_cnt <= 0;
      user_done <= 0;
      user_word_size_buf <= 0;
    end else begin
      //default
      read_enq <= 0;
      user_done <= 0;
      read_addr_done <= 0;

      //----------------------------------------------------------------------
      if(read_busy) begin
        read_addr_done <= !avm_waitrequest;
        if(avm_readdatavalid) begin
          read_data <= avm_readdata;
          read_enq <= 1;
          read_cnt <= read_cnt + 1;
          if(read_cnt == user_word_size_buf - 1) begin
            read_busy <= 0;
            user_done <= 1;
          end
        end
      end
      //----------------------------------------------------------------------
      else if(write_busy) begin
        if(!avm_waitrequest && !write_empty) begin
          write_cnt <= write_cnt + 1;
          if(write_cnt == user_word_size_buf - 1) begin
            write_busy <= 0;
            user_done <= 1;
          end
        end
      end
      //----------------------------------------------------------------------
      else if(!user_done && user_read_enable) begin // user_done is ack
        read_cnt <= 0;
        user_word_size_buf <= user_word_size;
        read_busy <= 1;
        read_addr_done <= !avm_waitrequest;
      end
      //----------------------------------------------------------------------
      else if(!user_done && user_write_enable) begin // user_done is ack
        write_cnt <= 1;
        user_word_size_buf <= user_word_size;
        if(!avm_waitrequest && !write_empty && user_word_size > 1) write_busy <= 1;
        if(!avm_waitrequest && !write_empty && user_word_size <= 1) user_done <= 1;
      end 
      //----------------------------------------------------------------------

    end
  end

endmodule

//------------------------------------------------------------------------------
module avm_data_fifo #
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
  
  avm_data_fifo_ram
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
module avm_data_fifo_ram #
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

