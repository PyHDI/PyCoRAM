`include "pycoram.v"

module st #
  (
   parameter W_D = 32
   )
  (
   input CLK,
   input RST,
   input exec_start,
   input [31:0] mesh_size,
   input [31:0] num_iter,
   output exec_done,
   output [31:0] check_sum
   );

  st_init
  inst_st_init
    (
     .CLK(CLK),
     .RST(RST),
     .exec_start(exec_start),
     .mesh_size(mesh_size),
     .num_iter(num_iter)
     );

  st_main
  inst_st_main
    (
     .CLK(CLK),
     .RST(RST),
     .exec_done(exec_done),
     .sum(check_sum)
     );

endmodule
  
//------------------------------------------------------------------------------
module st_init #
  (
   parameter W_D = 32,
   parameter W_INIT_A = 3, // 8
   parameter W_COMM_A = 4, // 16
   parameter LOADER_SIZE = 256 * 1024,
   parameter SKIP_SIZE = 256 * 1024
   )
  (
   input CLK,
   input RST,
   input exec_start,
   input [W_D-1:0] mesh_size,
   input [W_D-1:0] num_iter
   );

  reg [7:0] state;

  reg [W_D-1:0] comm_d;
  reg comm_enq;
  wire comm_full;
  wire [W_D-1:0] comm_q;
  reg comm_deq;
  wire comm_empty;

  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      comm_enq <= 0;
      comm_deq <= 0;
      comm_d <= 0;
    end else begin
      comm_enq <= 0;
      comm_deq <= 0;

      case(state)
        'h0: begin
          if(exec_start) begin
            comm_enq <= 1;
            comm_d <= mesh_size;
            state <= 'h1;
          end
        end
        'h1: begin
          comm_enq <= 0;
          state <= 'h2;
        end
        'h2: begin
          comm_enq <= 1;
          comm_d <= num_iter;
          state <= 'h3;
        end
        'h3: begin
          comm_enq <= 0;
          state <= 'h4;
        end
        'h4: begin
          if(!exec_start) begin
            state <= 'h0; // done
            $display("mesh_size=%d", mesh_size);
            $display("num_iter=%d", num_iter);
          end
        end
      endcase
    end
  end

  reg [W_INIT_A-1:0] zero_addr;
  
  always @(posedge CLK) begin
    if(RST) begin
      zero_addr <= 0;
    end else begin
      zero_addr <= zero_addr + 1;
    end
  end
  
  CoramMemory1P # 
    (
     .CORAM_THREAD_NAME("cthread_st"),
     .CORAM_ID(101),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_INIT_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_mem_zero
    (
     .CLK(CLK),
     .ADDR(zero_addr),
     .D(0),
     .WE(1'b1),
     .Q()
     );
  
  CoramChannel #
    (
     .CORAM_THREAD_NAME("cthread_st"),
     .CORAM_ID(100),
     .CORAM_ADDR_LEN(W_COMM_A),
     .CORAM_DATA_WIDTH(W_D)
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

//------------------------------------------------------------------------------
module st_main #
  (
   parameter W_D = 32,
   parameter W_A = 9, // 512 (= Max size of Matrix) 
   parameter W_COMM_A = 4 // 16
   )
  (
   input CLK,
   input RST,
   output reg exec_done,
   output reg [W_D-1:0] sum
   );

  localparam PIPELINE_DEPTH = W_D + 3 + 1 + 3;
  
  reg [W_A-1:0] mem_addr;
  wire [W_D-1:0] mem_0_q;
  wire [W_D-1:0] mem_1_q;
  wire [W_D-1:0] mem_2_q;
  wire [W_D-1:0] mem_3_q;
  
  reg [W_A-1:0] next_mem_d_addr;
  reg [W_A-1:0] mem_d_addr;
  reg [W_D-1:0] mem_d_d;
  reg mem_d0_we;
  reg mem_d1_we;

  reg [W_D-1:0] comm_d;
  wire [W_D-1:0] comm_q;
  reg comm_enq;
  reg comm_deq;
  wire comm_empty;
  wire comm_full;

  reg [7:0] state;
  
  reg [W_D-1:0] read_count;
  reg [W_D-1:0] mesh_size;
  
  //reg [W_D-1:0] comp_d;
  reg [W_D-1:0] comp_d0;
  reg [W_D-1:0] comp_d1;
  reg [W_D-1:0] comp_d2;
  reg [W_D-1:0] comp_d3;
  reg [3:0] comp_inv_active_map;
  reg comp_enable;
  reg [7:0] comp_wait;

  reg init_sum;
  reg calc_sum;
  reg hot_spot;
  reg [3:0] inv_read_active_map;
  reg [1:0] write_active_map;
  
/* -----\/----- EXCLUDED -----\/-----
  function [W_D-1:0] add;
    input [3:0] inv_active_map;
    input [W_D-1:0] in0;
    input [W_D-1:0] in1;
    input [W_D-1:0] in2;
    input [W_D-1:0] in3;
    reg [3:0] active_map;
    reg [W_D-1:0] t0;
    reg [W_D-1:0] t1;
    reg [W_D-1:0] t2;
    reg [W_D-1:0] t3;
    begin
      active_map = ~inv_active_map;
      t0 = active_map[0]==0? 0 : in0;
      t1 = active_map[1]==0? 0 : in1;
      t2 = active_map[2]==0? 0 : in2;
      t3 = active_map[3]==0? 0 : in3;
      add = t0 + t1 + t2 + t3;
    end
  endfunction
 -----/\----- EXCLUDED -----/\----- */
  
  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      comm_enq <= 0;
      comm_deq <= 0;
      comm_d <= 0;
      sum <= 0;
      init_sum <= 0;
      calc_sum <= 0;
      hot_spot <= 0;
      inv_read_active_map <= 0;
      write_active_map <= 0;
      mesh_size <= 0;
      read_count <= 0;
      mem_addr <= 0;
      comp_enable <= 0;
      comp_d0 <= 0;
      comp_d1 <= 0;
      comp_d2 <= 0;
      comp_d3 <= 0;
      comp_inv_active_map <= 0;
      comp_wait <= 0;
      exec_done <= 0;
    end else begin
      // default value
      comm_enq <= 0;
      comm_deq <= 0;
      comp_enable <= 0;
      case(state)
        'h0: begin
          if(!comm_empty) begin
            comm_deq <= 1;
            state <= 'h1;
          end
        end
        'h1: begin
          comm_deq <= 0;
          state <= 'h2;
        end
        'h2: begin
          sum <= 0;
          init_sum <= 0;
          calc_sum <= 0;
          hot_spot <= 0;
          inv_read_active_map <= 0;
          write_active_map <= 0;
          mesh_size <= comm_q;
          state <= 'h3;
          $display("start execution");
          $display("mesh_size=%d", comm_q);
        end
        // computation start
        'h3: begin
          if(!comm_empty) begin
            comm_deq <= 1;
            state <= 'h4;
          end
        end
        'h4: begin
          comm_deq <= 0;
          state <= 'h5;
        end
        'h5: begin
          {init_sum, calc_sum, hot_spot, write_active_map, inv_read_active_map} <= comm_q;
          mem_addr <= 0;
          read_count <= 0;
          if(comm_q == 0) begin // done
            //state <= 'h0;
            state <= 'hd;
          end else begin
            state <= 'h6;
          end
        end
        'h6: begin
          if(init_sum) begin
            sum <= 0;
          end
          mem_addr <= mem_addr + 1;
          state <= 'h7;
        end
        'h7: begin
          mem_addr <= mem_addr + 1;
          read_count <= read_count + 1;
          comp_enable <= !calc_sum;
          //comp_d <= add(inv_read_active_map, mem_0_q, mem_1_q, mem_2_q, mem_3_q);
          if(!inv_read_active_map[0] && mem_0_q === 'hx) $finish;
          if(!inv_read_active_map[1] && mem_1_q === 'hx) $finish;
          if(!inv_read_active_map[2] && mem_2_q === 'hx) $finish;
          if(!inv_read_active_map[3] && mem_3_q === 'hx) $finish;
          comp_d0 <= mem_0_q;
          comp_d1 <= mem_1_q;
          comp_d2 <= mem_2_q;
          comp_d3 <= mem_3_q;
          comp_inv_active_map <= inv_read_active_map;
          sum <= sum + mem_0_q;
          if(read_count + 3 >= mesh_size) begin
            state <= 'h8;
          end
        end
        'h8: begin
          read_count <= read_count + 1;
          comp_enable <= !calc_sum;
          //comp_d <= add(inv_read_active_map, mem_0_q, mem_1_q, mem_2_q, mem_3_q);
          if(!inv_read_active_map[0] && mem_0_q === 'hx) $finish;
          if(!inv_read_active_map[1] && mem_1_q === 'hx) $finish;
          if(!inv_read_active_map[2] && mem_2_q === 'hx) $finish;
          if(!inv_read_active_map[3] && mem_3_q === 'hx) $finish;
          comp_d0 <= mem_0_q;
          comp_d1 <= mem_1_q;
          comp_d2 <= mem_2_q;
          comp_d3 <= mem_3_q;
          comp_inv_active_map <= inv_read_active_map;
          sum <= sum + mem_0_q;
          state <= 'h9;
        end
        'h9: begin
          read_count <= read_count + 1;
          comp_enable <= !calc_sum;
          //comp_d <= add(inv_read_active_map, mem_0_q, mem_1_q, mem_2_q, mem_3_q);
          if(!inv_read_active_map[0] && mem_0_q === 'hx) $finish;
          if(!inv_read_active_map[1] && mem_1_q === 'hx) $finish;
          if(!inv_read_active_map[2] && mem_2_q === 'hx) $finish;
          if(!inv_read_active_map[3] && mem_3_q === 'hx) $finish;
          comp_d0 <= mem_0_q;
          comp_d1 <= mem_1_q;
          comp_d2 <= mem_2_q;
          comp_d3 <= mem_3_q;
          comp_inv_active_map <= inv_read_active_map;
          sum <= sum + mem_0_q;
          comp_wait <= 0;
          state <= 'ha;
        end
        'ha: begin
          comp_wait <= comp_wait + 1;
          if(comp_wait == PIPELINE_DEPTH+2) begin
            state <= 'hb;
          end else if(calc_sum) begin
            state <= 'hb;
          end
        end
        'hb: begin
          comm_d <= sum;
          if(!comm_full) begin
            comm_enq <= 1;
            state <= 'hc;
          end
        end
        'hc: begin
          comm_enq <= 0;
          state <= 'h3;
        end
        'hd: begin
          // done
          exec_done <= 1;
        end
      endcase
    end
  end

  // execution pipeline
  wire comp_enable_local;
  wire [W_D-1:0] comp_rslt;
  wire comp_valid;
  assign comp_enable_local = comp_enable;

  AddDiv #
   (
    .W_D(W_D)
    ) 
  inst_adddiv
    (
     .CLK(CLK),
     .RST(RST),
     //.in(comp_d),
     .in0(comp_d0),
     .in1(comp_d1),
     .in2(comp_d2),
     .in3(comp_d3),
     .inv_active_map(comp_inv_active_map),
     .enable(comp_enable_local),
     .rslt(comp_rslt),
     .valid(comp_valid)
    );

  always @(posedge CLK) begin
    if(RST) begin
      mem_d0_we <= 0;
      mem_d1_we <= 0;
      mem_d_addr <= 0;
      mem_d_d <= 0;
    end else begin
      if(comp_valid && comp_rslt === 'hx) $finish;
      mem_d0_we <= 0;
      mem_d1_we <= 0;
      if(state == 'h3) begin
        mem_d_addr <= 0; // write to [1] to [(mesh_size -2)]
      end else if(comp_valid) begin
        if(mem_d_addr == 0 && hot_spot) begin
          mem_d_d <= 'h9999999;
        end else begin
          mem_d_d <= comp_rslt;
        end
        mem_d0_we <= write_active_map[0];
        mem_d1_we <= write_active_map[1];
        mem_d_addr <= mem_d_addr + 1;
      end
    end
  end
  
  CoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_st"),
     .CORAM_ID(0),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_mem_0
   (
    .CLK(CLK),
    .ADDR(mem_addr),
    .D('hx),
    .WE(1'b0),
    .Q(mem_0_q)
    );

  CoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_st"),
     .CORAM_ID(1),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_mem_1
   (
    .CLK(CLK),
    .ADDR(mem_addr),
    .D('hx),
    .WE(1'b0),
    .Q(mem_1_q)
    );

  CoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_st"),
     .CORAM_ID(2),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_mem_2
   (
    .CLK(CLK),
    .ADDR(mem_addr),
    .D('hx),
    .WE(1'b0),
    .Q(mem_2_q)
    );

  CoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_st"),
     .CORAM_ID(3),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_mem_3
   (
    .CLK(CLK),
    .ADDR(mem_addr),
    .D('hx),
    .WE(1'b0),
    .Q(mem_3_q)
    );

  CoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_st"),
     .CORAM_ID(4),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_mem_d0
   (
    .CLK(CLK),
    .ADDR(mem_d_addr),
    .D(mem_d_d),
    .WE(mem_d0_we),
    .Q()
    );

  CoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_st"),
     .CORAM_ID(5),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_mem_d1
   (
    .CLK(CLK),
    .ADDR(mem_d_addr),
    .D(mem_d_d),
    .WE(mem_d1_we),
    .Q()
    );

  CoramChannel #
    (
     .CORAM_THREAD_NAME("cthread_st"),
     .CORAM_ID(0),
     .CORAM_ADDR_LEN(W_COMM_A),
     .CORAM_DATA_WIDTH(W_D)
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

//------------------------------------------------------------------------------
module AddDiv #
  (
   parameter W_D = 32,
   parameter NUM_LINES = 3,
   parameter NUM_POINTS = 9 // divide value
   )
  (
   input CLK,
   input RST,
   //input [W_D-1:0] in,
   input [W_D-1:0] in0,
   input [W_D-1:0] in1,
   input [W_D-1:0] in2,
   input [W_D-1:0] in3,
   input [3:0] inv_active_map,
   input enable,
   output [W_D-1:0] rslt,
   output valid
   );

  wire [W_D-1:0] add_rslt;
  wire add_valid;
  
  wire [W_D-1:0] div_in;
  wire div_en;

  Adder4 #
    (
     .W_D(W_D)
     )
  inst_addr4
    (
     .CLK(CLK),
     .RST(RST),
     .in0(in0),
     .in1(in1),
     .in2(in2),
     .in3(in3),
     .inv_active_map(inv_active_map),
     .enable(enable),
     .rslt(add_rslt),
     .valid(add_valid)
     );

  genvar i;
  generate for(i=0; i<NUM_LINES; i=i+1) begin: s_point
    reg [W_D-1:0] sum;
    reg svalid;
    if(i==0) begin
      always @(posedge CLK) begin
        if(RST) begin
          svalid <= 0;
        end else begin
          svalid <= add_valid;
        end
      end
      always @(posedge CLK) begin
        if(add_valid) begin
          sum <= add_rslt;
        end else begin
          sum <= 0;
        end
      end
    end else begin
      always @(posedge CLK) begin
        if(RST) begin
          svalid <= 0;
        end else begin
          svalid <= s_point[i-1].svalid && add_valid;
        end
      end
      always @(posedge CLK) begin
        if(add_valid) begin
          sum <= s_point[i-1].sum + add_rslt;
        end
      end
    end
  end endgenerate

  assign div_en = s_point[NUM_LINES-1].svalid;
  assign div_in = s_point[NUM_LINES-1].sum;

  Divider #
    (
     .W_D(W_D)
     )
  inst_divider
    (
     .CLK(CLK),
     .RST(RST),
     .in_a(div_in),
     .in_b(NUM_POINTS),
     .enable(div_en),
     .rslt(rslt),
     .mod(),
     .valid(valid)
     );
  
endmodule

//------------------------------------------------------------------------------
module Divider #
  (
   parameter W_D = 32
   )
  (
   input CLK,
   input RST,
   input [W_D-1:0] in_a,
   input [W_D-1:0] in_b,
   input enable,
   output reg [W_D-1:0] rslt,
   output reg [W_D-1:0] mod,
   output reg valid
   );

  localparam DEPTH = W_D + 1;
  
  function getsign;
    input [W_D-1:0] in;
    getsign = in[W_D-1]; //0: positive, 1: negative
  endfunction

  function is_positive;
    input [W_D-1:0] in;
    is_positive = (getsign(in) == 0);
  endfunction
    
  function [W_D-1:0] complement2;
    input [W_D-1:0] in;
    complement2 = ~in + {{(W_D-1){1'b0}}, 1'b1};
  endfunction
    
  function [W_D*2-1:0] complement2_2x;
    input [W_D*2-1:0] in;
    complement2_2x = ~in + {{(W_D*2-1){1'b0}}, 1'b1};
  endfunction
    
  function [W_D-1:0] absolute;
    input [W_D-1:0] in;
    begin
      if(getsign(in)) //Negative
        absolute = complement2(in);
      else //Positive
        absolute = in;
    end
  endfunction

  wire [W_D-1:0] abs_in_a;
  wire [W_D-1:0] abs_in_b;
  assign abs_in_a = absolute(in_a);
  assign abs_in_b = absolute(in_b);

  genvar d;
  generate 
    for(d=0; d<DEPTH; d=d+1) begin: s_depth
      reg stage_valid;
      reg in_a_positive;
      reg in_b_positive;
      reg [W_D*2-1:0] dividend;
      reg [W_D*2-1:0] divisor;
      reg [W_D*2-1:0] stage_rslt;

      wire [W_D*2-1:0] sub_value;
      wire is_large;
      assign sub_value = dividend - divisor;
      assign is_large = !sub_value[W_D*2-1];
      
      if(d == 0) begin 
        always @(posedge CLK) begin
          if(RST) begin
            stage_valid   <= 0;
            in_a_positive <= 0;
            in_b_positive <= 0;          
          end else begin
            stage_valid   <= enable;
            in_a_positive <= is_positive(in_a);
            in_b_positive <= is_positive(in_b);
          end
        end
      end else begin
        always @(posedge CLK) begin
          if(RST) begin
            stage_valid   <= 0;
            in_a_positive <= 0;
            in_b_positive <= 0;
          end else begin
            stage_valid   <= s_depth[d-1].stage_valid;
            in_a_positive <= s_depth[d-1].in_a_positive;
            in_b_positive <= s_depth[d-1].in_b_positive;
          end
        end
      end
      
      if(d==0) begin
        always @(posedge CLK) begin
          dividend <= abs_in_a;
          divisor <= abs_in_b << (W_D-1);
          stage_rslt <= 0;
        end
      end else begin
        always @(posedge CLK) begin
          dividend <= s_depth[d-1].is_large? s_depth[d-1].sub_value : s_depth[d-1].dividend;
          divisor <= s_depth[d-1].divisor >> 1;
          stage_rslt <= {s_depth[d-1].stage_rslt, s_depth[d-1].is_large};
        end
      end
    end
  endgenerate
  
  always @(posedge CLK) begin
    if(RST) begin
      valid <= 0;
    end else begin
      valid <= s_depth[DEPTH-1].stage_valid;
    end
  end
    
  always @(posedge CLK) begin
    rslt <= (s_depth[DEPTH-1].in_a_positive && s_depth[DEPTH-1].in_b_positive)?
            s_depth[DEPTH-1].stage_rslt:
            (!s_depth[DEPTH-1].in_a_positive && s_depth[DEPTH-1].in_b_positive)?
            complement2_2x(s_depth[DEPTH-1].stage_rslt):
            (s_depth[DEPTH-1].in_a_positive && !s_depth[DEPTH-1].in_b_positive)?
            complement2_2x(s_depth[DEPTH-1].stage_rslt):
            (!s_depth[DEPTH-1].in_a_positive && !s_depth[DEPTH-1].in_b_positive)?
            s_depth[DEPTH-1].stage_rslt:
            'hx;
    mod  <= (s_depth[DEPTH-1].in_a_positive && s_depth[DEPTH-1].in_b_positive)?
            s_depth[DEPTH-1].dividend[W_D-1:0]:
            (!s_depth[DEPTH-1].in_a_positive && s_depth[DEPTH-1].in_b_positive)?
            complement2_2x(s_depth[DEPTH-1].dividend[W_D-1:0]):
            (s_depth[DEPTH-1].in_a_positive && !s_depth[DEPTH-1].in_b_positive)?
            s_depth[DEPTH-1].dividend[W_D-1:0]:            
            (!s_depth[DEPTH-1].in_a_positive && !s_depth[DEPTH-1].in_b_positive)?
            complement2_2x(s_depth[DEPTH-1].dividend[W_D-1:0]):
            'hx;
  end
endmodule

module Adder4 #
  (
   parameter W_D = 32
   )
  (
   input CLK,
   input RST,
   input [W_D-1:0] in0,
   input [W_D-1:0] in1,
   input [W_D-1:0] in2,
   input [W_D-1:0] in3,
   input [3:0] inv_active_map,
   input enable,
   output reg [W_D-1:0] rslt,
   output reg valid
   );

  wire [W_D-1:0] t0;
  wire [W_D-1:0] t1;
  wire [W_D-1:0] t2;
  wire [W_D-1:0] t3;
  
  reg [W_D-1:0] r0;
  reg [W_D-1:0] r1;
  reg [W_D-1:0] r2;
  reg [W_D-1:0] r3;
  
  reg [W_D-1:0] sum_0_1;
  reg [W_D-1:0] sum_2_3;
  reg d_enable;
  reg dd_enable;

  assign t0 = inv_active_map[0]? 0 : in0;
  assign t1 = inv_active_map[1]? 0 : in1;
  assign t2 = inv_active_map[2]? 0 : in2;
  assign t3 = inv_active_map[3]? 0 : in3;
  
  always @(posedge CLK) begin
    if(RST) begin
      d_enable <= 0;
      dd_enable <= 0;
      valid <= 0;
    end else begin
      d_enable <= enable;
      dd_enable <= d_enable;
      valid <= dd_enable;
    end
  end

  always @(posedge CLK) begin
    r0 <= t0;
    r1 <= t1;
    r2 <= t2;
    r3 <= t3;
    sum_0_1 <= r0 + r1;
    sum_2_3 <= r2 + r3;
    rslt <= sum_0_1 + sum_2_3;
  end
  
endmodule

