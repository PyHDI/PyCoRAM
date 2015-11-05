
reg [7:0] uart_tx_data;
reg uart_tx_we;
wire uart_tx_txd;
wire uart_tx_ready;

wire [7:0] uart_rx_data;
wire uart_rx_rxd;
wire uart_rx_en;

reg [63:0] exec_time;
reg [63:0] return_value;

assign USB_1_TX = uart_tx_txd;
assign uart_rx_rxd = USB_1_RX;

UartTx #
 (
  .SYS_CLK_FREQ(SYS_CLK_FREQ),
  .BAUDRATE(BAUDRATE)
 )
inst_uart_tx
 (
  .CLK(sim_clk),
  .RST(!sim_resetn),
  .DATA(uart_tx_data),
  .WE(uart_tx_we),
  .TXD(uart_tx_txd),
  .READY(uart_tx_ready)
 );

UartRx #
(
 .SYS_CLK_FREQ(SYS_CLK_FREQ),
 .BAUDRATE(BAUDRATE)
 )
inst_uart_rx
 (
  .CLK(sim_clk),
  .RST(!sim_resetn),
  .RXD(uart_rx_rxd),
  .DATA(uart_rx_data),
  .EN(uart_rx_en)
  );

initial begin
  uart_tx_we = 0;
  uart_tx_data = 0;
  #1000;
  wait(sim_resetn == 1);
  #100;
  nclk();

  //uart_tx_data = 'h0;
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

  
  wait(uart_rx_en == 1'b1);
  return_value = {uart_rx_data, return_value[63:8]};
  nclk();
  
  wait(uart_rx_en == 1'b1);
  return_value = {uart_rx_data, return_value[63:8]};
  nclk();

  wait(uart_rx_en == 1'b1);
  return_value = {uart_rx_data, return_value[63:8]};
  nclk();

  wait(uart_rx_en == 1'b1);
  return_value = {uart_rx_data, return_value[63:8]};
  nclk();

  wait(uart_rx_en == 1'b1);
  return_value = {uart_rx_data, return_value[63:8]};
  nclk();

  wait(uart_rx_en == 1'b1);
  return_value = {uart_rx_data, return_value[63:8]};
  nclk();

  wait(uart_rx_en == 1'b1);
  return_value = {uart_rx_data, return_value[63:8]};
  nclk();

  wait(uart_rx_en == 1'b1);
  return_value = {uart_rx_data, return_value[63:8]};
  nclk();

  
  wait(uart_rx_en == 1'b1);
  exec_time = {uart_rx_data, exec_time[63:8]};
  nclk();
  
  wait(uart_rx_en == 1'b1);
  exec_time = {uart_rx_data, exec_time[63:8]};
  nclk();

  wait(uart_rx_en == 1'b1);
  exec_time = {uart_rx_data, exec_time[63:8]};
  nclk();

  wait(uart_rx_en == 1'b1);
  exec_time = {uart_rx_data, exec_time[63:8]};
  nclk();

  wait(uart_rx_en == 1'b1);
  exec_time = {uart_rx_data, exec_time[63:8]};
  nclk();

  wait(uart_rx_en == 1'b1);
  exec_time = {uart_rx_data, exec_time[63:8]};
  nclk();

  wait(uart_rx_en == 1'b1);
  exec_time = {uart_rx_data, exec_time[63:8]};
  nclk();

  wait(uart_rx_en == 1'b1);
  exec_time = {uart_rx_data, exec_time[63:8]};
  nclk();

  $display("return_value=%d", return_value);
  $display("exec_time=%d", exec_time);
  $finish;
end
