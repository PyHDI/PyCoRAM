reg [31:0] read_val;

initial begin
  #1000;
  wait(sim_resetn == 1);
  nclk();
  $display("write");
  iochannel_write_cthread_mm_coramiochannel_0(256 * 1024, 0);
  iochannel_write_cthread_mm_coramiochannel_0(208, 0);
  nclk();
  $display("read");
  iochannel_read_cthread_mm_coramiochannel_0(read_val, 0);
  nclk();
  $display("iochannel read_val=%d", read_val);
  #1000;
  $finish;
end
