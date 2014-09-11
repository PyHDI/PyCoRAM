wire CLK;
wire RST;
assign CLK = sim_clk;
assign RST = !sim_resetn;

reg [7:0] uart_tx_data;
reg uart_tx_we;
wire uart_tx_txd;
wire uart_tx_ready;

assign USB_1_TX = uart_tx_txd;

UartTx #
 (
  .SYS_CLK_FREQ(SYS_CLK_FREQ),
  .BAUDRATE(BAUDRATE)
 )
inst_uart_tx
 (
  .CLK(CLK),
  .RST(RST),
  .DATA(uart_tx_data),
  .WE(uart_tx_we),
  .TXD(uart_tx_txd),
  .READY(uart_tx_ready)
 );

initial begin
  uart_tx_we = 0;
  uart_tx_data = 0;
  #1000;
  wait(RST == 0);
  #100;
  nclk();

  uart_tx_data = 'h1;
  uart_tx_we = 1;
  nclk();
  wait(uart_tx_ready == 0);
  uart_tx_we = 0;
  nclk();
  wait(uart_tx_ready == 1);
  nclk();
  
  uart_tx_data = 'h0;
  uart_tx_we = 1;
  nclk();
  wait(uart_tx_ready == 0);
  uart_tx_we = 0;
  nclk();
  wait(uart_tx_ready == 1);
  nclk();
  
  uart_tx_data = 'h0;
  uart_tx_we = 1;
  nclk();
  wait(uart_tx_ready == 0);
  uart_tx_we = 0;
  nclk();
  wait(uart_tx_ready == 1);
  nclk();
  
  uart_tx_data = 'h0;
  uart_tx_we = 1;
  nclk();
  wait(uart_tx_ready == 0);
  uart_tx_we = 0;
  nclk();
  wait(uart_tx_ready == 1);
  nclk();

  wait(inst_uut.inst_userlogic.state == 'h28);
  wait(inst_uut.inst_userlogic.state == 'h0);
  #1000;

  
  uart_tx_data = 'h3;
  uart_tx_we = 1;
  nclk();
  wait(uart_tx_ready == 0);
  uart_tx_we = 0;
  nclk();
  wait(uart_tx_ready == 1);
  nclk();
  
  uart_tx_data = 'h0;
  uart_tx_we = 1;
  nclk();
  wait(uart_tx_ready == 0);
  uart_tx_we = 0;
  nclk();
  wait(uart_tx_ready == 1);
  nclk();
  
  uart_tx_data = 'h0;
  uart_tx_we = 1;
  nclk();
  wait(uart_tx_ready == 0);
  uart_tx_we = 0;
  nclk();
  wait(uart_tx_ready == 1);
  nclk();
  
  uart_tx_data = 'h0;
  uart_tx_we = 1;
  nclk();
  wait(uart_tx_ready == 0);
  uart_tx_we = 0;
  nclk();
  wait(uart_tx_ready == 1);
  nclk();

  wait(inst_uut.inst_userlogic.state == 'h28);
  wait(inst_uut.inst_userlogic.state == 'h0);
  #1000;
  
  uart_tx_data = 'h5;
  uart_tx_we = 1;
  nclk();
  wait(uart_tx_ready == 0);
  uart_tx_we = 0;
  nclk();
  wait(uart_tx_ready == 1);
  nclk();
  
  uart_tx_data = 'h0;
  uart_tx_we = 1;
  nclk();
  wait(uart_tx_ready == 0);
  uart_tx_we = 0;
  nclk();
  wait(uart_tx_ready == 1);
  nclk();
  
  uart_tx_data = 'h0;
  uart_tx_we = 1;
  nclk();
  wait(uart_tx_ready == 0);
  uart_tx_we = 0;
  nclk();
  wait(uart_tx_ready == 1);
  nclk();
  
  uart_tx_data = 'h0;
  uart_tx_we = 1;
  nclk();
  wait(uart_tx_ready == 0);
  uart_tx_we = 0;
  nclk();
  wait(uart_tx_ready == 1);
  nclk();

  wait(inst_uut.inst_userlogic.state == 'h28);
  wait(inst_uut.inst_userlogic.state == 'h0);
  #1000;

  
  $finish;
  
end
