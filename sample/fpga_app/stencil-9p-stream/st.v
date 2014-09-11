`include "pycoram.v"

module st #
  (
   parameter NUM_BANKS = 2,
   parameter LOG_NUM_BANKS = 1,
   parameter W_D = 32
   )
  (
   input CLK,
   input RST
   );

  st_main #
    (
     .NUM_BANKS(NUM_BANKS),
     .LOG_NUM_BANKS(LOG_NUM_BANKS),
     .W_D(W_D)
     )
  inst_st_main
    (
     .CLK(CLK),
     .RST(RST)
     );

endmodule
  
//------------------------------------------------------------------------------
module st_main #
  (
   parameter NUM_BANKS = 2,
   parameter LOG_NUM_BANKS = 1,
   parameter W_D = 32,
   parameter W_A = 9, // 512 (= Max size of Matrix) 
   parameter W_COMM_A = 4 // 16
   )
  (
   input CLK,
   input RST
   );

  localparam PIPELINE_DEPTH = W_D + 3 + 1 + 3;

  reg [W_D-1:0] sum;
  
  reg [W_A-1:0] mem_addr;
  wire [W_D-1:0] mem_0_q;
  wire [W_D-1:0] mem_1_q;
  wire [W_D-1:0] mem_2_q;
  wire [W_D-1:0] mem_3_q;
  
  reg [W_A-1:0] mem_d_addr;
  reg [W_A-1:0] next_mem_d_addr;
  
  reg [W_D*NUM_BANKS-1:0] mem_d_d;
  reg mem_d_enq;
  wire mem_d_full;
  wire mem_d_almost_full;

  reg [W_D-1:0] comm_d;
  wire [W_D-1:0] comm_q;
  reg comm_enq;
  reg comm_deq;
  wire comm_empty;
  wire comm_full;

  reg [7:0] state;
  
  reg [W_D-1:0] read_count;
  reg [W_D-1:0] mesh_size;
  
  reg [W_D-1:0] comp_d0;
  reg [W_D-1:0] comp_d1;
  reg [W_D-1:0] comp_d2;
  reg [W_D-1:0] comp_d3;
  reg [3:0] comp_inv_active_map;
  reg comp_enable;
  reg [7:0] comp_wait;
  reg comp_reset;

  reg init_sum;
  reg calc_sum;
  reg hot_spot;
  reg [3:0] inv_read_active_map;
  reg read_buf2;
  reg [W_A-1:0] write_count;
  
  reg [W_D-1:0] edgeinfo_data_in;
  reg edgeinfo_enq;
  wire edgeinfo_full;
  wire edgeinfo_almost_full;
  
  wire [W_D-1:0] edgeinfo_data_out;
  wire edgeinfo_deq;
  wire edgeinfo_empty;
  wire edgeinfo_almost_empty;
  
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
      read_buf2 <= 0;
      mesh_size <= 0;
      read_count <= 0;
      mem_addr <= 0;
      comp_enable <= 0;
      comp_reset <= 0;
      comp_d0 <= 0;
      comp_d1 <= 0;
      comp_d2 <= 0;
      comp_d3 <= 0;
      comp_inv_active_map <= 0;
      comp_wait <= 0;
      edgeinfo_enq <= 0;
      edgeinfo_data_in <= 0;
    end else begin
      // default value
      comm_enq <= 0;
      comm_deq <= 0;
      comp_enable <= 0;
      comp_reset <= 0;
      edgeinfo_enq <= 0;
      
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
          read_buf2 <= 0;
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
          {read_buf2, init_sum, calc_sum, hot_spot, inv_read_active_map} <= comm_q;
          mem_addr <= 0;
          read_count <= 0;
          if(comm_q == 0) begin // done
            state <= 'h0;
            comp_reset <= 1;
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
          if(read_count == 0) edgeinfo_enq <= 1;
          edgeinfo_data_in <= inv_read_active_map[0]? mem_2_q :
                              inv_read_active_map[1]? mem_3_q :
                              inv_read_active_map[2]? mem_0_q :
                              inv_read_active_map[3]? mem_1_q :
                              'hx;

          mem_addr <= mem_addr + 1;
          read_count <= read_count + 1;
          comp_enable <= !calc_sum;
          if(!inv_read_active_map[0] && mem_0_q === 'hx) $finish;
          if(!inv_read_active_map[1] && mem_1_q === 'hx) $finish;
          if(!inv_read_active_map[2] && mem_2_q === 'hx) $finish;
          if(!inv_read_active_map[3] && mem_3_q === 'hx) $finish;
          comp_d0 <= (read_buf2 && (mem_addr == 1))? 0 : mem_0_q;
          comp_d1 <= (read_buf2 && (mem_addr == 1))? 0 : mem_1_q;
          comp_d2 <= (read_buf2 && (mem_addr == 1))? 0 : mem_2_q;
          comp_d3 <= (read_buf2 && (mem_addr == 1))? 0 : mem_3_q;
          if(!calc_sum)
            $display("Q: %x %x %x %x",
                     !inv_read_active_map[0]? (read_buf2 && (mem_addr == 1)? 0 : mem_0_q) : 'hffffffff,
                     !inv_read_active_map[1]? (read_buf2 && (mem_addr == 1)? 0 : mem_1_q) : 'hffffffff,
                     !inv_read_active_map[2]? (read_buf2 && (mem_addr == 1)? 0 : mem_2_q) : 'hffffffff,
                     !inv_read_active_map[3]? (read_buf2 && (mem_addr == 1)? 0 : mem_3_q) : 'hffffffff);
          comp_inv_active_map <= inv_read_active_map;
          sum <= sum + mem_0_q;
          if(read_count + 3 >= mesh_size) begin
            state <= 'h8;
          end
        end
        'h8: begin
          read_count <= read_count + 1;
          comp_enable <= !calc_sum;
          if(!inv_read_active_map[0] && mem_0_q === 'hx) $finish;
          if(!inv_read_active_map[1] && mem_1_q === 'hx) $finish;
          if(!inv_read_active_map[2] && mem_2_q === 'hx) $finish;
          if(!inv_read_active_map[3] && mem_3_q === 'hx) $finish;
          comp_d0 <= mem_0_q;
          comp_d1 <= mem_1_q;
          comp_d2 <= mem_2_q;
          comp_d3 <= mem_3_q;
          if(!calc_sum)
            $display("Q: %x %x %x %x",!inv_read_active_map[0]? mem_0_q:'hffffffff,
                     !inv_read_active_map[1]? mem_1_q:'hffffffff,
                     !inv_read_active_map[2]? mem_2_q:'hffffffff,
                     !inv_read_active_map[3]? mem_3_q:'hffffffff);
          comp_inv_active_map <= inv_read_active_map;
          sum <= sum + mem_0_q;
          state <= 'h9;
        end
        'h9: begin
          edgeinfo_enq <= 1;
          edgeinfo_data_in <= inv_read_active_map[0]? mem_2_q :
                              inv_read_active_map[1]? mem_3_q :
                              inv_read_active_map[2]? mem_0_q :
                              inv_read_active_map[3]? mem_1_q :
                              'hx;
          read_count <= read_count + 1;
          comp_enable <= !calc_sum;
          if(!inv_read_active_map[0] && mem_0_q === 'hx) $finish;
          if(!inv_read_active_map[1] && mem_1_q === 'hx) $finish;
          if(!inv_read_active_map[2] && mem_2_q === 'hx) $finish;
          if(!inv_read_active_map[3] && mem_3_q === 'hx) $finish;
          comp_d0 <= (read_buf2 && (mem_addr == mesh_size-1))? 0 : mem_0_q;
          comp_d1 <= (read_buf2 && (mem_addr == mesh_size-1))? 0 : mem_1_q;
          comp_d2 <= (read_buf2 && (mem_addr == mesh_size-1))? 0 : mem_2_q;
          comp_d3 <= (read_buf2 && (mem_addr == mesh_size-1))? 0 : mem_3_q;
          if(!calc_sum)
            $display("Q: %x %x %x %x", 
                     !inv_read_active_map[0]? (read_buf2 && (mem_addr == mesh_size-1)? 0 : mem_0_q) : 'hffffffff,
                     !inv_read_active_map[1]? (read_buf2 && (mem_addr == mesh_size-1)? 0 : mem_1_q) : 'hffffffff,
                     !inv_read_active_map[2]? (read_buf2 && (mem_addr == mesh_size-1)? 0 : mem_2_q) : 'hffffffff,
                     !inv_read_active_map[3]? (read_buf2 && (mem_addr == mesh_size-1)? 0 : mem_3_q) : 'hffffffff);
          comp_inv_active_map <= inv_read_active_map;
          sum <= sum + mem_0_q;
          comp_wait <= 0;
          state <= 'ha;
        end
        'ha: begin
          comm_d <= sum;
          if(!comm_full && !mem_d_almost_full) begin
            comm_enq <= 1;
            state <= 'hb;
          end
        end
        'hb: begin
          comm_enq <= 0;
          state <= 'h3;
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
     .in0(comp_d0),
     .in1(comp_d1),
     .in2(comp_d2),
     .in3(comp_d3),
     .inv_active_map(comp_inv_active_map),
     .enable(comp_enable_local),
     .rslt(comp_rslt),
     .valid(comp_valid)
    );

  edgeinfo_fifo #
  (
   .ADDR_LEN(4),
   .DATA_WIDTH(W_D)
   )
  inst_edgeinfo_fifo
  (
   .CLK(CLK),
   .RST(RST),
   .Q(edgeinfo_data_out),
   .DEQ(edgeinfo_deq),
   .EMPTY(edgeinfo_empty),
   .ALM_EMPTY(edgeinfo_almost_empty),
   .D(edgeinfo_data_in),
   .ENQ(edgeinfo_enq),
   .FULL(edgeinfo_full),
   .ALM_FULL(edgeinfo_almost_full)
   );

  reg d_comp_enable;
  reg d_comp_valid;
  reg dd_comp_valid;
  reg [W_D-1:0] d_comp_rslt;

  assign edgeinfo_deq = (comp_valid && !d_comp_valid) || (!d_comp_valid && dd_comp_valid);
  
  always @(posedge CLK) begin
    if(RST) begin
      mem_d_addr <= 0;
      mem_d_d <= 0;
      mem_d_enq <= 0;
      next_mem_d_addr <= 0;
      write_count <= 0;
      d_comp_enable <= 0;
      d_comp_valid <= 0;
      dd_comp_valid <= 0;
      d_comp_rslt <= 0;
    end else begin
      if(comp_valid && comp_rslt === 'hx) $finish;
      mem_d_enq <= 0;
      d_comp_enable <= comp_enable;
      d_comp_valid <= comp_valid;
      dd_comp_valid <= d_comp_valid;
      d_comp_rslt <= comp_rslt;

      if(comp_valid && !d_comp_valid) begin // first
        mem_d_enq <= write_count == NUM_BANKS-1;
        mem_d_addr <= next_mem_d_addr;
        mem_d_d <= edgeinfo_data_out << (W_D*(NUM_BANKS-1)) | (mem_d_d >> W_D);
        next_mem_d_addr <= (next_mem_d_addr == mesh_size - 1)? 0 : next_mem_d_addr + 1;
        write_count <= (write_count == NUM_BANKS-1)? 0: write_count + 1;
      end
      
      if(d_comp_valid) begin
        mem_d_enq <= write_count == NUM_BANKS-1;
        mem_d_addr <= next_mem_d_addr;
        mem_d_d <= (next_mem_d_addr == 1 && hot_spot)? 32'h9999999 << (W_D*(NUM_BANKS-1)) | (mem_d_d >> W_D):
                   d_comp_rslt << (W_D*(NUM_BANKS-1)) | (mem_d_d >> W_D);
        next_mem_d_addr <= (next_mem_d_addr == mesh_size - 1)? 0 : next_mem_d_addr + 1;
        write_count <= (write_count == NUM_BANKS-1)? 0: write_count + 1;
      end

      if(!d_comp_valid && dd_comp_valid) begin
        mem_d_enq <= write_count == NUM_BANKS-1;
        mem_d_addr <= next_mem_d_addr;
        mem_d_d <= edgeinfo_data_out << (W_D*(NUM_BANKS-1)) | (mem_d_d >> W_D);
        next_mem_d_addr <= (next_mem_d_addr == mesh_size - 1)? 0 : next_mem_d_addr + 1;
        write_count <= (write_count == NUM_BANKS-1)? 0: write_count + 1;
      end
    
      if(comp_reset) begin
        mem_d_addr <= 0;
        next_mem_d_addr <= 0;
        write_count <= 0;
      end
      
    end
  end

  always @(negedge CLK) begin
    if(mem_d_enq) begin
      $display("D: %x->%x", mem_d_d, mem_d_addr);
    end
  end
  
  MultibankCoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_st"),
     .CORAM_ID(0),
     .CORAM_SUB_ID(0),
     .ADDR_LEN(W_A),
     .DATA_WIDTH(W_D),
     .NUM_BANKS(NUM_BANKS),
     .LOG_NUM_BANKS(LOG_NUM_BANKS)
     )
  inst_mem_0
   (
    .CLK(CLK),
    .ADDR(mem_addr),
    .D('hx),
    .WE(1'b0),
    .Q(mem_0_q)
    );

  MultibankCoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_st"),
     .CORAM_ID(0),
     .CORAM_SUB_ID(1),
     .ADDR_LEN(W_A),
     .DATA_WIDTH(W_D),
     .NUM_BANKS(NUM_BANKS),
     .LOG_NUM_BANKS(LOG_NUM_BANKS)
     )
  inst_mem_1
   (
    .CLK(CLK),
    .ADDR(mem_addr),
    .D('hx),
    .WE(1'b0),
    .Q(mem_1_q)
    );

  MultibankCoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_st"),
     .CORAM_ID(0),
     .CORAM_SUB_ID(2),
     .ADDR_LEN(W_A),
     .DATA_WIDTH(W_D),
     .NUM_BANKS(NUM_BANKS),
     .LOG_NUM_BANKS(LOG_NUM_BANKS)
     )
  inst_mem_2
   (
    .CLK(CLK),
    .ADDR(mem_addr),
    .D('hx),
    .WE(1'b0),
    .Q(mem_2_q)
    );

  MultibankCoramMemory1P #
    (
     .CORAM_THREAD_NAME("cthread_st"),
     .CORAM_ID(0),
     .CORAM_SUB_ID(3),
     .ADDR_LEN(W_A),
     .DATA_WIDTH(W_D),
     .NUM_BANKS(NUM_BANKS),
     .LOG_NUM_BANKS(LOG_NUM_BANKS)
     )
  inst_mem_3
   (
    .CLK(CLK),
    .ADDR(mem_addr),
    .D('hx),
    .WE(1'b0),
    .Q(mem_3_q)
    );

  CoramOutStream #
    (
     .CORAM_THREAD_NAME("cthread_st"),
     .CORAM_ID(0),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_A),
     .CORAM_DATA_WIDTH(W_D * NUM_BANKS)
     )
  inst_mem_d0
   (
    .CLK(CLK),
    .RST(RST),
    .D(mem_d_d),
    .ENQ(mem_d_enq),
    .FULL(mem_d_full),
    .ALM_FULL(mem_d_almost_full)
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

module MultibankCoramMemory1P(CLK, ADDR, D, WE, Q);
  parameter CORAM_THREAD_NAME = "undefined";
  parameter CORAM_ID = 0;
  parameter CORAM_SUB_ID = 0;
  
  parameter ADDR_LEN = 9;
  parameter DATA_WIDTH = 32;
  parameter NUM_BANKS = 4;
  parameter LOG_NUM_BANKS = 2;

  input                   CLK;
  input  [ADDR_LEN-1:0]   ADDR;
  input  [DATA_WIDTH-1:0] D;
  input                   WE;
  output [DATA_WIDTH-1:0] Q;

  localparam CORAM_ADDR_LEN = ADDR_LEN - LOG_NUM_BANKS;
  localparam CORAM_DATA_WIDTH = DATA_WIDTH * NUM_BANKS;
  localparam CORAM_MASK_WIDTH = CORAM_DATA_WIDTH / 8;

  wire [CORAM_ADDR_LEN-1:0] coram_addr;
  wire [CORAM_DATA_WIDTH-1:0] coram_d;
  wire coram_we;
  wire [CORAM_MASK_WIDTH-1:0] coram_mask;
  wire [CORAM_DATA_WIDTH-1:0] coram_q;

  assign coram_addr = ADDR[ADDR_LEN-1:LOG_NUM_BANKS];
  assign coram_we = WE;
  generate if(LOG_NUM_BANKS == 0) begin
    assign coram_d = D;
    assign coram_mask = {(DATA_WIDTH / 8){1'b1}};
    assign Q = coram_q;
  end else begin
    assign coram_d = D << (DATA_WIDTH * ADDR[LOG_NUM_BANKS-1:0]);
    assign coram_mask = {(DATA_WIDTH / 8){1'b1}} << ((DATA_WIDTH / 8) * ADDR[LOG_NUM_BANKS-1:0]);
    assign Q = coram_q >> (DATA_WIDTH * d_ADDR[LOG_NUM_BANKS-1:0]);
  end endgenerate

  reg [ADDR_LEN-1:0] d_ADDR;
  always @(posedge CLK) begin
    d_ADDR <= ADDR;
  end
  
  CoramMemoryBE1P #
    (
     .CORAM_THREAD_NAME(CORAM_THREAD_NAME),
     .CORAM_ID(CORAM_ID),
     .CORAM_SUB_ID(CORAM_SUB_ID),
     .CORAM_ADDR_LEN(CORAM_ADDR_LEN),
     .CORAM_DATA_WIDTH(CORAM_DATA_WIDTH)
     )
  inst_mem
   (
    .CLK(CLK),
    .ADDR(coram_addr),
    .D(coram_d),
    .WE(coram_we),
    .MASK(coram_mask),
    .Q(coram_q)
    );
endmodule

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
