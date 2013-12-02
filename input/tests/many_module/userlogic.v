`include "pycoram.v"

`define THREAD_NAME "ctrl_thread"

module userlogic(CLK, RST);
  input CLK, RST;
  reg [31:0] in_0;
  wire [31:0] out_0;
  reg [31:0] in_1;
  wire [31:0] out_1;
  reg [31:0] in_2;
  wire [31:0] out_2;
  reg [31:0] in_3;
  wire [31:0] out_3;
  reg [31:0] in_4;
  wire [31:0] out_4;
  reg [31:0] in_5;
  wire [31:0] out_5;
  reg [31:0] in_6;
  wire [31:0] out_6;
  reg [31:0] in_7;
  wire [31:0] out_7;
  reg [31:0] in_8;
  wire [31:0] out_8;
  reg [31:0] in_9;
  wire [31:0] out_9;
  reg [31:0] in_10;
  wire [31:0] out_10;
  reg [31:0] in_11;
  wire [31:0] out_11;
  reg [31:0] in_12;
  wire [31:0] out_12;
  reg [31:0] in_13;
  wire [31:0] out_13;
  reg [31:0] in_14;
  wire [31:0] out_14;
  reg [31:0] in_15;
  wire [31:0] out_15;
  reg [31:0] in_16;
  wire [31:0] out_16;
  reg [31:0] in_17;
  wire [31:0] out_17;
  reg [31:0] in_18;
  wire [31:0] out_18;
  reg [31:0] in_19;
  wire [31:0] out_19;
  reg [31:0] in_20;
  wire [31:0] out_20;
  reg [31:0] in_21;
  wire [31:0] out_21;
  reg [31:0] in_22;
  wire [31:0] out_22;
  reg [31:0] in_23;
  wire [31:0] out_23;
  reg [31:0] in_24;
  wire [31:0] out_24;
  reg [31:0] in_25;
  wire [31:0] out_25;
  reg [31:0] in_26;
  wire [31:0] out_26;
  reg [31:0] in_27;
  wire [31:0] out_27;
  reg [31:0] in_28;
  wire [31:0] out_28;
  reg [31:0] in_29;
  wire [31:0] out_29;
  reg [31:0] in_30;
  wire [31:0] out_30;
  reg [31:0] in_31;
  wire [31:0] out_31;

  always @(posedge CLK) begin
    if(RST) begin
      in_0 <= 0;
      in_1 <= 0;
      in_2 <= 0;
      in_3 <= 0;
      in_4 <= 0;
      in_5 <= 0;
      in_6 <= 0;
      in_7 <= 0;
      in_8 <= 0;
      in_9 <= 0;
      in_10 <= 0;
      in_11 <= 0;
      in_12 <= 0;
      in_13 <= 0;
      in_14 <= 0;
      in_15 <= 0;
      in_16 <= 0;
      in_17 <= 0;
      in_18 <= 0;
      in_19 <= 0;
      in_20 <= 0;
      in_21 <= 0;
      in_22 <= 0;
      in_23 <= 0;
      in_24 <= 0;
      in_25 <= 0;
      in_26 <= 0;
      in_27 <= 0;
      in_28 <= 0;
      in_29 <= 0;
      in_30 <= 0;
      in_31 <= 0;
    end else begin
      in_0 <= in_0 + 0;
      in_1 <= in_1 + 1;
      in_2 <= in_2 + 2;
      in_3 <= in_3 + 3;
      in_4 <= in_4 + 4;
      in_5 <= in_5 + 5;
      in_6 <= in_6 + 6;
      in_7 <= in_7 + 7;
      in_8 <= in_8 + 8;
      in_9 <= in_9 + 9;
      in_10 <= in_10 + 10;
      in_11 <= in_11 + 11;
      in_12 <= in_12 + 12;
      in_13 <= in_13 + 13;
      in_14 <= in_14 + 14;
      in_15 <= in_15 + 15;
      in_16 <= in_16 + 16;
      in_17 <= in_17 + 17;
      in_18 <= in_18 + 18;
      in_19 <= in_19 + 19;
      in_20 <= in_20 + 20;
      in_21 <= in_21 + 21;
      in_22 <= in_22 + 22;
      in_23 <= in_23 + 23;
      in_24 <= in_24 + 24;
      in_25 <= in_25 + 25;
      in_26 <= in_26 + 26;
      in_27 <= in_27 + 27;
      in_28 <= in_28 + 28;
      in_29 <= in_29 + 29;
      in_30 <= in_30 + 30;
      in_31 <= in_31 + 31;
    end
  end
  SUB #
  (
   .ID(0)
  )
  inst_sub_0
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_0),
   .OUT(out_0)
  );
  SUB #
  (
   .ID(1)
  )
  inst_sub_1
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_1),
   .OUT(out_1)
  );
  SUB #
  (
   .ID(2)
  )
  inst_sub_2
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_2),
   .OUT(out_2)
  );
  SUB #
  (
   .ID(3)
  )
  inst_sub_3
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_3),
   .OUT(out_3)
  );
  SUB #
  (
   .ID(4)
  )
  inst_sub_4
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_4),
   .OUT(out_4)
  );
  SUB #
  (
   .ID(5)
  )
  inst_sub_5
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_5),
   .OUT(out_5)
  );
  SUB #
  (
   .ID(6)
  )
  inst_sub_6
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_6),
   .OUT(out_6)
  );
  SUB #
  (
   .ID(7)
  )
  inst_sub_7
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_7),
   .OUT(out_7)
  );
  SUB #
  (
   .ID(8)
  )
  inst_sub_8
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_8),
   .OUT(out_8)
  );
  SUB #
  (
   .ID(9)
  )
  inst_sub_9
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_9),
   .OUT(out_9)
  );
  SUB #
  (
   .ID(10)
  )
  inst_sub_10
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_10),
   .OUT(out_10)
  );
  SUB #
  (
   .ID(11)
  )
  inst_sub_11
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_11),
   .OUT(out_11)
  );
  SUB #
  (
   .ID(12)
  )
  inst_sub_12
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_12),
   .OUT(out_12)
  );
  SUB #
  (
   .ID(13)
  )
  inst_sub_13
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_13),
   .OUT(out_13)
  );
  SUB #
  (
   .ID(14)
  )
  inst_sub_14
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_14),
   .OUT(out_14)
  );
  SUB #
  (
   .ID(15)
  )
  inst_sub_15
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_15),
   .OUT(out_15)
  );
  SUB #
  (
   .ID(16)
  )
  inst_sub_16
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_16),
   .OUT(out_16)
  );
  SUB #
  (
   .ID(17)
  )
  inst_sub_17
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_17),
   .OUT(out_17)
  );
  SUB #
  (
   .ID(18)
  )
  inst_sub_18
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_18),
   .OUT(out_18)
  );
  SUB #
  (
   .ID(19)
  )
  inst_sub_19
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_19),
   .OUT(out_19)
  );
  SUB #
  (
   .ID(20)
  )
  inst_sub_20
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_20),
   .OUT(out_20)
  );
  SUB #
  (
   .ID(21)
  )
  inst_sub_21
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_21),
   .OUT(out_21)
  );
  SUB #
  (
   .ID(22)
  )
  inst_sub_22
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_22),
   .OUT(out_22)
  );
  SUB #
  (
   .ID(23)
  )
  inst_sub_23
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_23),
   .OUT(out_23)
  );
  SUB #
  (
   .ID(24)
  )
  inst_sub_24
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_24),
   .OUT(out_24)
  );
  SUB #
  (
   .ID(25)
  )
  inst_sub_25
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_25),
   .OUT(out_25)
  );
  SUB #
  (
   .ID(26)
  )
  inst_sub_26
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_26),
   .OUT(out_26)
  );
  SUB #
  (
   .ID(27)
  )
  inst_sub_27
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_27),
   .OUT(out_27)
  );
  SUB #
  (
   .ID(28)
  )
  inst_sub_28
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_28),
   .OUT(out_28)
  );
  SUB #
  (
   .ID(29)
  )
  inst_sub_29
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_29),
   .OUT(out_29)
  );
  SUB #
  (
   .ID(30)
  )
  inst_sub_30
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_30),
   .OUT(out_30)
  );
  SUB #
  (
   .ID(31)
  )
  inst_sub_31
  (
   .CLK(CLK),
   .RST(RST),
   .IN(in_31),
   .OUT(out_31)
  );

endmodule



module SUB (CLK, RST, IN, OUT);
  parameter ID = 0;
  input CLK, RST;
  input [31:0] IN;
  output [31:0] OUT;
  SUBSUB #(.ID(ID))
  inst (.CLK(CLK), .RST(RST), .IN(IN), .OUT(OUT));
endmodule

module SUBSUB (CLK, RST, IN, OUT);
  parameter ID = 0;
  input CLK, RST;
  input [31:0] IN;
  output [31:0] OUT;
  SUBSUBSUB #(.ID(ID))
  inst (.CLK(CLK), .RST(RST), .IN(IN), .OUT(OUT));
endmodule

module SUBSUBSUB (CLK, RST, IN, OUT);
  parameter ID = 0;
  input CLK, RST;
  input [31:0] IN;
  output [31:0] OUT;
  SUBSUBSUBSUB #(.ID(ID))
  inst (.CLK(CLK), .RST(RST), .IN(IN), .OUT(OUT));
endmodule

module SUBSUBSUBSUB (CLK, RST, IN, OUT);
  parameter ID = 0;
  input CLK, RST;
  input [31:0] IN;
  output [31:0] OUT;
  SUBSUBSUBSUBSUB #(.ID(ID))
  inst (.CLK(CLK), .RST(RST), .IN(IN), .OUT(OUT));
endmodule



module SUBSUBSUBSUBSUB (CLK, RST, IN, OUT);
  parameter ID = 0;
  input CLK, RST;
  input [31:0] IN;
  output [31:0] OUT;

  reg [9:0] mem_addr;
  reg mem_we;
  reg [31:0] d_IN;

  always @(posedge CLK) begin
    if(RST) begin
      d_IN <= 0;
      mem_we <= 0;
      mem_addr <= 0;
    end else begin
      d_IN <= IN;
      mem_we <= 0;
      if(d_IN != IN) begin
        mem_addr <= mem_addr + 1;
        mem_we <= 1;
      end
    end
  end

  CoramMemory1P
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(ID),
    .CORAM_ADDR_LEN(10),
    .CORAM_DATA_WIDTH(32)
    )
  inst_data_memory
  (.CLK(CLK),
   .ADDR(mem_addr),
   .D(IN),
   .WE(mem_we),
   .Q(OUT)
   );

endmodule

