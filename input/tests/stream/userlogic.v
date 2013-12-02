`include "pycoram.v"

`define THREAD_NAME "ctrl_thread"

module userlogic #  
  (
   parameter W_A = 6,
   parameter W_COMM_A = 4,
   parameter W_D = 32,
   parameter SIZE = 128
   )
  (
   input CLK,
   input RST,
   output reg [4:0] led
   );

  wire [W_D-1:0] instream_q;
  wire           instream_deq;
  wire           instream_empty;
  wire           instream_almost_empty;
  
  wire [W_D-1:0] outstream_d;
  wire           outstream_enq;
  wire           outstream_full;
  wire           outstream_almost_full;
  
  reg [W_D-1:0]  comm_d;
  reg            comm_enq;
  wire           comm_full;
  wire [W_D-1:0] comm_q;
  reg            comm_deq;
  wire           comm_empty;

  reg            d_instream_deq;
  reg [31:0]     read_count;
  reg [31:0]     write_count;
  
  reg [3:0] state;
  reg [31:0] sum;

  assign instream_deq = (state == 1) && !instream_empty && (read_count < SIZE);
  assign outstream_enq = (state == 3) && !outstream_full && (write_count < SIZE);
  assign outstream_d = write_count;
  
  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      comm_deq <= 0;
      comm_enq <= 0;
    end else begin
      // default value
      comm_enq <= 0;
      comm_deq <= 0;
      d_instream_deq <= instream_deq;
      if(state == 0) begin
        sum <= 0;
        read_count <= 0;
        if(!comm_empty) begin
          comm_deq <= 1;
          state <= 1;
        end
      end else if(state == 1) begin
        if(instream_deq) begin
          read_count <= read_count + 1;
        end
        if(d_instream_deq) begin
          sum <= sum + instream_q;
          if(read_count == SIZE) begin
            state <= 2;
          end
        end
      end else if(state == 2) begin
        read_count <= 0;
        write_count <= 0;
        if(!comm_full) begin
          comm_d <= sum;
          comm_enq <= 1;
          state <= 3;
        end
      end else if(state == 3) begin
        comm_enq <= 0;
        if(outstream_enq) begin
          write_count <= write_count + 1;
        end
        if(!comm_empty) begin
          comm_deq <= 1;
          state <= 1;
        end
      end
    end
  end

  CoramInStream
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(W_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_data_instream
  (.CLK(CLK),
   .RST(RST),
   .Q(instream_q),
   .DEQ(instream_deq),
   .EMPTY(instream_empty),
   .ALM_EMPTY(instream_almost_empty)
   );

  CoramOutStream
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(W_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_data_outstream
  (.CLK(CLK),
   .RST(RST),
   .D(outstream_d),
   .ENQ(outstream_enq),
   .FULL(outstream_full),
   .ALM_FULL(outstream_almost_full)
   );

  CoramChannel
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(W_COMM_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_comm_channel
  (.CLK(CLK),
   .RST(RST),
   .D(comm_d),
   .ENQ(comm_enq),
   .FULL(comm_full),
   .Q(comm_q),
   .DEQ(comm_deq),
   .EMPTY(comm_empty)
   );

endmodule
  
