`include "pycoram.v"

`define THREAD_NAME "cthread_heap"

`define CMP(__x, __y) (__x <= __y)
`define MAX_VALUE (32'hffff_ffff)
`define MIN_VALUE (32'h0000_0000)

module heap #  
  (
   parameter W_D = 32,
   parameter W_A = 6,
   parameter W_COMM_A = 4,
   parameter W_OCM_A = 8,
   parameter MODE_MIN = 1
   )
  (
   input CLK,
   input RST,
   
   input write_valid,
   input [W_D-1:0] write_data,
   output write_ready,
   
   input read_request,
   output reg [W_D-1:0] read_data,
   output reg read_valid,
   output read_empty
   );

  wire [W_D-1:0] instream_q;
  wire           instream_deq;
  wire           instream_empty;
  wire           instream_almost_empty;
  reg            d_instream_deq;

  reg  [W_D-1:0] outstream_d;
  reg            outstream_enq;
  wire           outstream_full;
  wire           outstream_almost_full;
  
  reg [W_D-1:0]  comm_d;
  reg            comm_enq;
  wire           comm_almost_full;
  wire [W_D-1:0] comm_q;
  reg            comm_deq;
  wire           comm_empty;

  wire [W_OCM_A-1:0] ocm_read_addr;
  wire [W_D-1:0] ocm_read_q;
  reg  [W_OCM_A-1:0] ocm_write_addr;
  reg  [W_D-1:0] ocm_write_d;
  reg  ocm_write_we;
  
  reg [W_D-1:0] root;
  reg [W_D-1:0] new_value;

  reg [W_D-1:0] left;
  reg [W_D-1:0] right;
  reg [W_D-1:0] parent;
  
  reg [W_D-1:0] num_entries;
  reg [W_D-1:0] index;
  
  reg [7:0] state;
  
  wire deq_cond;
  
  assign write_ready = (state == 'h00) && !comm_almost_full;
  assign read_empty = num_entries == 0;
  assign instream_deq = !instream_empty && !outstream_almost_full &&
                        (state == 'h10 || state == 'h11 || state == 'h12 || state == 'h20) && deq_cond;
  assign deq_cond = ((state == 'h10) && !(num_entries + 1 < (2 ** W_OCM_A))) ||
                    ((state == 'h11) && !((index << 1) < (2 ** W_OCM_A))) ||
                    ((state == 'h12) && !(((index << 1) + 1) < (2 ** W_OCM_A))) ||
                    ((state == 'h20) && !((index >> 1) < (2 ** W_OCM_A)));
  assign ocm_read_addr = (state == 'h00)? ((read_request)? num_entries: (num_entries + 1) >> 1):
                         (state == 'h10)? 2:
                         (state == 'h11)? (index << 1) + 1:
                         (state == 'h13)? ((`CMP(left, right))? index << 2: ((index << 1) + 1) << 1):
                         (state == 'h21)? index >> 2:
                         'h0;

  wire test_cmp_left;
  wire test_cmp_right;
  wire test_cmp_parent;
  assign test_cmp_left = `CMP(new_value, left);
  assign test_cmp_right = `CMP(new_value, right);
  assign test_cmp_parent = `CMP(parent, new_value);
  
  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      read_valid <= 0;
      read_data <= 0;
      comm_d <= 0;
      comm_deq <= 0;
      comm_enq <= 0;
      outstream_d <= 0;
      outstream_enq <= 0;
      d_instream_deq <= 0;
      root <= 0;
      new_value <= 0;
      left <= 0;
      right <= 0;
      parent <= 0;
      num_entries <= 0;
      index <= 0;
    end else begin
      read_valid <= 0;
      comm_enq <= 0;
      comm_deq <= 0;
      outstream_enq <= 0;
      ocm_write_we <= 0;
      d_instream_deq <= instream_deq;
      
      case(state)
        // idle -> memory request
        'h00: begin
          if(read_request && num_entries > 0 && !comm_almost_full) begin
            // downheap
            read_data <= root;
            read_valid <= 1;
            num_entries <= num_entries - 1;
            index <= 1;
            comm_d <= 1; // downheap mode
            comm_enq <= 1;
            state <= 'h10;
            $display("## downheap, root=%d", root);
          end else if(write_valid && !comm_almost_full) begin
            // upheap
            comm_d <= 2; // write mode
            comm_enq <= 1;
            num_entries <= num_entries + 1;
            if(num_entries == 0) begin
              ocm_write_addr <= 1;
              ocm_write_d <= write_data;
              ocm_write_we <= 1;
              outstream_d <= write_data;
              outstream_enq <= 1;
              root <= write_data;
            end else begin
              new_value <= write_data;
              index <= num_entries + 1;
              state <= 'h20;
            end
            $display("## upheap");
          end
        end
        
        // get a new root candidate
        'h10: begin
          if(num_entries == 0) begin
            state <= 'h00;
          end else if(num_entries + 1 < (2 ** W_OCM_A)) begin
            new_value <= ocm_read_q;
            $display("## new_value %d", ocm_read_q);
            state <= 'h11;
          end else if(d_instream_deq) begin
            new_value <= instream_q;
            $display("## new_value %d", instream_q);
            state <= 'h11;
          end
        end
        
        // downheap
        'h11: begin
          if((index << 1) > num_entries) begin
            state <= 'h14;
          end else if((index << 1) < (2 ** W_OCM_A)) begin
            left <= ocm_read_q;
            $display("## left %d", ocm_read_q);
            state <= 'h12;
          end else if(d_instream_deq) begin
            left <= instream_q;
            $display("## left %d", instream_q);
            state <= 'h12;
          end
        end
        'h12: begin
          if(((index << 1) + 1) < (2 ** W_OCM_A)) begin
            right <= ((index << 1) + 1) > num_entries? `MAX_VALUE : ocm_read_q;
            $display("## right %d", ((index << 1) + 1) > num_entries? `MAX_VALUE : ocm_read_q);
            state <= 'h13;
          end else if(d_instream_deq) begin
            right <= ((index << 1) + 1) > num_entries? `MAX_VALUE : instream_q;
            $display("## right %d", ((index << 1) + 1) > num_entries? `MAX_VALUE : instream_q);
            state <= 'h13;
          end
        end
        'h13: begin
          if(!comm_almost_full) begin
            ocm_write_addr <= index;
            ocm_write_d <= (`CMP(new_value, left) &&  `CMP(new_value, right))? new_value:
                           (`CMP(left, right))? left:
                           right;
            ocm_write_we <= (index < (2 ** W_OCM_A));
            outstream_d <= (`CMP(new_value, left) &&  `CMP(new_value, right))? new_value:
                           (`CMP(left, right))? left:
                           right;
            outstream_enq <= 1;
            comm_d <= (`CMP(new_value, left) &&  `CMP(new_value, right))? 1:
                      (`CMP(left, right))? 0:
                      2;
            comm_enq <= 1;
            $display("## DW WRITE %d (%d)",
                     (`CMP(new_value, left) &&  `CMP(new_value, right))? new_value:
                     (`CMP(left, right))? left:
                     right,
                     (`CMP(new_value, left) &&  `CMP(new_value, right))? 1:
                     (`CMP(left, right))? 0:
                     2);
            if(index == 1) begin
              root <= (`CMP(new_value, left) &&  `CMP(new_value, right))? new_value:
                      (`CMP(left, right))? left:
                      right;
            end
            if( `CMP(new_value, left) && `CMP(new_value, right) ) begin
              state <= 'h00;
            end else begin
              index <= (`CMP(left, right))? index << 1: (index << 1) + 1;
              state <= 'h11;
            end
          end
        end
        'h14: begin
          if(index == 1) begin
            root <= new_value;
          end
          ocm_write_addr <= index;
          ocm_write_d <= new_value;
          ocm_write_we <= index < (2 ** W_OCM_A);
          outstream_d <= new_value;
          outstream_enq <= 1;
          state <= 'h00;
        end
        
        // upheap
        'h20: begin
          if((index >> 1) < (2 ** W_OCM_A)) begin
            parent <= ocm_read_q;
            $display("## new_value %d", new_value);
            $display("## parent %d", ocm_read_q);
            state <= 'h21;
          end else  if(d_instream_deq) begin
            parent <= instream_q;
            $display("## new_value %d", new_value);
            $display("## parent %d", instream_q);
            state <= 'h21;
          end
        end
        'h21: begin
          if(!comm_almost_full) begin
            ocm_write_addr <= index;
            ocm_write_d <= `CMP(parent, new_value)? new_value : parent;
            ocm_write_we <= (index < (2 ** W_OCM_A));
            outstream_d <= `CMP(parent, new_value)? new_value : parent;
            outstream_enq <= 1;
            comm_d <= `CMP(parent, new_value)? 1'b1 : 1'b0;
            comm_enq <= 1;
            index <= index >> 1;
            $display("## UP WRITE %d (%d)",
                     `CMP(parent, new_value)? new_value : parent, `CMP(parent, new_value));
            if( `CMP(parent, new_value) ) begin
              state <= 'h22;
            end else if((index >> 1) == 1) begin
              state <= 'h23;
            end else begin
              state <= 'h20;
            end
          end
        end
        'h22: begin
          ocm_write_addr <= index;
          ocm_write_d <= parent;
          ocm_write_we <= (index < (2 ** W_OCM_A));
          outstream_d <= parent;
          outstream_enq <= 1;
          state <= 'h00;
          if(index == 1) begin
            root <= parent;
          end
        end
        'h23: begin
          root <= `CMP(parent, new_value)? parent: new_value;
          ocm_write_addr <= index;
          ocm_write_d <= `CMP(parent, new_value)? parent: new_value;
          ocm_write_we <= (index < (2 ** W_OCM_A));
          outstream_d <= `CMP(parent, new_value)? parent: new_value;
          outstream_enq <= 1;
          state <= 'h00;
        end
      endcase
    end
  end

  OnchipRam
  #(
    .W_D(W_D),
    .W_A(W_OCM_A)
    )
  inst_onchipram
  (
   .CLK(CLK),
   .addr0(ocm_read_addr),
   .we0(1'b0),
   .d0(0),
   .q0(ocm_read_q),
   .addr1(ocm_write_addr),
   .we1(ocm_write_we),
   .d1(ocm_write_d),
   .q1()
   );
  
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
   .ALM_FULL(comm_almost_full),
   .Q(comm_q),
   .DEQ(comm_deq),
   .EMPTY(comm_empty)
   );

endmodule

module OnchipRam #
  (
   parameter W_D = 32,
   parameter W_A = 10
   )
  (
   input CLK,
   input [W_A-1:0]  addr0,
   input            we0,
   input [W_D-1:0]  d0,
   output [W_D-1:0] q0,
   input [W_A-1:0]  addr1,
   input            we1,
   input [W_D-1:0]  d1,
   output [W_D-1:0] q1
   );
  reg [W_D-1:0] mem [0:2**W_A-1];
  reg [W_A-1:0] d_addr0;
  reg [W_A-1:0] d_addr1;
  always @(posedge CLK) begin
    d_addr0 <= addr0;
    d_addr1 <= addr1;
    if(we0) begin
      mem[addr0] <= d0;
    end
    if(we1) begin
      mem[addr1] <= d1;
    end
  end
  assign q0 = mem[d_addr0];
  assign q1 = mem[d_addr1];
endmodule
