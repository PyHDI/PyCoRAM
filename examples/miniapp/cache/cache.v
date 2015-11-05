`default_nettype none
`include "pycoram.v"
  
`define CACHE_THREAD_NAME "cache_thread"

`define CACHE_LOG_2(n) (\
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
  
module Cache #
  (
   parameter NUM_WAYS = 1,
   parameter NUM_LINES = 512,
   parameter LINE_SIZE = 16,
   parameter W_D = 32,
   parameter W_A = 27,
   parameter MMAP_FLUSH = 'h10
   )
  (
   input CLK,
   input RST,
   input [W_A-1:0] addr,
   input we,
   input [W_D-1:0] d,
   input re,
   output [W_D-1:0] q,
   output stall
   );

  localparam ADDR_OFFSET = `CACHE_LOG_2( W_D/8 );
  localparam W_INDEX = `CACHE_LOG_2( NUM_LINES );
  localparam W_LOCAL_A = `CACHE_LOG_2( NUM_LINES * LINE_SIZE / (W_D/8) );
  localparam W_TAG = W_A - W_LOCAL_A - ADDR_OFFSET;
  localparam W_STATUS = W_TAG + 3; // valid, dirty, accessed

  localparam CMD_MISS_CLEAN = 1;
  localparam CMD_MISS_DIRTY = 2;
  localparam CMD_FLUSH = 3;

  reg [31:0] comm_d;
  reg comm_enq;
  wire comm_full;
  wire [31:0] comm_q;
  reg comm_deq;
  wire comm_empty;
  
  reg d_re;
  reg d_we;
  reg [W_D-1:0] d_d;
  reg [W_A-1:0] d_addr;

  reg [W_LOCAL_A-1:0] init_addr;
  wire [W_LOCAL_A-1:0] local_addr;
  reg [W_LOCAL_A-1:0] d_local_addr;
  
  wire [W_TAG-1:0] local_tag;
  reg [W_TAG-1:0] d_local_tag;
  
  reg [NUM_WAYS-1:0] replace_way;
  reg [W_LOCAL_A-1:0] replace_addr;
  reg [W_TAG-1:0] replace_tag;
  reg [W_TAG-1:0] next_tag;
  reg replace_status_we;

  wire miss;
  wire write_stall;

  wire [W_D-1:0] q_array [0:NUM_WAYS-1];
  wire [W_TAG-1:0] tag_q_array [0:NUM_WAYS-1];
  wire [NUM_WAYS-1:0] write_stall_array;
  
  wire [NUM_WAYS-1:0] miss_array;
  wire [NUM_WAYS-1:0] valid_array;
  wire [NUM_WAYS-1:0] dirty_array;
  wire [NUM_WAYS-1:0] accessed_array;

  wire [NUM_WAYS-1:0] hit_way;
  wire [NUM_WAYS-1:0] lru_selected;
  reg [NUM_WAYS-1:0] random_cnt;
  
  wire flush_flag;
  reg is_dirty;

  reg filled;
  
  reg [7:0] state;

  function [NUM_WAYS-1:0] way_select;
    input [NUM_WAYS-1:0] miss;
    integer i;
    begin
      way_select = 0;
      for(i=0; i<NUM_WAYS; i=i+1) begin
        if(miss[i] == 0) way_select = i;
      end
    end
  endfunction
  
  function [NUM_WAYS-1:0] lru;
    input [NUM_WAYS-1:0] valid;
    input [NUM_WAYS-1:0] accessed;
    input [NUM_WAYS-1:0] random;
    reg done;
    integer i;
    begin
      if(NUM_WAYS == 1) begin
        lru = 0;
      end else begin
        done = 0;
        for(i=0; i<NUM_WAYS; i=i+1) begin
          if(valid[i] == 0) begin
            lru = i;
            done = 1;
          end
        end
        if(!done) begin
          lru = random;
          for(i=0; i<NUM_WAYS; i=i+1) begin
            if(accessed[i] == 0) begin
              lru = i;
            end
          end
        end
      end
    end
  endfunction

  always @(posedge CLK) begin
    if(RST) begin
      random_cnt <= 0;
    end else begin
      random_cnt <= (random_cnt == NUM_WAYS-1)? 0 : random_cnt + 1;
    end
  end

  assign stall = (state != 'h10) || write_stall || miss;
  assign q = q_array[hit_way];
  
  assign local_addr = addr[W_LOCAL_A-1+ADDR_OFFSET:ADDR_OFFSET];
  assign local_tag = addr[W_A-1:W_A-W_TAG];
  assign flush_flag = (d_addr == MMAP_FLUSH) && d_we;
  assign write_stall = |write_stall_array;
  assign miss = (d_we || d_re) && &miss_array;
  assign hit_way = way_select(miss_array);
  assign lru_selected = lru(valid_array, accessed_array, random_cnt);

  always @(posedge CLK) begin
    if(RST) begin
      init_addr <= 0;
      d_re <= 0;
      d_we <= 0;
      d_d <= 0;
      d_addr <= 0;
      d_local_addr <= 0;      
      d_local_tag <= 0;
      replace_way <= 0;
      replace_addr <= 0;
      replace_tag <= 0;
      replace_status_we <= 0;
      next_tag <= 0;
      is_dirty <= 0;
      filled <= 0;
      state <= 0;
    end else begin
      comm_deq <= 0;
      comm_enq <= 0;
      filled <= 0;
      
      case(state)
        //----------------------------------------------------------------------
        // initialize
        //---------------------------------------------------------------------- 
        'h0: begin
          init_addr <= 0;
          state <= 'h1;
        end
        'h1: begin
          init_addr <= init_addr + 1;
          if(init_addr == NUM_LINES * LINE_SIZE / (W_D/8) -2) begin
            state <= 'h2;
          end
        end
        'h2: begin
          init_addr <= 0;
          state <= 'h10;
        end

        //----------------------------------------------------------------------
        // idle
        //----------------------------------------------------------------------
        'h10: begin
          if(flush_flag) begin
            state <= 'h30;
          end else if(miss) begin 
            replace_way <= lru_selected;
            replace_addr <= d_local_addr;
            replace_tag <= tag_q_array[lru_selected];
            next_tag <= d_local_tag;
            is_dirty <= dirty_array[lru_selected];
            state <= 'h20;
          end else if(write_stall) begin
            d_re <= 0;
            d_we <= 0;
          end else begin
            d_re <= re;
            d_we <= we;
            d_d <= d;
            d_addr <= addr;
            d_local_addr <= local_addr;
            d_local_tag <= local_tag;
          end
        end

        //----------------------------------------------------------------------
        // replace
        //---------------------------------------------------------------------- 
        'h20: begin // miss dirty and clean
          if(!comm_full) begin
            comm_d <= is_dirty? CMD_MISS_DIRTY : CMD_MISS_CLEAN;
            comm_enq <= 1;
            state <= 'h21;
          end
        end
        'h21: begin
          comm_enq <= 0;
          state <= 'h22;
        end
        'h22: begin
          if(!comm_full) begin
            comm_d <= replace_way;
            comm_enq <= 1;
            state <= 'h23;
          end
        end
        'h23: begin
          comm_enq <= 0;
          state <= 'h24;
        end
        'h24: begin
          if(!comm_full) begin
            //comm_d <= { replace_addr[W_LOCAL_A-1:W_LOCAL_A-W_INDEX], {(W_LOCAL_A-W_INDEX){1'b0}} };
            comm_d <= replace_addr >> (W_LOCAL_A-W_INDEX);
            comm_enq <= 1;
            state <= 'h25;
          end
        end
        'h25: begin
          comm_enq <= 0;
          if(is_dirty) begin
            state <= 'h26;
          end else begin
            state <= 'h28;
          end
        end
        'h26: begin
          if(!comm_full) begin
            comm_d <= replace_tag;
            comm_enq <= 1;
            state <= 'h27;
          end
        end
        'h27: begin
          comm_enq <= 0;
          state <= 'h28;
        end
        'h28: begin
          if(!comm_full) begin
            comm_d <= next_tag;
            comm_enq <= 1;
            state <= 'h29;
          end
        end
        'h29: begin
          comm_enq <= 0;
          state <= 'h2a;
        end
        'h2a: begin // wait
          if(!comm_empty) begin
            replace_status_we <= 1;
            replace_addr <= d_local_addr;
            comm_deq <= 1;
            state <= 'h2b;
          end
        end
        'h2b: begin
          replace_status_we <= 0;
          comm_deq <= 0;
          state <= 'h2c;
        end
        'h2c: begin
          filled <= 1;
          state <= 'h10; // done
        end
        //----------------------------------------------------------------------
        // flush
        //---------------------------------------------------------------------- 
        'h30: begin
          d_addr <= 0; // cancel the flush flag
          replace_way <= 0;
          replace_addr <= 0;
          state <= 'h32; // to 'h32
        end
        'h31: begin
          replace_way <= (replace_way == NUM_WAYS - 1)? 0 : replace_way + 1;
          replace_addr <= (replace_way == NUM_WAYS - 1)? replace_addr + 1 : replace_addr;
          if(replace_addr == NUM_LINES-1 && replace_way == NUM_WAYS-1) begin
            state <= 'h10; // done
          end else begin
            state <= 'h32;
          end
        end
        'h32: begin // reqest the tag and info
          state <= 'h33; 
        end
        'h33: begin
          replace_tag <= tag_q_array[replace_way];
          if(valid_array[replace_way]) begin
            state <= 'h34;
          end else begin
            state <= 'h31; // next
          end
        end
        'h34: begin 
          if(!comm_full) begin
            comm_d <= CMD_FLUSH;
            comm_enq <= 1;
            state <= 'h35;
          end
        end
        'h35: begin
          comm_enq <= 0;
          state <= 'h36;
        end
        'h36: begin
          if(!comm_full) begin
            comm_d <= replace_way;
            comm_enq <= 1;
            state <= 'h37;
          end
        end
        'h37: begin
          comm_enq <= 0;
          state <= 'h38;
        end
        'h38: begin
          if(!comm_full) begin
            comm_d <= replace_addr;
            comm_enq <= 1;
            state <= 'h39;
          end
        end
        'h39: begin
          comm_enq <= 0;
          state <= 'h3a;
        end
        'h3a: begin
          if(!comm_full) begin
            comm_d <= replace_tag;
            comm_enq <= 1;
            state <= 'h3b;
          end
        end
        'h3b: begin
          comm_enq <= 0;
          state <= 'h3c;
        end
        'h3c: begin
          if(!comm_empty) begin
            replace_status_we <= 1;
            comm_deq <= 1;
            state <= 'h3d;
          end
        end
        'h3d: begin
          comm_deq <= 0;
          state <= 'h31; // next
        end
      endcase
    end
  end
  
  genvar i;
  generate for(i=0; i<NUM_WAYS; i=i+1) begin: s_way
    wire [W_INDEX-1:0] way_read_index;
    wire [W_INDEX-1:0] way_write_index;
    wire [W_LOCAL_A-1:0] way_addr;
    wire [W_D-1:0] way_d;
    wire [W_D-1:0] way_q;
    wire way_we;
    wire way_write_stall;
    wire [W_TAG-1:0] way_tag_q;
    wire [W_TAG-1:0] way_tag_d;
    wire [2:0] way_info_q;
    wire [2:0] way_info_d;
    wire way_miss;
    wire way_status_we;
    wire way_valid;
    wire way_dirty;
    wire way_accessed;
    assign way_read_index = (state=='h10)? local_addr >> (W_LOCAL_A - W_INDEX):
                            (state>='h20)? replace_addr >> (W_LOCAL_A - W_INDEX):
                            'hx;
    assign way_write_index = (state>='h0 && state<='hf)? init_addr >> (W_LOCAL_A - W_INDEX):
                             (state=='h10)? d_local_addr >> (W_LOCAL_A - W_INDEX):
                             (state>='h20)? replace_addr >> (W_LOCAL_A - W_INDEX):
                             'hx;
    assign way_addr = (state>='h0 && state<='hf)? init_addr:
                      (state=='h10 && d_we)? d_local_addr:
                      (state=='h10 && !d_we)? local_addr:
                      (state>='h20)? replace_addr:
                      'hx;
    assign way_d = d_d;
    assign way_we = (state>=0 && state<='hf)? 0:
                    (state=='h10 && d_we)? !way_miss:
                    0;
    assign way_write_stall = way_we;
    assign way_tag_d = (state>='h0 && state<='hf)? 'hffff:
                       (state=='h10)? way_tag_q:
                       (state>='h30)? 'hffff:
                       (state>='h20)? next_tag:
                       'hx;
    assign way_info_d = (state>=0 && state<='hf)? 3'b000:
                        (state=='h10 && d_we)? {2'b11, !filled}:
                        (state=='h10 && d_re)? (way_info_q | {2'b10, !filled}):
                        (state>='h30)? 3'b000: // flush
                        (state>='h20)? 3'b100:
                        'hx;
    assign way_status_we = (state>=0 && state<='hf)? 1:
                           (state=='h10 && d_we)? !way_miss:
                           (state=='h10 && d_re)? !way_miss:
                           (state>='h20)? replace_status_we && (replace_way == i):
                           0;
    assign way_valid = way_info_q[2];
    assign way_dirty = way_info_q[1];
    assign way_accessed = way_info_q[0];
    assign way_miss = (d_re || d_we) && (!way_valid || (d_local_tag != way_tag_q));

    assign q_array[i] = way_q;
    assign write_stall_array[i] = way_write_stall;
    assign tag_q_array[i] = way_tag_q;
    assign miss_array[i] = way_miss;
    assign valid_array[i] = way_valid;
    assign dirty_array[i] = way_dirty;
    assign accessed_array[i] = way_accessed;
    
    CoramMemory1P # 
      (
       .CORAM_THREAD_NAME(`CACHE_THREAD_NAME),
       .CORAM_ID(0),
       .CORAM_SUB_ID(i),
       .CORAM_ADDR_LEN(W_LOCAL_A),
       .CORAM_DATA_WIDTH(W_D)
       )
    inst_mem
      (
       .CLK(CLK),
       .ADDR(way_addr),
       .D(way_d),
       .WE(way_we),
       .Q(way_q)
       );
    
    CacheStatusRam #
      (
       .ADDR_LEN(W_INDEX),
       .DATA_WIDTH(W_STATUS)
       )
    inst_status
      (
       .CLK0(CLK),
       .ADDR0(way_read_index),
       .D0('hx),
       .WE0(1'b0),
       .Q0({way_info_q, way_tag_q}),
       .CLK1(CLK),
       .ADDR1(way_write_index),
       .D1({way_info_d,  way_tag_d}),
       .WE1(way_status_we),
       .Q1()
       );

    always @(posedge CLK) begin
      if(d_re && !way_miss) $display("WAY[%d] read  addr=%x data=%x", i, way_addr, way_q);
      if(way_we) $display("WAY[%d] write addr=%x data=%x", i, way_addr, way_d);
    end

  end endgenerate

  CoramChannel #
    (
     .CORAM_THREAD_NAME(`CACHE_THREAD_NAME),
     .CORAM_ID(0),
     .CORAM_ADDR_LEN(4),
     .CORAM_DATA_WIDTH(32)
     )
  inst_channel
    (
     .CLK(CLK),
     .RST(RST),
     .D(comm_d),
     .ENQ(comm_enq),
     .FULL(comm_full),
     .Q(comm_q),
     .DEQ(comm_deq),
     .EMPTY(comm_empty)
     );
  
endmodule  

module CacheStatusRam(CLK0, ADDR0, D0, WE0, Q0, 
                      CLK1, ADDR1, D1, WE1, Q1);
  parameter ADDR_LEN = 10;
  parameter DATA_WIDTH = 32;
  localparam LEN = 2 ** ADDR_LEN;
  input            CLK0;
  input  [ADDR_LEN-1:0] ADDR0;
  input  [DATA_WIDTH-1:0] D0;
  input            WE0;
  output [DATA_WIDTH-1:0] Q0;
  input            CLK1;
  input  [ADDR_LEN-1:0] ADDR1;
  input  [DATA_WIDTH-1:0] D1;
  input            WE1;
  output [DATA_WIDTH-1:0] Q1;
  
  reg [ADDR_LEN-1:0] d_ADDR0;
  reg [ADDR_LEN-1:0] d_ADDR1;
  reg [DATA_WIDTH-1:0] mem [0:LEN-1];
  
  always @(posedge CLK0) begin
    if(WE0) mem[ADDR0] <= D0;
    d_ADDR0 <= ADDR0;
  end
  always @(posedge CLK1) begin
    if(WE1) mem[ADDR1] <= D1;
    d_ADDR1 <= ADDR1;
  end
  assign Q0 = mem[d_ADDR0];
  assign Q1 = mem[d_ADDR1];
endmodule

