//parameter mesh_size = 96;
//parameter iter_num = 200;
parameter mesh_size = 32 * 2;
parameter iter_num = 2 * 2;
parameter a_offset = 1 * 1024 * 1024;
parameter b_offset = 2 * 1024 * 1024;

parameter data_offset = 256 * 1024;
parameter loader_size = 64 * 1024;

integer x, y, d;
initial begin
  d = 0;
  for(y=0; y<mesh_size; y=y+1) begin
    for(x=0; x<mesh_size; x=x+1) begin
      {inst_dram_stub.memory[a_offset + (mesh_size * y + x) * 4 + 3],
       inst_dram_stub.memory[a_offset + (mesh_size * y + x) * 4 + 2],
       inst_dram_stub.memory[a_offset + (mesh_size * y + x) * 4 + 1],
       inst_dram_stub.memory[a_offset + (mesh_size * y + x) * 4 + 0]} =
          {inst_dram_stub.memory[data_offset + (d % loader_size) * 4 + 3],
           inst_dram_stub.memory[data_offset + (d % loader_size) * 4 + 2],
           inst_dram_stub.memory[data_offset + (d % loader_size) * 4 + 1],
           inst_dram_stub.memory[data_offset + (d % loader_size) * 4 + 0]};
      {inst_dram_stub.memory[b_offset + (mesh_size * y + x) * 4 + 3],
       inst_dram_stub.memory[b_offset + (mesh_size * y + x) * 4 + 2],
       inst_dram_stub.memory[b_offset + (mesh_size * y + x) * 4 + 1],
       inst_dram_stub.memory[b_offset + (mesh_size * y + x) * 4 + 0]} = 0;
      d = d + 1;
    end
  end
end

reg [31:0] read_val;

initial begin
  #1000;
  wait(sim_resetn == 1);
  nclk();
  $display("write");
  iochannel_write_cthread_st_coramiochannel_0(mesh_size, 0);
  iochannel_write_cthread_st_coramiochannel_0(iter_num, 0);
  iochannel_write_cthread_st_coramiochannel_0(a_offset, 0);
  iochannel_write_cthread_st_coramiochannel_0(b_offset, 0);
  nclk();
  $display("read");
  iochannel_read_cthread_st_coramiochannel_0(read_val, 0);
  nclk();
  $display("iochannel read_val=%d", read_val);
  nclk();
  iochannel_read_cthread_st_coramiochannel_0(read_val, 0);
  nclk();
  $display("iochannel read_val=%d", read_val);
  #1000;
  $finish;
end
  
