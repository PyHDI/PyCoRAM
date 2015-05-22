parameter START_ID = 1826;
parameter GOAL_ID = 217;

//parameter START_ID = 1056;
//parameter GOAL_ID = 674;

//parameter START_ID = 0;
//parameter GOAL_ID = 1;

/* -----\/----- EXCLUDED -----\/-----
// 1MB (default)
parameter PAGE_OFFSET = 'h000100;
parameter NODE_OFFSET = 'h040000;
parameter IDTB_OFFSET = 'h080000;
parameter ADTB_OFFSET = 'h090000;
parameter HEAP_OFFSET = 'h100000;
 -----/\----- EXCLUDED -----/\----- */

// 128MB
parameter PAGE_OFFSET = 'h0000100;
parameter NODE_OFFSET = 'h6000000;
parameter IDTB_OFFSET = 'h7000000;
parameter ADTB_OFFSET = 'h7400000;
parameter HEAP_OFFSET = 'h7800000;

parameter DATA_WIDTH = 32;

reg [DATA_WIDTH-1:0] cost;
reg [DATA_WIDTH-1:0] cycles;

reg [DATA_WIDTH-1:0] start_addr;
reg [DATA_WIDTH-1:0] goal_addr;
reg [DATA_WIDTH-1:0] idtb_start_addr;
reg [DATA_WIDTH-1:0] idtb_goal_addr;
reg [DATA_WIDTH-1:0] idtb_start_id;
reg [DATA_WIDTH-1:0] idtb_goal_id;

initial begin
  start_addr = {inst_dram_stub.memory[(ADTB_OFFSET + START_ID * 4)+3],
                inst_dram_stub.memory[(ADTB_OFFSET + START_ID * 4)+2],
                inst_dram_stub.memory[(ADTB_OFFSET + START_ID * 4)+1],
                inst_dram_stub.memory[(ADTB_OFFSET + START_ID * 4)+0]};
  goal_addr = {inst_dram_stub.memory[(ADTB_OFFSET + GOAL_ID * 4)+3],
               inst_dram_stub.memory[(ADTB_OFFSET + GOAL_ID * 4)+2],
               inst_dram_stub.memory[(ADTB_OFFSET + GOAL_ID * 4)+1],
               inst_dram_stub.memory[(ADTB_OFFSET + GOAL_ID * 4)+0]};
  
  idtb_start_addr = (start_addr - NODE_OFFSET) / 4 + IDTB_OFFSET;
  idtb_goal_addr = (goal_addr - NODE_OFFSET) / 4 + IDTB_OFFSET;
  
  idtb_start_id = {inst_dram_stub.memory[idtb_start_addr + 3],
                   inst_dram_stub.memory[idtb_start_addr + 2],
                   inst_dram_stub.memory[idtb_start_addr + 1],
                   inst_dram_stub.memory[idtb_start_addr + 0]};
  idtb_goal_id = {inst_dram_stub.memory[idtb_goal_addr + 3],
                  inst_dram_stub.memory[idtb_goal_addr + 2],
                  inst_dram_stub.memory[idtb_goal_addr + 1],
                  inst_dram_stub.memory[idtb_goal_addr + 0]};

  $display("start ID:%x addr:%x", START_ID, start_addr);
  $display(" goal ID:%x addr:%x", GOAL_ID, goal_addr);
  $display("check start ID:%x addr:%x", idtb_start_id, idtb_start_addr);
  $display("check  goal ID:%x addr:%x", idtb_goal_id, idtb_goal_addr);

  #1000;
  wait(sim_resetn == 1);
  nclk();
  #1000;
  nclk();

  iochannel_write_cthread_dijkstra_coramiochannel_0(HEAP_OFFSET, 'h0); // heap offset
  iochannel_write_cthread_dijkstra_coramiochannel_0(start_addr, 'h4); // start_node_addr
  iochannel_write_cthread_dijkstra_coramiochannel_0(goal_addr, 'h8); // goal_node_addr

  iochannel_read_cthread_dijkstra_coramiochannel_0(cost,'h100); // get result
  iochannel_read_cthread_dijkstra_coramiochannel_0(cycles,'h100); // get cycle count
  
  $display("# cost = %d", cost);
  $display("# cycles = %d", cycles);
  
  #10000;
  $finish;
end
