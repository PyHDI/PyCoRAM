reg [31:0] read_val;

initial begin
  #1000;
  wait(sim_resetn == 1);
  
  nclk();
  iochannel_write_ctrl_thread_coramiochannel_0(42, 0);
  nclk();
  iochannel_read_ctrl_thread_coramiochannel_0(read_val, 0);
  nclk();
  $display("iochannel read_val=%d", read_val);

/* -----\/----- EXCLUDED -----\/-----
  nclk();
  iochannel_write_ctrl_thread_coramiochannel_0(20, 0);
  nclk();
  iochannel_read_ctrl_thread_coramiochannel_0(read_val, 0);
  nclk();
  $display("iochannel read_val=%d", read_val);
 -----/\----- EXCLUDED -----/\----- */

  #1000;
  $finish;
end
