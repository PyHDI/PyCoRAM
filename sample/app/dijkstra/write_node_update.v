//`include "pycoram.v"

`default_nettype none

module write_node_update #
  (
   parameter W_D = 32,
   parameter W_A = 10,
   parameter W_COMM_A = 4
   )
  (
   input CLK,
   input RST,

   input [W_D-1:0] write_addr,
   input write_valid,
   output write_ready,
   input [W_D-1:0] next_cost,
   input [W_D-1:0] parent_addr,

   output write_empty
   );

  wire [W_D-1:0] comm_d;
  wire           comm_enq;
  wire           comm_almost_full;
  wire [W_D-1:0] comm_q;
  wire           comm_deq;
  wire           comm_empty;

  wire [W_D*2-1:0] node_out_d;
  wire node_out_enq;
  wire node_out_full;
  wire node_out_almost_full;

  assign write_ready = !comm_almost_full && !node_out_almost_full;
  assign node_out_enq = write_valid && !comm_almost_full && !node_out_almost_full;
  assign comm_enq = write_valid && !comm_almost_full && !node_out_almost_full;
  assign node_out_d = {next_cost, parent_addr};
  assign comm_d = write_addr;
  assign comm_deq = 0;
  assign write_empty = comm_empty;
  
  CoramOutStream
  #(
    .CORAM_THREAD_NAME("cthread_write_node_update"),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(W_A),
    .CORAM_DATA_WIDTH(W_D * 2)
    )
  inst_write_node_outstream
  (
   .CLK(CLK),
   .RST(RST),
   .D(node_out_d),
   .ENQ(node_out_enq),
   .FULL(node_out_full),
   .ALM_FULL(node_out_almost_full)
   );
  
  CoramChannel
  #(
    .CORAM_THREAD_NAME("cthread_write_node_update"),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(W_COMM_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_comm_channel
  (.CLK(CLK),
   .RST(RST),
   .D(comm_d),
   .ENQ(comm_enq),
   .ALM_FULL(comm_almost_full),
   .Q(comm_q),
   .DEQ(comm_deq),
   .EMPTY(comm_empty)
   );
endmodule

`default_nettype wire

