//`include "pycoram.v"

`default_nettype none
  
module read_node #
  (
   parameter W_D = 32,
   parameter W_A = 10,
   parameter W_COMM_A = 4
   )
  (
   input CLK,
   input RST,
   
   input [W_D-1:0] req_addr,
   input req_valid,
   output req_ready,
   
   output data_valid,
   input data_ready,
   output [W_D-1:0] page_addr,
   output [W_D-1:0] parent_addr,
   output [W_D-1:0] current_cost,
   output [W_D-1:0] visited
   );

  reg [W_D-1:0]  comm_d;
  reg            comm_enq;
  wire           comm_almost_full;
  wire [W_D-1:0] comm_q;
  reg            comm_deq;
  wire           comm_empty;

  wire [W_D*4-1:0] node_in_q;
  wire node_in_deq;
  wire node_in_empty;
  wire node_in_almost_empty;

  reg [W_D*4-1:0] d_node_in_q;

  reg d_data_valid;
  reg d_data_ready;
  reg d_node_in_deq;
  
  assign req_ready = !comm_almost_full;
  assign node_in_deq = ((data_valid && data_ready) || !data_valid) && !node_in_empty;
  assign data_valid = (d_node_in_deq || (d_data_valid && !d_data_ready));
  assign {visited, page_addr, current_cost, parent_addr} = d_data_ready? node_in_q : d_node_in_q;

  always @(posedge CLK) begin
    if(RST) begin
      comm_d <= 0;
      comm_enq <= 0;
      comm_deq <= 0;
      d_data_valid <= 0;      
      d_data_ready <= 0;
      d_node_in_deq <= 0;
    end else begin
      comm_enq <= 0;
      comm_deq <= 0;
      d_data_valid <= data_valid;
      d_data_ready <= data_ready;
      d_node_in_deq <= node_in_deq;
      if(d_node_in_deq) d_node_in_q <= node_in_q;
      
      if(req_valid && !comm_almost_full) begin
        comm_d <= req_addr;
        comm_enq <= 1;
      end
    end
  end
  
  CoramInStream
  #(
    .CORAM_THREAD_NAME("cthread_read_node"),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(W_A),
    .CORAM_DATA_WIDTH(W_D * 4)
    )
  inst_read_node_instream
  (
   .CLK(CLK),
   .RST(RST),
   .Q(node_in_q),
   .DEQ(node_in_deq),
   .EMPTY(node_in_empty),
   .ALM_EMPTY(node_in_almost_empty)
   );

  CoramChannel
  #(
    .CORAM_THREAD_NAME("cthread_read_node"),
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
