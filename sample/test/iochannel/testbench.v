reg [31:0] read_val;

initial begin
  #1000;
  wait(sim_resetn == 1);
  nclk();
  $display("write");
  iochannel_write_ctrl_thread_coramiochannel_0(1, 0);
  nclk();

  // Polling
  read_val = 1;
  while(read_val) begin
    $display("read status");
    iochannel_read_ctrl_thread_coramiochannel_0(read_val, 4);
    nclk();
    $display("status=%d", read_val);
    nclk();
  end
  
  $display("read");
  iochannel_read_ctrl_thread_coramiochannel_0(read_val, 0);
  nclk();
  $display("value=%d", read_val);
  #1000;
  $finish;
end
