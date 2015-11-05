reg [31:0] read_val;

initial begin
  #1000;
  wait(sim_resetn == 1);
  nclk();
  iochannel_write_ctrl_thread_coramiochannel_0(0, 0); // src
  iochannel_write_ctrl_thread_coramiochannel_0(1024, 0); // dst
  iochannel_write_ctrl_thread_coramiochannel_0(128, 0); // size (byte)
  nclk();
  iochannel_read_ctrl_thread_coramiochannel_0(read_val, 0);
  nclk();
  #1000;
  
  nclk();
  iochannel_write_ctrl_thread_coramiochannel_0(0, 0); // src
  iochannel_write_ctrl_thread_coramiochannel_0(8192, 0); // dst
  iochannel_write_ctrl_thread_coramiochannel_0(8192, 0); // size (byte)
  nclk();
  iochannel_read_ctrl_thread_coramiochannel_0(read_val, 0);
  nclk();
  #1000;
  $finish;
end
