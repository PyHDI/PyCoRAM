reg _exec_start;
reg [31:0] _matrix_size;
assign exec_start = _exec_start;
assign matrix_size = _matrix_size;

initial begin
  _exec_start = 0;
  _matrix_size = 208;
  #1000;
  _exec_start = 1;
  #100;
  _exec_start = 0;

  wait(exec_done);
  #100;
  $finish;
end
