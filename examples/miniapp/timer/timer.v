`include "pycoram.v"

`define THREAD_NAME "cthread_timer"

module userlogic #  
  (
   parameter W_A = 10,
   parameter W_COMM_A = 4,
   parameter W_D = 32,
   parameter SIZE = 128
   )
  (
   input CLK,
   input RST
   );

  wire [W_D-1:0] comm_d;
  wire           comm_we;
  wire [W_D-1:0] comm_q;

  reg [W_D-1:0] cycle_counter;
  
  always @(posedge CLK) begin
    if(RST) begin
      cycle_counter <= 0;
    end else begin
      cycle_counter <= cycle_counter + 1;
    end
  end

  assign comm_d = cycle_counter;
  assign comm_we = 1;
  
  CoramRegister
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(0),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_comm_register
  (.CLK(CLK),
   .D(comm_d),
   .WE(comm_we),
   .Q(comm_q)
   );
  
endmodule

