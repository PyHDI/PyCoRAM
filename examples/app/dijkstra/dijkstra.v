`include "pycoram.v"
`include "frontier.v"
`include "read_node.v"
`include "read_edge.v"
`include "write_node_update.v"
`include "write_node_visited.v"

`default_nettype none

module dijkstra #
  (
   parameter W_D = 32,
   parameter W_A = 10,
   parameter W_COMM_A = 4,
   parameter W_OCM_A = 8
   )
  (
   input CLK,
   input RST
   );

  reg [W_D-1:0]  comm_d;
  reg            comm_enq;
  wire           comm_almost_full;
  wire [W_D-1:0] comm_q;
  reg            comm_deq;
  wire           comm_empty;

  reg [W_D-1:0] heap_offset;
  reg [W_D-1:0] start_node_addr;
  reg [W_D-1:0] goal_node_addr;

  reg [7:0] state;
  
  //------------------------------------------------------------------------------
  wire frontier_read_req_valid;
  wire frontier_read_req_ready;
  wire frontier_read_data_valid;
  wire [W_D-1:0] frontier_read_node_addr;
  wire [W_D-1:0] frontier_read_cost;
  wire frontier_read_empty;

  wire frontier_write_valid;
  wire frontier_write_ready;
  wire [W_D-1:0] frontier_write_node_addr;
  wire [W_D-1:0] frontier_write_cost;

  wire frontier_reset_state;
  
  frontier #
  (
   .W_D(W_D),
   .W_A(W_A),
   .W_OCM_A(W_OCM_A),
   .W_COMM_A(W_COMM_A)
   )
  inst_frontier
  (
   .CLK(CLK),
   .RST(RST),

   .offset(heap_offset),
   
   .read_req_valid(frontier_read_req_valid),
   .read_req_ready(frontier_read_req_ready),
   .read_data_valid(frontier_read_data_valid),
   .read_node_addr(frontier_read_node_addr),
   .read_cost(frontier_read_cost),
   .read_empty(frontier_read_empty),
   
   .write_valid(frontier_write_valid),
   .write_ready(frontier_write_ready),
   .write_node_addr(frontier_write_node_addr),
   .write_cost(frontier_write_cost),

   .reset_state(frontier_reset_state)
   );

  //------------------------------------------------------------------------------
  wire [W_D-1:0] read_node_req_addr;
  wire read_node_req_valid;
  wire read_node_req_ready;

  wire read_node_data_valid;
  wire read_node_data_ready;
  wire [W_D-1:0] read_node_page_addr;
  wire [W_D-1:0] read_node_parent_addr;
  wire [W_D-1:0] read_node_current_cost;
  wire [W_D-1:0] read_node_visited;

  read_node #
  (
   .W_D(W_D),
   .W_A(W_A),
   .W_COMM_A(W_COMM_A)
   )
  inst_read_node
  (
   .CLK(CLK),
   .RST(RST),

   .req_addr(read_node_req_addr),
   .req_valid(read_node_req_valid),
   .req_ready(read_node_req_ready),
   
   .data_valid(read_node_data_valid),
   .data_ready(read_node_data_ready),
   .page_addr(read_node_page_addr),
   .parent_addr(read_node_parent_addr),
   .current_cost(read_node_current_cost),
   .visited(read_node_visited)
   );

  //------------------------------------------------------------------------------
  wire [W_D-1:0] read_edge_req_addr;
  wire read_edge_req_valid;
  wire read_edge_req_ready;

  wire read_edge_data_valid;
  wire read_edge_data_ready;
  wire read_edge_data_end;
  wire [W_D-1:0] read_edge_next_addr;
  wire [W_D-1:0] read_edge_next_cost;

  read_edge #
  (
   .W_D(W_D),
   .W_A(W_A),
   .W_COMM_A(W_COMM_A)
   )
  inst_read_edge
  (
   .CLK(CLK),
   .RST(RST),

   .req_addr(read_edge_req_addr),
   .req_valid(read_edge_req_valid),
   .req_ready(read_edge_req_ready),

   .data_valid(read_edge_data_valid),
   .data_ready(read_edge_data_ready),
   .data_end(read_edge_data_end),
   .next_addr(read_edge_next_addr),
   .next_cost(read_edge_next_cost)
   );
  
  //------------------------------------------------------------------------------
  wire [W_D-1:0] edgeinfo_addr_in;
  wire [W_D-1:0] edgeinfo_cost_in;
  wire edgeinfo_enq;
  wire edgeinfo_full;
  wire edgeinfo_almost_full;

  wire [W_D-1:0] edgeinfo_addr_out;
  wire [W_D-1:0] edgeinfo_cost_out;
  wire edgeinfo_deq;
  wire edgeinfo_empty;
  wire edgeinfo_almost_empty;

  edgeinfo_fifo #
  (
   .ADDR_LEN(W_COMM_A),
   .DATA_WIDTH(W_D * 2)
   )
  inst_edgeinfo_fifo
  (
   .CLK(CLK),
   .RST(RST),
   .Q({edgeinfo_addr_out, edgeinfo_cost_out}),
   .DEQ(edgeinfo_deq),
   .EMPTY(edgeinfo_empty),
   .ALM_EMPTY(edgeinfo_almost_empty),
   .D({edgeinfo_addr_in, edgeinfo_cost_in}),
   .ENQ(edgeinfo_enq),
   .FULL(edgeinfo_full),
   .ALM_FULL(edgeinfo_almost_full)
   );
  
  //------------------------------------------------------------------------------
  wire [W_D-1:0] write_node_update_write_addr;
  wire write_node_update_write_valid;
  wire write_node_update_write_ready;
  wire [W_D-1:0] write_node_update_next_cost;
  wire [W_D-1:0] write_node_update_parent_addr;
  wire write_node_update_write_empty;
  
  write_node_update #
  (
   .W_D(W_D),
   .W_A(W_A),
   .W_COMM_A(W_COMM_A)
   )
  inst_write_node_update
  (
   .CLK(CLK),
   .RST(RST),

   .write_addr(write_node_update_write_addr),
   .write_valid(write_node_update_write_valid),
   .write_ready(write_node_update_write_ready),
   .next_cost(write_node_update_next_cost),
   .parent_addr(write_node_update_parent_addr),
   .write_empty(write_node_update_write_empty)
   );

  //------------------------------------------------------------------------------
  wire [W_D-1:0] write_node_visited_write_addr;
  wire write_node_visited_write_valid;
  wire write_node_visited_write_ready;
  wire write_node_visited_write_empty;
  
  write_node_visited #
  (
   .W_D(W_D),
   .W_A(W_A),
   .W_COMM_A(W_COMM_A)
   )
  inst_write_node_visited
  (
   .CLK(CLK),
   .RST(RST),

   .write_addr(write_node_visited_write_addr),
   .write_valid(write_node_visited_write_valid),
   .write_ready(write_node_visited_write_ready),
   .write_empty(write_node_visited_write_empty)
   );

  //------------------------------------------------------------------------------
  // main FSM
  //------------------------------------------------------------------------------
  reg [W_D-1:0] current_node_addr;
  reg [W_D-1:0] page_addr;
  reg [W_D-1:0] current_cost;
  
  reg edge_data_end;
  reg [W_D-1:0] read_edge_count;
  reg [W_D-1:0] read_node_count;
  
  reg [63:0] cycle_count;
  
  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      comm_d <= 0;
      comm_enq <= 0;
      comm_deq <= 0;
      heap_offset <= 0;
      start_node_addr <= 0;
      goal_node_addr <= 0;
      current_node_addr <= 0;
      page_addr <= 0;
      current_cost <= 0;
      edge_data_end <= 0;
      read_edge_count <= 0;
      read_node_count <= 0;
      cycle_count <= 0;
    end else begin
      comm_enq <= 0;
      comm_deq <= 0;
      cycle_count <= cycle_count + 1;

      case(state)
        //------------------------------------------------------------------------------
        // initialization
        //------------------------------------------------------------------------------
        'h00: begin
          if(!comm_empty) begin
            comm_deq <= 1;
            state <= 'h01;
          end
        end
        'h01: begin
          heap_offset <= comm_q;
          state <= 'h02;
        end
        'h02: begin
          if(!comm_empty) begin
            comm_deq <= 1;
            state <= 'h03;
          end
        end
        'h03: begin
          start_node_addr <= comm_q;
          state <= 'h04;
        end
        'h04: begin
          if(!comm_empty) begin
            comm_deq <= 1;
            state <= 'h05;
          end
        end
        'h05: begin
          goal_node_addr <= comm_q;
          cycle_count <= 0; // reset cycle count
          state <= 'h06;
        end
        'h06: begin // write node
          if(write_node_update_write_ready) begin
            state <= 'h07;
            $display("[HDL] heap_offset=%x", heap_offset);
            $display("[HDL] start_node_addr=%x", start_node_addr);
            $display("[HDL] goal_node_addr=%x", goal_node_addr);
            $display("[HDL] write node update, dst_addr=%x, parent_addr=%x new_cost=%d",
                     write_node_update_write_addr, write_node_update_parent_addr, write_node_update_next_cost);
          end
        end
        'h07: begin // write node visited and add frontier (start node)
          if(frontier_write_ready) begin
            state <= 'h10;
            $display("[HDL] add frontier, first, addr=%x, cost=%d",
                     frontier_write_node_addr, frontier_write_cost);
          end
        end

        //------------------------------------------------------------------------------
        // main
        //------------------------------------------------------------------------------
        'h10: begin // read frontier (request)
          if(frontier_read_empty) begin
            current_cost <= {W_D{1'b1}};
            state <= 'h30;
            $display("[HDL] goal not found");
          end else if(frontier_read_req_ready) begin
            state <= 'h11;
            $display("[HDL] read frontier request");
          end
        end
        'h11: begin // read frontier (get data)
          if(frontier_read_data_valid) begin
            current_node_addr <= frontier_read_node_addr;
            current_cost <= frontier_read_cost;
            state <= 'h12;
            $display("[HDL] read frontier %x", frontier_read_node_addr);
          end
        end
        'h12: begin // read node (request)
          if(read_node_req_ready) begin
            state <= 'h13;
            $display("[HDL] read node request");
          end
        end
        'h13: begin // read node (get data)
          if(read_node_data_valid) begin
            page_addr <= read_node_page_addr;
            if(current_node_addr == goal_node_addr) begin
              state <= 'h30;
              $display("[HDL] goal found");
            end else if(read_node_visited) begin
              state <= 'h10; // try next
              $display("[HDL] read node, but visited");
            end else begin
              state <= 'h14;
              $display("[HDL] read node, page_addr=%x current_cost=%d",
                       read_node_page_addr, read_node_current_cost);
            end
          end
        end
        'h14: begin // write node visit 
          if(write_node_visited_write_ready) begin
            if(page_addr == 0) begin
              state <= 'h10; // try next node
              $display("[HDL] no edges for this node: %x", current_node_addr);
            end else begin
              edge_data_end <= 0;
              read_edge_count <= 0;
              read_node_count <= 0;
              state <= 'h20;
            end
            $display("[HDL] write node visit");
          end
        end

        //------------------------------------------------------------------------------
        // Pipeline Phase
        //------------------------------------------------------------------------------
        'h20: begin
          //----------------------------------------
          // Read Edge
          //----------------------------------------
          if(read_edge_data_valid && read_edge_data_ready) begin
            read_edge_count <= read_edge_count + 1;
            $display("[HDL] read edge, next_node_addr=%x edge_cost=%d",
                     read_edge_next_addr, read_edge_next_cost);
            if(read_edge_data_end) begin
              edge_data_end <= 1;
              $display("[HDL] read edge end now");
            end
          end

          //----------------------------------------
          // Read Node
          //----------------------------------------
          if(read_node_data_valid && read_node_data_ready) begin
            read_node_count <= read_node_count + 1;
            $display("[HDL] read neighbor node, visited=%d, current_cost=%d",
                     read_node_visited, read_node_current_cost);
            if(!read_node_visited &&
               (read_node_current_cost > edgeinfo_cost_out + current_cost)) begin
              $display("[HDL] read neighbor node, update");
            end
          end

          //----------------------------------------
          // Update Node and Push Frontier
          //----------------------------------------
          if(write_node_update_write_valid && write_node_update_write_ready) begin
            $display("[HDL] write node update, dst_addr=%x, parent_addr=%x new_cost=%d",
                     write_node_update_write_addr, write_node_update_parent_addr, write_node_update_next_cost);
          end
          if(frontier_write_valid && frontier_write_ready) begin
            $display("[HDL] add frontier, dst_addr=%x, new_cost=%d",
                     frontier_write_node_addr, frontier_write_cost);
          end
          // Pipeline Termination Condtion
          if(write_node_update_write_ready && frontier_write_ready && 
             edge_data_end && (read_edge_count == read_node_count)) begin
            state <= 'h10;
          end
        end
        
        //------------------------------------------------------------------------------
        // finalization
        //------------------------------------------------------------------------------
        'h30: begin // goal node found
          comm_d <= current_cost;
          if(!comm_almost_full) begin
            comm_enq <= 1;
            $display("[HDL] cost=%d", current_cost);
            state <= 'h31;
          end
        end
        'h31: begin
          comm_d <= cycle_count;
          if(!comm_almost_full) begin
            comm_enq <= 1;
            $display("[HDL] cycles=%d", cycle_count);
            state <= 'h00;
          end
        end
      endcase
    end
  end

  //------------------------------------------------------------------------------
  assign frontier_read_req_valid = (state == 'h10);
  
  assign write_node_visited_write_addr = current_node_addr;
  assign write_node_visited_write_valid = (state == 'h14);

  assign read_edge_req_addr = page_addr;
  assign read_edge_req_valid = (state == 'h20) && !edge_data_end && !read_edge_data_end;
  assign read_edge_data_ready = (state == 'h20 && read_node_req_ready && !edgeinfo_almost_full);

  assign edgeinfo_addr_in = read_edge_next_addr;
  assign edgeinfo_cost_in = read_edge_next_cost;
  assign edgeinfo_enq = (state == 'h20 && read_edge_data_valid && read_edge_data_ready);
  assign edgeinfo_deq = (state == 'h20 && read_node_data_valid && read_node_data_ready);
  
  assign read_node_req_addr = (state == 'h12)? current_node_addr : read_edge_next_addr;
  assign read_node_req_valid = (state == 'h12) || (state == 'h20 && read_edge_data_valid && read_edge_data_ready);
  assign read_node_data_ready = (state == 'h13) ||
                                (state == 'h20 && write_node_update_write_ready && !edgeinfo_empty);

  assign write_node_update_write_addr = (state == 'h06)? start_node_addr : edgeinfo_addr_out;
  assign write_node_update_write_valid = (state == 'h06) ||
                                         (state == 'h20 && 
                                          read_node_data_valid && read_node_data_ready &&
                                          !read_node_visited &&
                                          (read_node_current_cost > edgeinfo_cost_out + current_cost));
  assign write_node_update_parent_addr = (state == 'h06)? start_node_addr : current_node_addr;
  assign write_node_update_next_cost = (state == 'h06)? 0 : edgeinfo_cost_out + current_cost;
  
  assign frontier_write_node_addr = (state == 'h07)? start_node_addr : edgeinfo_addr_out;
  assign frontier_write_valid = (state == 'h07) ||
                                (state == 'h20 &&
                                 read_node_data_valid && read_node_data_ready &&
                                 !read_node_visited &&
                                 (read_node_current_cost > edgeinfo_cost_out + current_cost));
  assign frontier_write_cost = (state == 'h07)? 0 : edgeinfo_cost_out + current_cost;
  
  assign frontier_reset_state = (state == 'h00);
  
  //------------------------------------------------------------------------------
  CoramChannel
  #(
    .CORAM_THREAD_NAME("cthread_dijkstra"),
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

//------------------------------------------------------------------------------
module edgeinfo_fifo(CLK, RST,
                     Q, DEQ, EMPTY, ALM_EMPTY,
                     D, ENQ,  FULL,  ALM_FULL);
  parameter ADDR_LEN = 10;
  parameter DATA_WIDTH = 32;
  localparam MEM_SIZE = 2 ** ADDR_LEN;
  input                         CLK;
  input                         RST;
  output [DATA_WIDTH-1:0] Q;
  input                         DEQ;
  output                        EMPTY;
  output                        ALM_EMPTY;
  input  [DATA_WIDTH-1:0] D;
  input                         ENQ;
  output                        FULL;
  output                        ALM_FULL;

  reg EMPTY;
  reg ALM_EMPTY;
  reg FULL;
  reg ALM_FULL;

  reg [ADDR_LEN-1:0] head;
  reg [ADDR_LEN-1:0] tail;

  wire ram_we;
  assign ram_we = ENQ && !FULL;
  
  function [ADDR_LEN-1:0] to_gray;
    input [ADDR_LEN-1:0] in;
    to_gray = in ^ (in >> 1);
  endfunction
  
  function [ADDR_LEN-1:0] mask;
    input [ADDR_LEN-1:0] in;
    mask = in[ADDR_LEN-1:0];
  endfunction
  
  // Read Pointer
  always @(posedge CLK) begin
    if(RST) begin
      head <= 0;
    end else begin
      if(!EMPTY && DEQ) head <= head == (MEM_SIZE-1)? 0 : head + 1;
    end
  end
  
  // Write Pointer
  always @(posedge CLK) begin
    if(RST) begin
      tail <= 0;
    end else begin
      if(!FULL && ENQ) tail <= tail == (MEM_SIZE-1)? 0 : tail + 1;
    end
  end
  
  always @(posedge CLK) begin
    if(RST) begin
      EMPTY <= 1'b1;
      ALM_EMPTY <= 1'b1;
    end else begin
      if(DEQ && !EMPTY) begin
        if(ENQ && !FULL) begin
          EMPTY <= (mask(tail+1) == mask(head+1));
          ALM_EMPTY <= (mask(tail+1) == mask(head+2)) || (mask(tail+1) == mask(head+1));
        end else begin
          EMPTY <= (tail == mask(head+1));
          ALM_EMPTY <= (tail == mask(head+2)) || (tail == mask(head+1));
        end
      end else begin
        if(ENQ && !FULL) begin
          EMPTY <= (mask(tail+1) == mask(head));
          ALM_EMPTY <= (mask(tail+1) == mask(head+1)) || (mask(tail+1) == mask(head));
        end else begin
          EMPTY <= (tail == mask(head));
          ALM_EMPTY <= (tail == mask(head+1)) || (tail == mask(head));
        end
      end
    end
  end
  
  always @(posedge CLK) begin
    if(RST) begin
      FULL <= 1'b0;
      ALM_FULL <= 1'b0;
    end else begin
      if(ENQ && !FULL) begin
        if(DEQ && !EMPTY) begin
          FULL <= (mask(head+1) == mask(tail+2));
          ALM_FULL <= (mask(head+1) == mask(tail+3)) || (mask(head+1) == mask(tail+2));
        end else begin
          FULL <= (head == mask(tail+2));
          ALM_FULL <= (head == mask(tail+3)) || (head == mask(tail+2));
        end
      end else begin
        if(DEQ && !EMPTY) begin
          FULL <= (mask(head+1) == mask(tail+1));
          ALM_FULL <= (mask(head+1) == mask(tail+2)) || (mask(head+1) == mask(tail+1));
        end else begin
          FULL <= (head == mask(tail+1));
          ALM_FULL <= (head == mask(tail+2)) || (head == mask(tail+1));
        end
      end
    end
  end
  
  edgeinfo_lutram2 #(.W_A(ADDR_LEN), .W_D(DATA_WIDTH))
  ram (.CLK0(CLK), .ADDR0(head), .D0('h0), .WE0(1'b0), .Q0(Q), // read
       .CLK1(CLK), .ADDR1(tail), .D1(D), .WE1(ram_we), .Q1()); // write
  
endmodule

module edgeinfo_lutram2(CLK0, ADDR0, D0, WE0, Q0, 
                        CLK1, ADDR1, D1, WE1, Q1);
  parameter W_A = 10;
  parameter W_D = 32;
  localparam LEN = 2 ** W_A;
  input            CLK0;
  input  [W_A-1:0] ADDR0;
  input  [W_D-1:0] D0;
  input            WE0;
  output [W_D-1:0] Q0;
  input            CLK1;
  input  [W_A-1:0] ADDR1;
  input  [W_D-1:0] D1;
  input            WE1;
  output [W_D-1:0] Q1;
  
  reg [W_A-1:0] d_ADDR0;
  reg [W_A-1:0] d_ADDR1;
  reg [W_D-1:0] mem [0:LEN-1];
  
  always @(posedge CLK0) begin
    if(WE0) mem[ADDR0] <= D0;
    d_ADDR0 <= ADDR0;
  end
  always @(posedge CLK1) begin
    if(WE1) mem[ADDR1] <= D1;
    d_ADDR1 <= ADDR1;
  end
  //assign Q0 = mem[d_ADDR0];
  //assign Q1 = mem[d_ADDR1];
  assign Q0 = mem[ADDR0];
  assign Q1 = mem[ADDR1];
endmodule

`default_nettype wire

