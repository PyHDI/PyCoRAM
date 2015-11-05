reg [31:0] read_val;

integer c;

initial begin
  #1000;
  wait(sim_resetn == 1);
  nclk();
  
  $display("write");
  ioregister_write_ctrl_thread_coramioregister_0(1, 0);
  nclk();

  read_val = 1;
  while(read_val > 0) begin
    ioregister_read_ctrl_thread_coramioregister_0(read_val, 0);
    nclk();
  end
  
  $display("read");
  ioregister_read_ctrl_thread_coramioregister_0(read_val, 4);
  nclk();
  $display("ioregister read_val=%d", read_val);
  
  #10000;
  $finish;
end
