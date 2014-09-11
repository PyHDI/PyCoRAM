reg [31:0] read_val;

integer c;

initial begin
  #1000;
  wait(sim_resetn == 1);
  nclk();
  $display("write");
  ioregister_write_ctrl_thread_coramioregister_0(1, 0);
  nclk();

  for(c=0; c<1024*8; c=c+1) begin
    nclk();
  end
  
  $display("read");
  ioregister_read_ctrl_thread_coramioregister_0(read_val, 0);
  nclk();
  $display("ioregister read_val=%d", read_val);
  #10000;
  $finish;
end
