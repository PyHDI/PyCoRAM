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

reg [7:0] init_data [0:4*1024*1024-1];
integer fp, c, addr;

parameter SIZE = 128;

//parameter SIZE = 512 * 1024;
/* -----\/----- EXCLUDED -----\/-----
parameter BIN_FILE = "320mm_hw512.bin";
initial begin
  fp = $fopen(BIN_FILE, "rb");
  c = $fread(init_data, fp);
end
 -----/\----- EXCLUDED -----/\----- */

reg [31:0] iochannel_read_val;
  
initial begin
  uart_tx_we = 0;
  uart_tx_data = 0;
  #1000;
  wait(sim_resetn == 1);

  #100000;
  
  for(addr=0; addr<SIZE; addr=addr+1) begin
/* -----\/----- EXCLUDED -----\/-----
    uart_tx_data = init_data[addr];
 -----/\----- EXCLUDED -----/\----- */
    uart_tx_data = addr;
    uart_tx_we = 1;
/* -----\/----- EXCLUDED -----\/-----
    $display("uart_tx_data=%x, init_data[%d]=%x", uart_tx_data, addr, init_data[addr]);
 -----/\----- EXCLUDED -----/\----- */
    //$display("uart_tx_data=%x", uart_tx_data);
    nclk();
    wait(uart_tx_ready == 0);
    uart_tx_we = 0;
    nclk();
    wait(uart_tx_ready == 1);
    nclk();
  end
  
  $display("program transferred");
end
  
initial begin
  #1000;
  wait(sim_resetn == 1);

  nclk();

  $display("offset");
  iochannel_write_cthread_recv_coramiochannel_0('h1000, 0);
  nclk();
  $display("size");
  iochannel_write_cthread_recv_coramiochannel_0(SIZE, 0);
  nclk();
  iochannel_read_cthread_recv_coramiochannel_0(iochannel_read_val, 0);
  nclk();
  $display("iochannel read_val=%d", iochannel_read_val);
  
  iochannel_write_cthread_send_coramiochannel_0('h41, 0); // 'A'
  nclk();
  
  #100000;
  $finish;
end
  
initial begin
  while(1) begin
    wait(uart_rx_en == 1'b1);
    $write("%c", uart_rx_data);
    nclk();
  end
end

reg _INIT_X_IN;
assign INIT_X_IN = _INIT_X_IN;  
initial begin
  _INIT_X_IN = 1;
  #100;
  _INIT_X_IN = 0;
  #100;
  _INIT_X_IN = 1;
end

