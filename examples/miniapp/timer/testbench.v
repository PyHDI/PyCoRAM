reg [31:0] start_val;
reg [31:0] finish_val;

integer wait_count;

initial begin
  #1000;
  wait(sim_resetn == 1);
  nclk();

  for(wait_count=0; wait_count<4096; wait_count=wait_count+1) begin
    nclk();
  end
  
  ioregister_read_cthread_timer_coramioregister_0(start_val, 0);
  nclk();
  $display("start_time = %d", start_val);

  for(wait_count=0; wait_count<4096; wait_count=wait_count+1) begin
    nclk();
  end
  
  ioregister_read_cthread_timer_coramioregister_0(finish_val, 0);
  nclk();
  $display("finish_time = %d", finish_val);
  $display("cycle_count = %d", finish_val - start_val);
  #1000;
  
  $finish;
end
