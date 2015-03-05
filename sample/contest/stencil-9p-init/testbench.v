reg [31:0] read_val;

initial begin
  #1000;
  wait(sim_resetn == 1);
  nclk();
  $display("write");
  iochannel_write_cthread_st_coramiochannel_0(96, 0);
  iochannel_write_cthread_st_coramiochannel_0(200, 0);
  nclk();
  $display("read");
  iochannel_read_cthread_st_coramiochannel_0(read_val, 0);
  nclk();
  $display("iochannel read_val=%d", read_val);
  #1000;
  $finish;
end
  
