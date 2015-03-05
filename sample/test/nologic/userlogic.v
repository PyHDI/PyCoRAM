`include "pycoram.v"

`define THREAD_NAME "ctrl_thread"

module userlogic
  (
   input CLK,
   input RST
   );

  reg [31:0] counter;

  always @(posedge CLK) begin
    if(RST) begin
      counter <= 0;
    end else begin
      counter <= counter + 1;
    end
  end
  
endmodule
  
