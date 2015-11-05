//`include "pycoram.v"

`default_nettype none

module read_edge #
  (
   parameter W_D = 32,
   parameter W_A = 10,
   parameter W_COMM_A = 6
   )
  (
   input CLK,
   input RST,

   input [W_D-1:0] req_addr, // page_addr
   input req_valid,
   output req_ready,

   output data_valid,
   input data_ready,
   output data_end,   
   output [W_D-1:0] next_addr,
   output [W_D-1:0] next_cost
   );

  reg [W_D-1:0]  comm_d;
  reg            comm_enq;
  wire           comm_almost_full;
  wire [W_D-1:0] comm_q;
  reg            comm_deq;
  wire           comm_empty;

  wire [W_D*2-1:0] next_q;
  wire next_deq;
  wire next_empty;
  wire next_almost_empty;

  reg [W_D*2-1:0] d_next_q;

  reg d_data_valid;
  reg d_data_ready;
  reg d_next_deq;

  reg [W_D-1:0] page_size;
  reg [W_D-1:0] next_page_addr;

  reg [W_D-1:0] count;
  reg [3:0] state;
  
  assign req_ready = !comm_almost_full && (state == 'h0);
  assign next_deq = !next_empty &&
                    ((state == 'h1 && !d_next_deq) ||
                     (state == 'h3 && ((data_valid && data_ready) || !data_valid) &&
                      !((count == page_size - 1) && (data_valid && data_ready))));
  assign data_valid = (state == 'h3) && (d_next_deq || (d_data_valid && !d_data_ready));
  assign data_end = (state == 'h3) && (count == page_size - 1) && data_valid && (next_page_addr == 0);
  assign {next_cost, next_addr} = d_data_ready? next_q : d_next_q;
  
  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      comm_d <= 0;
      comm_enq <= 0;
      comm_deq <= 0;
      d_next_q <= 0;
      d_data_valid <= 0;      
      d_data_ready <= 0;
      d_next_deq <= 0;
      page_size <= 0;
      next_page_addr <= 0;
      count <= 0;
    end else begin
      comm_enq <= 0;
      comm_deq <= 0;
      d_data_valid <= data_valid;
      d_data_ready <= data_ready;
      d_next_deq <= next_deq;
      if(d_next_deq) d_next_q <= next_q;
      
      case(state)
        'h0: begin
          if(req_valid && !comm_almost_full) begin
            comm_d <= req_addr;
            comm_enq <= 1;
            count <= 0;
            state <= 'h1;
          end
        end
        'h1: begin
          if(d_next_deq) begin
            {next_page_addr, page_size} <= next_q;
            comm_d <= next_q[W_D-1:0]; // size
            comm_enq <= 1;
            state <= 'h2;
          end
        end
        'h2: begin
          if(next_page_addr != 0) begin
            if(!comm_almost_full) begin
              comm_d <= next_page_addr;
              comm_enq <= 1;
              state <= 'h3;
            end
          end else begin
            state <= 'h3;
          end
        end
        'h3: begin
          if(data_valid && data_ready) begin
            count <= count + 1;
            if(count == page_size - 1) begin
              count <= 0;
              if(next_page_addr != 0) begin
                state <= 'h1;
              end else begin
                state <= 'h0;
              end
            end
          end
        end
      endcase
    end
  end
  
  CoramInStream
  #(
    .CORAM_THREAD_NAME("cthread_read_edge"),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(W_A),
    .CORAM_DATA_WIDTH(W_D * 2)
    )
  inst_read_edge_instream
  (
   .CLK(CLK),
   .RST(RST),
   .Q(next_q),
   .DEQ(next_deq),
   .EMPTY(next_empty),
   .ALM_EMPTY(next_almost_empty)
   );
  
  CoramChannel
  #(
    .CORAM_THREAD_NAME("cthread_read_edge"),
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

