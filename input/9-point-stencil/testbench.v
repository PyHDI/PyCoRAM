reg _exec_start;
reg [31:0] _mesh_size;
reg [31:0] _num_iter;
reg [31:0] _iter;

assign exec_start = _exec_start;
assign mesh_size = _mesh_size;
assign num_iter = _num_iter;

initial begin
  _exec_start = 0;
  _mesh_size = 96;
  _num_iter = 200;
  #1000;
  _exec_start = 1;
  #100;
  _exec_start = 0;

  wait(exec_done);
  #100;
  $finish;
end
