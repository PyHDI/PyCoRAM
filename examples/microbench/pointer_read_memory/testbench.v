parameter num_entries = 1024;
parameter __SIMD_WIDTH = 1;
parameter __DSIZE = 4;
  
parameter mem_offset = 0;
parameter dma_size = 256;
parameter data_size = 16 * 1024;

//------------------------------------------------------------------------------
reg [31:0] t;
reg [31:0] __x;
reg [31:0] __y;
reg [31:0] __z;
reg [31:0] __w;

initial begin
  __x = 123456789;
  __y = 362436069;
  __z = 521288629;
  __w = 88675123;
end

task update_xorshift;
  begin
    t = __x ^ (__x << 11);
    __x = __y;
    __y = __z;
    __z = __w;
    __w = (__w ^ (__w >> 19)) ^ (t ^ (t >> 8));
  end
endtask    

task reset_xorshift;
  begin
    __x = 123456789;
    __y = 362436069;
    __z = 521288629;
    __w = 88675123;
  end
endtask
  
//------------------------------------------------------------------------------
reg [31:0] address;
reg [31:0] next_address;
reg [31:0] write_data;
integer i, j, p;

task write_mem;
  input [31:0] addr;
  input [31:0] data;
  integer p;
  begin
    {inst_dram_stub.memory[addr+3],
     inst_dram_stub.memory[addr+2],
     inst_dram_stub.memory[addr+1],
     inst_dram_stub.memory[addr+0]} = data;
  end
endtask    
  
initial begin
  for(i=0; i<num_entries; i=i+1) begin
    address = mem_offset + (i * dma_size * __DSIZE * __SIMD_WIDTH);
    next_address = mem_offset + (__w % num_entries) * dma_size * __DSIZE * __SIMD_WIDTH;
    update_xorshift();
    write_mem(address, next_address);
    for(j=1; j<dma_size*__SIMD_WIDTH; j=j+1) begin
      address = mem_offset + (i * dma_size * __DSIZE * __SIMD_WIDTH) + (j * __DSIZE);
      write_mem(address, 'h0000_ffff);
    end
  end
end

//------------------------------------------------------------------------------  
reg [31:0] read_val;
  
initial begin
  #1000;
  wait(sim_resetn == 1);
  nclk();
  $display("write mem_offset");
  iochannel_write_cthread_pointer_read_memory_coramiochannel_0(mem_offset, 0);
  
  nclk();
  $display("write dma_size");
  iochannel_write_cthread_pointer_read_memory_coramiochannel_0(dma_size, 0);
  
  nclk();
  $display("write data_size");
  iochannel_write_cthread_pointer_read_memory_coramiochannel_0(data_size, 0);
  
  nclk();
  iochannel_read_cthread_pointer_read_memory_coramiochannel_0(read_val, 0);
  nclk();
  $display("iochannel cyclecount=%d", read_val);
  #1000;
  $finish;
end
