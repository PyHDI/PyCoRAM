//parameter matrix_size = 208;
parameter matrix_size = 16 * 4;
parameter a_offset = 1 * 1024 * 1024;
parameter b_offset = 2 * 1024 * 1024;
parameter c_offset = 3 * 1024 * 1024;

parameter data_offset = 256 * 1024;
parameter loader_size = 64 * 1024;

integer x, y, d;
initial begin
  d = 0;
  for(y=0; y<matrix_size; y=y+1) begin
    for(x=0; x<matrix_size; x=x+1) begin
      {inst_dram_stub.memory[a_offset + (matrix_size * y + x) * 4 + 3],
       inst_dram_stub.memory[a_offset + (matrix_size * y + x) * 4 + 2],
       inst_dram_stub.memory[a_offset + (matrix_size * y + x) * 4 + 1],
       inst_dram_stub.memory[a_offset + (matrix_size * y + x) * 4 + 0]} =
          {inst_dram_stub.memory[data_offset + (d % loader_size) * 4 + 3],
           inst_dram_stub.memory[data_offset + (d % loader_size) * 4 + 2],
           inst_dram_stub.memory[data_offset + (d % loader_size) * 4 + 1],
           inst_dram_stub.memory[data_offset + (d % loader_size) * 4 + 0]};
      {inst_dram_stub.memory[b_offset + (matrix_size * x + y) * 4 + 3],
       inst_dram_stub.memory[b_offset + (matrix_size * x + y) * 4 + 2],
       inst_dram_stub.memory[b_offset + (matrix_size * x + y) * 4 + 1],
       inst_dram_stub.memory[b_offset + (matrix_size * x + y) * 4 + 0]} =
          {inst_dram_stub.memory[data_offset + ((d + 1) % loader_size) * 4 + 3],
           inst_dram_stub.memory[data_offset + ((d + 1) % loader_size) * 4 + 2],
           inst_dram_stub.memory[data_offset + ((d + 1) % loader_size) * 4 + 1],
           inst_dram_stub.memory[data_offset + ((d + 1) % loader_size) * 4 + 0]};
      {inst_dram_stub.memory[c_offset + (matrix_size * y + x) * 4 + 3],
       inst_dram_stub.memory[c_offset + (matrix_size * y + x) * 4 + 2],
       inst_dram_stub.memory[c_offset + (matrix_size * y + x) * 4 + 1],
       inst_dram_stub.memory[c_offset + (matrix_size * y + x) * 4 + 0]} = 0;
      d = d + 2;
    end
  end
end

reg [31:0] read_val;

initial begin
  #1000;
  wait(sim_resetn == 1);
  nclk();
  $display("write");
  iochannel_write_cthread_mm_coramiochannel_0(matrix_size, 0);
  iochannel_write_cthread_mm_coramiochannel_0(a_offset, 0);
  iochannel_write_cthread_mm_coramiochannel_0(b_offset, 0);
  iochannel_write_cthread_mm_coramiochannel_0(c_offset, 0);
  nclk();
  $display("read");
  iochannel_read_cthread_mm_coramiochannel_0(read_val, 0);
  nclk();
  $display("iochannel read_val=%x", read_val);
  #1000;
  $finish;
end
