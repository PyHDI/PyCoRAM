`include "pycoram.v"

module mm #
  (
   //parameter SIMD_WIDTH = 8,
   //parameter LOG_SIMD_WIDTH = 3,
   parameter SIMD_WIDTH = 4,
   parameter LOG_SIMD_WIDTH = 2,
   //parameter SIMD_WIDTH = 2,
   //parameter LOG_SIMD_WIDTH = 1,
   //parameter SIMD_WIDTH = 1,
   //parameter LOG_SIMD_WIDTH = 0,
   parameter W_D = 32,
   parameter W_A = 9
   )
  (
   input CLK,
   input RST
   );

  mm_main #
    (
     .SIMD_WIDTH(SIMD_WIDTH),
     .LOG_SIMD_WIDTH(LOG_SIMD_WIDTH),
     .W_D(W_D),
     .W_A(W_A)
     )
  inst_mm_main
    (
     .CLK(CLK),
     .RST(RST)
     );

endmodule
  
//------------------------------------------------------------------------------
module mm_main #
  (
   parameter SIMD_WIDTH = 4,
   parameter LOG_SIMD_WIDTH = 2,
   parameter W_D = 32,
   parameter W_A = 9, // Max Matix Size = 512, so address width = 9 (in 4-byte per word)
   parameter W_COMM_A = 4 // 16
   )
  (
   input CLK,
   input RST
   );

  localparam W_MEM_A = W_A - LOG_SIMD_WIDTH;
  localparam W_MEM_A_A = W_MEM_A;
  localparam W_MEM_B_A = W_MEM_A;
  localparam W_MEM_C_A = W_MEM_A;
  localparam MULTIPLIER_DEPTH = 6;

  wire [W_MEM_A_A-1:0] mem_a_addr;
  reg [W_MEM_A_A-1:0] next_mem_a_addr;
  wire [W_D*SIMD_WIDTH-1:0] mem_a_q;

  wire mem_b_deq;
  reg d_mem_b_deq;
  wire mem_b_empty;
  wire [W_D*SIMD_WIDTH-1:0] mem_b_q;
  
  reg [W_D*SIMD_WIDTH-1:0] mem_c_d;
  reg mem_c_enq;
  wire mem_c_full;
  wire mem_c_almost_full;
  reg [SIMD_WIDTH-1:0] mem_c_enq_count;

  reg [W_D-1:0] comm_d;
  wire [W_D-1:0] comm_q;
  reg comm_enq;
  reg comm_deq;
  wire comm_empty;
  wire comm_full;

  reg [7:0] state;
  
  reg [W_D-1:0] computation_size;
  reg [W_D-1:0] comp_count;
  reg [W_D-1:0] matrix_size;
  reg [W_D-1:0] read_count;
  
  reg mult_enable;
  reg [W_D*SIMD_WIDTH-1:0] mult_a_d_all;
  reg [W_D*SIMD_WIDTH-1:0] mult_b_d_all;
  reg [7:0] mult_wait;
  wire [SIMD_WIDTH-1:0] mult_valid;

  reg [W_D-1:0] local_sum [0:SIMD_WIDTH-1];
  reg [W_D*SIMD_WIDTH-1:0] local_sum_buf;

  reg adder_enable;
  wire [W_D-1:0] sum;
  wire sum_valid;
  
  reg [W_D-1:0] cyclecount;

  assign mem_a_addr = next_mem_a_addr;
  assign mem_b_deq = !mem_b_empty && ((state == 'h6) || (state == 'h7));
  
  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      comm_d <= 0;
      comm_enq <= 0;
      comm_deq <= 0;
      next_mem_a_addr <= 0;
      read_count <= 0;
      matrix_size <= 0;
      computation_size <= 0;
      mult_enable <= 0;
      mult_a_d_all <= 0;
      mult_b_d_all <= 0;
      mult_wait <= 0;
      d_mem_b_deq <= 0;
    end else begin
      // default value
      comm_enq <= 0;
      comm_deq <= 0;
      mult_enable <= 0;
      d_mem_b_deq <= mem_b_deq;
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
          read_count <= 0;
          if(comm_q == 0) begin // done
            state <= 'h0;
          end else begin
            state <= 'h6;
          end
        end
        'h6: begin
          if(mem_b_deq) begin
            $display("computation_size=%d", computation_size);
            next_mem_a_addr <= (next_mem_a_addr == matrix_size/SIMD_WIDTH -1)? 0 : next_mem_a_addr + 1;
            state <= 'h7;
          end
        end
        'h7: begin
          if(d_mem_b_deq) begin
            read_count <= read_count + 1;
            mult_enable <= 1;          
            mult_a_d_all <= mem_a_q;
            mult_b_d_all <= mem_b_q;
            $display("a=%x, b=%x", mem_a_q, mem_b_q);
/* -----\/----- EXCLUDED -----\/-----
            if(read_count + 2 >= computation_size) begin
              state <= 'h8;
            end
 -----/\----- EXCLUDED -----/\----- */
          end
          if(mem_b_deq) begin
            next_mem_a_addr <= (next_mem_a_addr == matrix_size/SIMD_WIDTH -1)? 0 : next_mem_a_addr + 1;
          end
          if(d_mem_b_deq && mem_b_deq && read_count + 2 >= computation_size) begin
            state <= 'h8;
          end
          if(!d_mem_b_deq && mem_b_deq && read_count + 1 >= computation_size) begin
            state <= 'h8;
          end
        end
        'h8: begin
          if(d_mem_b_deq) begin
            read_count <= read_count + 1;
            mult_enable <= 1;          
            mult_a_d_all <= mem_a_q;
            mult_b_d_all <= mem_b_q;
            $display("a=%x, b=%x", mem_a_q, mem_b_q);
            state <= 'h9;
          end
        end
        'h9: begin
          mult_wait <= 0;
          state <= 'ha;
        end
        'ha: begin
          mult_wait <= mult_wait + 1;
          if(mult_wait == MULTIPLIER_DEPTH + 2 + SIMD_WIDTH + 1) begin
            state <= 'hb;
          end
        end
        'hb: begin
          comm_d <= cyclecount;
          if(!comm_full) begin
            comm_enq <= 1;
            state <= 'hc;
          end
        end
        'hc: begin
          comm_enq <= 0;
          state <= 'h3;
        end
      endcase
    end
  end

  // execution pipeline
  genvar i;
  generate for(i=0; i<SIMD_WIDTH; i=i+1) begin: simd_bank
    wire [W_D-1:0] mult_a_d;
    wire [W_D-1:0] mult_b_d;
    wire [W_D*2-1:0] mult_rslt;
    assign mult_a_d = mult_a_d_all[W_D*(i+1)-1:W_D*i];
    assign mult_b_d = mult_b_d_all[W_D*(i+1)-1:W_D*i];
    
    wire [W_D-1:0] local_sum_wire;
    assign local_sum_wire = local_sum[i];
    
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
       .enable(mult_enable),
       .rslt(mult_rslt),
       .valid(mult_valid[i])
       );

    always @(posedge CLK) begin
      if(RST) begin
        local_sum[i] <= 0;
        local_sum_buf[W_D*(i+1)-1:W_D*i] <= 0;
      end else begin
        if(state == 'h2) begin
          local_sum[i] <= 0;
          local_sum_buf[W_D*(i+1)-1:W_D*i] <= 0;
        end else if(mult_valid) begin
          if(comp_count < matrix_size - SIMD_WIDTH) begin
            local_sum[i] <= local_sum[i] + mult_rslt[W_D-1:0];
          end else begin
            local_sum_buf[W_D*(i+1)-1:W_D*i] <= local_sum[i] + mult_rslt[W_D-1:0];
            local_sum[i] <= 0;
          end
        end
      end
    end
    
  end endgenerate

  SimdAdder #
    (
     .SIMD_WIDTH(SIMD_WIDTH),
     .LOG_SIMD_WIDTH(LOG_SIMD_WIDTH),
     .W_D(W_D)
     )
  inst_simdadder
    (
     .CLK(CLK),
     .RST(RST),
     .data_in(local_sum_buf),
     .enable(adder_enable),
     .data_out(sum),
     .valid(sum_valid)
     );
  
  always @(posedge CLK) begin
    if(RST) begin
      mem_c_enq <= 0;
      mem_c_d <= 0;
      mem_c_enq_count <= 0;
      comp_count <= 0;
      adder_enable <= 0;
    end else begin
      // default value
      mem_c_enq <= 0;
      adder_enable <= 0;
      
      if(state == 'h2) begin
        mem_c_enq_count <= 0;
        comp_count <= 0;
        adder_enable <= 0;
      end
      
      if(mult_valid[0]) begin
        if(comp_count < matrix_size - SIMD_WIDTH) begin
          comp_count <= comp_count + SIMD_WIDTH;
        end else begin
          comp_count <= 0;
          adder_enable <= 1;
        end
      end
      
      if(sum_valid) begin
        mem_c_enq_count <= (mem_c_enq_count == SIMD_WIDTH - 1)? 0: mem_c_enq_count + 1;
        mem_c_enq <= (mem_c_enq_count == SIMD_WIDTH - 1);
        mem_c_d <= sum << (W_D * (SIMD_WIDTH - 1)) | (mem_c_d >> W_D);
        $display("rslt=%x", sum);
        if(mem_c_enq_count == SIMD_WIDTH - 1) begin
          $display("c=%x", (sum << (W_D * (SIMD_WIDTH - 1)) | (mem_c_d >> W_D)));
        end
      end
    end
  end

  always @(posedge CLK) begin
    if(RST) begin
      cyclecount <= 0;
    end else begin
      if(state == 'h2) begin
        cyclecount <= 0;
      end else begin
        cyclecount <= cyclecount + 1;
      end
    end
  end
  
  CoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_mm"),
     .CORAM_ID(0),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_MEM_A_A),
     .CORAM_DATA_WIDTH(W_D * SIMD_WIDTH)
     )
  inst_mem_a
   (
    .CLK(CLK),
    .ADDR(mem_a_addr),
    .D('hx),
    .WE(1'b0),
    .Q(mem_a_q)
    );

  CoramInStream #
    (
     .CORAM_THREAD_NAME("cthread_mm"),
     .CORAM_ID(0),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_MEM_B_A),
     .CORAM_DATA_WIDTH(W_D * SIMD_WIDTH)
     )
  inst_mem_b
   (
    .CLK(CLK),
    .RST(RST),
    .Q(mem_b_q),
    .DEQ(mem_b_deq),
    .EMPTY(mem_b_empty),
    .ALM_EMPTY()
    );
  
  CoramOutStream #
    (
     .CORAM_THREAD_NAME("cthread_mm"),
     .CORAM_ID(0),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_MEM_C_A),
     .CORAM_DATA_WIDTH(W_D * SIMD_WIDTH)
     )
  inst_mem_c
   (
    .CLK(CLK),
    .RST(RST),
    .D(mem_c_d),
    .ENQ(mem_c_enq),
    .FULL(mem_c_full),
    .ALM_FULL(mem_c_almost_full)
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

//------------------------------------------------------------------------------
module SimdAdder #
  (
   parameter SIMD_WIDTH = 4,
   parameter LOG_SIMD_WIDTH = 2,
   parameter W_D = 32
   )
  (
   input CLK,
   input RST,
   input [W_D*SIMD_WIDTH-1:0] data_in,
   input enable,
   output [W_D-1:0] data_out,
   output valid
   );

  genvar i, j;
  generate for(i=0; i<LOG_SIMD_WIDTH; i=i+1) begin: depth
    for(j=0; j<SIMD_WIDTH >> (i+1); j=j+1) begin: width
      reg [W_D-1:0] sum;
      reg valid;
      if(i == 0) begin
        always @(posedge CLK) begin
          if(RST) begin
            sum <= 0;
            valid <= 0;
          end else begin
            sum <= data_in[W_D*(2*j+2)-1:W_D*(2*j+1)] + data_in[W_D*(2*j+1)-1:W_D*(2*j)];
            valid <= enable;
          end
        end
      end else begin
        always @(posedge CLK) begin
          if(RST) begin
            sum <= 0;
            valid <= 0;
          end else begin
            sum <= depth[i-1].width[2*j+1].sum + depth[i-1].width[2*j].sum;
            valid <= depth[i-1].width[2*j].valid;
          end
        end
      end
    end
  end endgenerate

  generate if(LOG_SIMD_WIDTH == 0) begin: single
    reg [W_D*SIMD_WIDTH-1:0] data_in_buf;
    reg enable_buf;
    always @(posedge CLK) begin
      if(RST) begin
        data_in_buf <= 0;
        enable_buf <= 0;
      end else begin
        data_in_buf <= data_in;
        enable_buf <= enable;
      end
    end
    assign data_out = data_in_buf;
    assign valid = enable_buf;
  end else begin: not_single
    assign data_out = depth[LOG_SIMD_WIDTH-1].width[0].sum;
    assign valid = depth[LOG_SIMD_WIDTH-1].width[0].valid;
  end endgenerate
  
endmodule

