`include "pycoram.v"

module mm #
  (
   parameter W_D = 32
   )
  (
   input CLK,
   input RST,
   input exec_start,
   input [31:0] matrix_size,
   output exec_done,
   output [31:0] check_sum
   );

  mm_init
  inst_mm_init
    (
     .CLK(CLK),
     .RST(RST),
     .exec_start(exec_start),
     .matrix_size(matrix_size)
     );

  mm_main
  inst_mm_main
    (
     .CLK(CLK),
     .RST(RST),
     .exec_done(exec_done),
     .check_sum(check_sum)
     );

endmodule
  
//------------------------------------------------------------------------------
module mm_init #
  (
   parameter W_D = 32,
   //parameter W_INIT_A = 7, // 128
   parameter W_INIT_A = 5, // 32
   parameter W_COMM_A = 4, // 16
   parameter LOADER_SIZE = 256 * 1024
   )
  (
   input CLK,
   input RST,
   input exec_start,
   input [W_D-1:0] matrix_size
   );

  reg [7:0] state;
  reg [W_INIT_A-1:0] mem_a_addr;
  reg [W_INIT_A-1:0] mem_b_addr;
  reg [W_INIT_A+1-1:0] mem_c_addr;
  reg [W_D-1:0] mem_a_d;
  reg [W_D-1:0] mem_b_d;
  wire [W_D-1:0] mem_c_q;
  reg mem_a_we;
  reg mem_b_we;

  reg [W_D-1:0] comm_d;
  reg comm_enq;
  wire comm_full;
  wire [W_D-1:0] comm_q;
  reg comm_deq;
  wire comm_empty;

  reg [W_D-1:0] total_count;
  
  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      comm_enq <= 0;
      comm_deq <= 0;
      comm_d <= 0;
      mem_a_addr <= 2**W_INIT_A-1;
      mem_b_addr <= 2**W_INIT_A-1;
      mem_c_addr <= 0;
      mem_a_d <= 0;
      mem_b_d <= 0;
      mem_a_we <= 0;
      mem_b_we <= 0;
      total_count <= 0;
    end else begin
      mem_a_we <= 0;
      mem_b_we <= 0;
      comm_enq <= 0;
      comm_deq <= 0;
      case(state)
        'h0: begin
          if(exec_start) begin
            comm_enq <= 1;
            comm_d <= matrix_size;
            state <= 'h1;
          end
        end
        'h1: begin
          total_count <= 0;
          comm_enq <= 0;
          state <= 'h2;
        end
        'h2: begin
          if(!comm_empty) begin
            comm_deq <= 1;
            mem_c_addr <= 0;
            total_count <= total_count + 1;
            state <= 'h3;
          end
        end
        'h3: begin
          mem_a_addr <= 2**W_INIT_A-1;
          mem_b_addr <= 2**W_INIT_A-1;
          mem_c_addr <= mem_c_addr + 1;
          total_count <= total_count + 1;
          state <= 'h4;
        end
        'h4: begin
          mem_c_addr <= mem_c_addr + 1;
          total_count <= total_count + 1;
          mem_a_d <= mem_c_q;
          mem_b_d <= mem_c_q;
          if(mem_c_addr[0] == 1) begin
            mem_a_addr <= mem_a_addr + 1;
            mem_a_we <= 1;
          end else begin
            mem_b_addr <= mem_b_addr + 1;
            mem_b_we <= 1;
          end
          if(mem_c_addr == 2**(W_INIT_A+1) -2) begin
            state <= 'h5;
          end
        end
        'h5: begin
          mem_a_d <= mem_c_q;
          mem_a_addr <= mem_a_addr + 1;
          mem_a_we <= 1;
          state <= 'h6;
        end
        'h6: begin
          mem_b_d <= mem_c_q;
          mem_b_addr <= mem_b_addr + 1;
          mem_b_we <= 1;
          state <= 'h7;
        end
        'h7: begin
          comm_d <= matrix_size;
          comm_enq <= 1;
          state <= 'h8;
        end
        'h8: begin
          comm_enq <= 0;
          if(total_count < LOADER_SIZE/4) begin
            state <= 'h2;
          end else begin
            state <= 'h0;
          end
        end
      endcase
    end
  end
  
  CoramMemory1P # 
    (
     .CORAM_THREAD_NAME("cthread_mm"),
     .CORAM_ID(100),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_INIT_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_mem_a
    (
     .CLK(CLK),
     .ADDR(mem_a_addr),
     .D(mem_a_d),
     .WE(mem_a_we),
     .Q()
     );
  
  CoramMemory1P # 
    (
     .CORAM_THREAD_NAME("cthread_mm"),
     .CORAM_ID(101),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_INIT_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_mem_b
    (
     .CLK(CLK),
     .ADDR(mem_b_addr),
     .D(mem_b_d),
     .WE(mem_b_we),
     .Q()
     );
  
  CoramMemory1P # 
    (
     .CORAM_THREAD_NAME("cthread_mm"),
     .CORAM_ID(102),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_INIT_A+1),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_mem_c
    (
     .CLK(CLK),
     .ADDR(mem_c_addr),
     .D(),
     .WE(1'b0),
     .Q(mem_c_q)
     );
  
  CoramChannel #
    (
     .CORAM_THREAD_NAME("cthread_mm"),
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
module mm_main #
  (
   parameter W_D = 32,
   parameter W_MEM_A_A = 9, // Max Matix Size = 512
   //parameter W_MEM_B_A = 8, // 256
   parameter W_MEM_B_A = 7, // 128
   parameter W_MEM_C_A = 9, // Max Matix Size = 512
   parameter W_COMM_A = 4 // 16
   )
  (
   input CLK,
   input RST,
   output reg exec_done,
   output reg [W_D-1:0] check_sum
   );
  
  localparam MULTIPLIER_DEPTH = 6;

  reg [W_MEM_A_A-1:0] mem_a_addr;
  reg [W_MEM_A_A-1:0] next_mem_a_addr;
  reg [W_MEM_B_A-1:0] mem_b_addr;
  wire [W_D-1:0] mem_a_q;
  wire [W_D-1:0] mem_b_q;
  
  reg [W_MEM_C_A-1:0] mem_c_addr;
  reg [W_MEM_C_A-1:0] next_mem_c_addr;
  reg [W_D-1:0] mem_c_d;
  reg mem_c_we;

  reg [W_D-1:0] comm_d;
  wire [W_D-1:0] comm_q;
  reg comm_enq;
  reg comm_deq;
  wire comm_empty;
  wire comm_full;

  reg [7:0] state;

  reg page;
  
  reg [W_D-1:0] computation_size;
  reg [W_D-1:0] comp_count;
  reg [W_D-1:0] matrix_size;
  reg [W_D-1:0] read_count;
  
  reg [W_D-1:0] sum;
  
  reg mult_enable;
  reg [W_D-1:0] mult_a_d_all;
  reg [W_D-1:0] mult_b_d_all;
  reg [7:0] mult_wait;

  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      comm_d <= 0;
      comm_enq <= 0;
      comm_deq <= 0;
      page <= 0;
      next_mem_a_addr <= 0;
      mem_a_addr <= 0;
      mem_b_addr <= 0;
      read_count <= 0;
      matrix_size <= 0;
      computation_size <= 0;
      mult_enable <= 0;
      mult_a_d_all <= 0;
      mult_b_d_all <= 0;
      mult_wait <= 0;
      exec_done <= 0;
    end else begin
      // default value
      comm_enq <= 0;
      comm_deq <= 0;
      mult_enable <= 0;
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
          matrix_size <= comm_q;
          next_mem_a_addr <= 0;
          page <= 0;
          state <= 'h3;
          $display("start execution");
          $display("matrix_size=%d", comm_q);
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
          computation_size <= comm_q;
          next_mem_a_addr <= (next_mem_a_addr == matrix_size -1)? 0 : next_mem_a_addr + 1;
          mem_a_addr <= next_mem_a_addr;
          mem_b_addr <= (page == 1'b0)? 0 : 2 ** (W_MEM_B_A-1);
          read_count <= 0;
          if(comm_q == 0) begin // done
            //state <= 'h0;
            state <= 'h10;
          end else begin
            state <= 'h6;
          end
        end
        'h6: begin
          next_mem_a_addr <= (next_mem_a_addr == matrix_size -1)? 0 : next_mem_a_addr + 1;
          mem_a_addr <= next_mem_a_addr;
          mem_b_addr <= mem_b_addr + 1;
          state <= 'h7;
        end
        'h7: begin
          next_mem_a_addr <= (next_mem_a_addr == matrix_size -1)? 0 : next_mem_a_addr + 1;
          mem_a_addr <= next_mem_a_addr;
          mem_b_addr <= mem_b_addr + 1;
          read_count <= read_count + 1;
          mult_enable <= 1;          
          mult_a_d_all <= mem_a_q;
          mult_b_d_all <= mem_b_q;
          $display("a=%x, b=%x", mem_a_q, mem_b_q);
          if(read_count + 3 >= computation_size) begin
            state <= 'h8;
          end
        end
        'h8: begin
          read_count <= read_count + 1;
          mult_enable <= 1;          
          mult_a_d_all <= mem_a_q;
          mult_b_d_all <= mem_b_q;
          $display("a=%x, b=%x", mem_a_q, mem_b_q);
          state <= 'h9;
        end
        'h9: begin
          read_count <= read_count + 1;
          mult_enable <= 1;          
          mult_a_d_all <= mem_a_q;
          mult_b_d_all <= mem_b_q;
          $display("a=%x, b=%x", mem_a_q, mem_b_q);
          mult_wait <= 0;
          state <= 'ha;
        end
        'ha: begin
          mult_wait <= mult_wait + 1;
          if(mult_wait == MULTIPLIER_DEPTH+2) begin
            state <= 'hb;
          end
        end
        'hb: begin
          $display("check_sum=%x", check_sum);
          comm_d <= check_sum;
          if(!comm_full) begin
            comm_enq <= 1;
            state <= 'hc;
          end
        end
        'hc: begin
          page <= !page;
          comm_enq <= 0;
          state <= 'h3;
        end
        'h10: begin
          // done
          exec_done <= 1;
        end
      endcase
    end
  end

  // execution pipeline
  wire mult_enable_local;
  wire [W_D-1:0] mult_a_d;
  wire [W_D-1:0] mult_b_d;
  wire [W_D*2-1:0] mult_rslt;
  wire mult_valid;
    
  assign mult_enable_local = mult_enable && (read_count < computation_size + 1);
  assign mult_a_d = mult_a_d_all;
  assign mult_b_d = mult_b_d_all;
    
  Multiplier #
   (
    .W_D(W_D)
    )
  inst_multiplier
   (
    .CLK(CLK),
    .RST(RST),
    .in_a(mult_a_d),
    .in_b(mult_b_d),
    .enable(mult_enable_local),
    .rslt(mult_rslt),
    .valid(mult_valid)
    );

  always @(posedge CLK) begin
    if(RST) begin
      mem_c_addr <= 0;
      mem_c_we <= 0;
      mem_c_d <= 0;
      next_mem_c_addr <= 0;
      sum <= 0;
      check_sum <= 0;
      comp_count <= 0;
    end else begin
      // default value
      mem_c_we <= 0;
      if(state == 'h2) begin
        next_mem_c_addr <= 0;
        sum <= 0;
        check_sum <= 0;
        comp_count <= 0;
      end else if(mult_valid) begin
        if(comp_count < matrix_size - 1) begin
          sum <= sum + mult_rslt[W_D-1:0];
          comp_count <= comp_count + 1;
        end else begin // write to BRAM
          mem_c_we <= 1;
          mem_c_addr <= next_mem_c_addr;
          mem_c_d <= sum + mult_rslt[W_D-1:0];
          check_sum <= check_sum + (sum + mult_rslt[W_D-1:0]);
          $display("rslt=%x", sum + mult_rslt[W_D-1:0]);
          sum <= 0;
          comp_count <= 0;
          next_mem_c_addr <= (next_mem_c_addr == matrix_size -1)? 0 : next_mem_c_addr + 1;
        end
      end
    end
  end
  
  CoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_mm"),
     .CORAM_ID(0),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_MEM_A_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_mem_a
   (
    .CLK(CLK),
    .ADDR(mem_a_addr),
    .D('hx),
    .WE(1'b0),
    .Q(mem_a_q)
    );

  CoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_mm"),
     .CORAM_ID(1),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_MEM_B_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_mem_b
   (
    .CLK(CLK),
    .ADDR(mem_b_addr),
    .D('hx),
    .WE(1'b0),
    .Q(mem_b_q)
    );
  
  CoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_mm"),
     .CORAM_ID(2),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_MEM_C_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_mem_c
   (
    .CLK(CLK),
    .ADDR(mem_c_addr),
    .D(mem_c_d),
    .WE(mem_c_we),
    .Q()
    );

  CoramChannel #
    (
     .CORAM_THREAD_NAME("cthread_mm"),
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
/* -----\/----- EXCLUDED -----\/-----
module Multiplier #
  (
   parameter W_D = 32,
   parameter DEPTH = 6 // log(W_D, 2) + 1
   )
  (
   input CLK,
   input RST,
   input [W_D-1:0] in_a,
   input [W_D-1:0] in_b,
   input enable,
   output reg [W_D*2-1:0] rslt,
   output reg valid
   );

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

  genvar d, i;
  generate 
    for(d=0; d<DEPTH; d=d+1) begin: s_depth
      reg stage_valid;
      reg in_a_positive;
      reg in_b_positive;
      
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
      
      for(i=0; i<W_D>>d; i=i+1) begin: s_width
        reg [W_D*2-1:0] out_data;
        if(d == 0) begin
          always @(posedge CLK) begin
            out_data <= (abs_in_b[i])? abs_in_a << i : {(W_D*2){1'b0}};
          end
        end else begin
          always @(posedge CLK) begin
            out_data <= s_depth[d-1].s_width[i*2].out_data + 
                        s_depth[d-1].s_width[i*2+1].out_data;
          end
        end
      end
    end
    
    always @(posedge CLK) begin
      if(RST) begin
        valid <= 0;
      end else begin
        valid <= s_depth[DEPTH-1].stage_valid;
      end
    end
    
    always @(posedge CLK) begin
      rslt <= (s_depth[DEPTH-1].in_a_positive && s_depth[DEPTH-1].in_b_positive)?
              s_depth[DEPTH-1].s_width[0].out_data :
              (!s_depth[DEPTH-1].in_a_positive && s_depth[DEPTH-1].in_b_positive)?
              complement2_2x(s_depth[DEPTH-1].s_width[0].out_data) :
              (s_depth[DEPTH-1].in_a_positive && !s_depth[DEPTH-1].in_b_positive)?
              complement2_2x(s_depth[DEPTH-1].s_width[0].out_data) :
              (!s_depth[DEPTH-1].in_a_positive && !s_depth[DEPTH-1].in_b_positive)?
              s_depth[DEPTH-1].s_width[0].out_data :
              'hx;
    end
  endgenerate
  
endmodule
 -----/\----- EXCLUDED -----/\----- */

module Multiplier #
  (
   parameter W_D = 32,
   parameter DEPTH = 6
   )
  (
   input CLK,
   input RST,
   input [W_D-1:0] in_a,
   input [W_D-1:0] in_b,
   input enable,
   output [W_D*2-1:0] rslt,
   output reg valid
   );

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
  wire [W_D*2-1:0] pipe_rslt;
  
  assign abs_in_a = absolute(in_a);
  assign abs_in_b = absolute(in_b);

  genvar d, i;
  generate 
    for(d=0; d<DEPTH; d=d+1) begin: s_depth
      reg stage_valid;
      reg in_a_positive;
      reg in_b_positive;
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
    end
  endgenerate
  
  always @(posedge CLK) begin
    if(RST) begin
      valid <= 0;
    end else begin
      valid <= s_depth[DEPTH-1].stage_valid;
    end
  end

  assign rslt = pipe_rslt;
  
  mm_pipelined_multiplier #
  (
   .DATA_WIDTH(W_D),
   .DEPTH(DEPTH-1)
   )
  multcore
  (
   .CLK(CLK),
   .A(abs_in_a),
   .B(abs_in_b),
   .RSLT(pipe_rslt)
   );

endmodule

(*mult_style="pipe_lut"*)
module mm_pipelined_multiplier #
  (
   parameter DATA_WIDTH = 32,
   parameter DEPTH = 6
   )
  (
   input CLK,
   input [DATA_WIDTH-1:0] A,
   input [DATA_WIDTH-1:0] B,
   output reg [DATA_WIDTH*2-1:0] RSLT
   );
  reg [DATA_WIDTH-1:0] a_in;
  reg [DATA_WIDTH-1:0] b_in;
  wire [DATA_WIDTH*2-1:0] mult_res;
  reg [DATA_WIDTH*2-1:0] pipe_regs [0:DEPTH-1];
  integer i;
  assign mult_res = a_in * b_in;
  always @(posedge CLK) begin
    a_in <= A;
    b_in <= B;
    pipe_regs[DEPTH-1] <= mult_res;
    for(i=0; i<DEPTH-1; i=i+1) pipe_regs[i] <= pipe_regs[i+1];
    RSLT <= pipe_regs[0];
  end
endmodule


