`include "pycoram.v"

`define RECV_THREAD_NAME "cthread_recv"
`define SEND_THREAD_NAME "cthread_send"

//`define SYS_CLK_FREQ 100
`define SYS_CLK_FREQ 50

//`define BAUDRATE 921600
`define BAUDRATE 1000000
//`define BAUDRATE 50000000 // simulation

module loader #
  (
   parameter SYS_CLK_FREQ = `SYS_CLK_FREQ,
   parameter BAUDRATE = `BAUDRATE,
   parameter W_D = 32,
   parameter W_COMM_A = 4
   )
  (
   input CLK,
   input RST,

   output USB_1_CTS, //= UART RTS
   input  USB_1_RTS, //= UART CTS
   output USB_1_RX,  //= UART_TX
   input  USB_1_TX,   //= UART_RX

   output reg [7:0] led,

   input INIT_X_IN,
   output FLUSH_X
   );

  reg [11:0] flush_count;
  assign FLUSH_X = flush_count[11];

  always @(posedge CLK) begin
    if(RST) begin
      flush_count <= 0;
    end else begin
      if(!INIT_X_IN) flush_count <= 0;
      else if(!FLUSH_X) flush_count <= flush_count + 1;
    end
  end
  
  wire [7:0] uart_tx_data;
  wire uart_tx_en;
  wire uart_tx_ready;
  wire uart_txd;

  wire [7:0] uart_rx_data;
  wire uart_rx_en;
  wire uart_rxd;

  wire [7:0] send_data;
  wire send_enable;
  wire send_ready;
  
  wire [7:0] recv_data;
  wire recv_enable;
  
  assign USB_1_RX = uart_txd;
  assign USB_1_CTS = 0;
  assign uart_rxd = USB_1_TX;
  
  assign recv_data = uart_rx_data;
  assign recv_enable = uart_rx_en;

  assign send_ready = uart_tx_ready;
  assign uart_tx_en = send_enable;
  assign uart_tx_data = send_data;

  reg [26:0] count;
  always @(posedge CLK) begin
    if(RST) begin
      count <= 0;
    end else begin
      count <= count + 1;
    end
  end
  
  //------------------------------------------------------------------------------
  always @(posedge CLK) begin
    led[0] <= uart_rxd;
    led[1] <= uart_rx_en;
    led[2] <= uart_txd;
    led[3] <= uart_tx_en;
    led[4] <= uart_tx_ready;
    led[5] <= RST;
    led[6] <= count[25];
    led[7] <= count[26];
  end
  
  //------------------------------------------------------------------------------
  uart_loader #
  (
   .W_D(W_D)
   )
  inst_uart_loader
  (
   .CLK(CLK),
   .RST(RST),
   .recv_data(recv_data),
   .recv_enable(recv_enable)
   );

  uart_sender #
  (
   .W_D(W_D),
   .W_COMM_A(W_COMM_A)
   )
  inst_uart_sender
  (
   .CLK(CLK),
   .RST(RST),
   .send_data(send_data),
   .send_enable(send_enable),
   .send_ready(send_ready)
   );

  //------------------------------------------------------------------------------
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
   .WE(uart_tx_en),
   .TXD(uart_txd),
   .READY(uart_tx_ready)
   );
  
  UartRx #
  (
   .SYS_CLK_FREQ(SYS_CLK_FREQ),
   .BAUDRATE(BAUDRATE)
   )
  inst_uart_rx
  (
   .CLK(CLK), 
   .RST(RST), 
   .RXD(uart_rxd),
   .DATA(uart_rx_data),
   .EN(uart_rx_en)
   );
  
endmodule

//------------------------------------------------------------------------------
module uart_loader #
  (
   parameter W_D = 32,
   parameter W_INIT_A = 3,
   parameter W_COMM_A = 4
   )
  (
   input CLK,
   input RST,
   input [7:0] recv_data,
   input recv_enable
   );

  reg [7:0] state;
  
  reg [W_D-1:0] byte_count;
  reg [W_INIT_A-1:0] mem_addr;
  reg [W_D-1:0] mem_d;
  reg mem_we;

  reg [W_D-1:0] comm_d;
  reg comm_enq;
  wire comm_full;
  wire [W_D-1:0] comm_q;
  reg comm_deq;
  wire comm_empty;

  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      comm_enq <= 0;
      comm_deq <= 0;
      comm_d <= 0;
      mem_we <= 0;
      mem_d <= 0;
      mem_addr <= 2 ** W_INIT_A - 1;
      byte_count <= 0;
    end else begin
      comm_enq <= 0;
      comm_deq <= 0;
      mem_we <= 0;
      
      case(state)
        'h0: begin
          byte_count <= 0;
          mem_addr <= 2 ** W_INIT_A - 1;
          state <= 'h1;
        end
        'h1: begin
          if(recv_enable) begin
            mem_d <= {recv_data, mem_d[31:8]};
            byte_count <= byte_count + 1;
            if(byte_count == 3) begin
              byte_count <= 0;
              mem_we <= 1;
              mem_addr <= mem_addr + 1;
              if(mem_addr == 2 ** W_INIT_A - 2) begin
                state <= 'h2;
              end
            end
          end
        end
        'h2: begin
          comm_d <= 0;
          if(!comm_full) begin
            comm_enq <= 1;
            state <= 'h0;
          end
        end
      endcase
    end
  end

  CoramMemory1P # 
    (
     .CORAM_THREAD_NAME(`RECV_THREAD_NAME),
     .CORAM_ID(0),
     .CORAM_SUB_ID(0),
     .CORAM_ADDR_LEN(W_INIT_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_mem
    (
     .CLK(CLK),
     .ADDR(mem_addr),
     .D(mem_d),
     .WE(mem_we),
     .Q()
     );
  
  CoramChannel #
    (
     .CORAM_THREAD_NAME(`RECV_THREAD_NAME),
     .CORAM_ID(0),
     .CORAM_ADDR_LEN(W_COMM_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_channel
    (
     .CLK(CLK),
     .RST(RST),
     .D(comm_d),
     .ENQ(comm_enq),
     .FULL(comm_full),
     .Q(comm_q),
     .DEQ(comm_deq),
     .EMPTY(comm_empty)
     );
endmodule

//------------------------------------------------------------------------------
module uart_sender #
  (
   parameter W_D = 32,
   parameter W_COMM_A = 4
   )
  (
   input CLK,
   input RST,
   output reg [7:0] send_data,
   output reg send_enable,
   input send_ready
   );

  reg [7:0] state;
  
  reg [W_D-1:0] comm_d;
  reg comm_enq;
  wire comm_full;
  wire [W_D-1:0] comm_q;
  reg comm_deq;
  wire comm_empty;

  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      comm_enq <= 0;
      comm_deq <= 0;
      comm_d <= 0;
      send_enable <= 0;
    end else begin
      comm_enq <= 0;
      comm_deq <= 0;
      send_enable <= 0;
      case(state)
        'h0: begin
          if(send_ready && !comm_empty) begin
            comm_deq <= 1;
            state <= 'h1;
          end
        end
        'h1: begin
          state <= 'h2;
        end
        'h2: begin
          send_data <= comm_q[7:0];
          send_enable <= 1;
          state <= 'h3;
        end
        'h3: begin
          if(!comm_full) begin
            comm_d <= 1;
            comm_enq <= 1;
            state <= 'h0;
          end            
        end
      endcase
    end
  end

  CoramChannel #
    (
     .CORAM_THREAD_NAME(`SEND_THREAD_NAME),
     .CORAM_ID(0),
     .CORAM_ADDR_LEN(W_COMM_A),
     .CORAM_DATA_WIDTH(W_D)
     )
  inst_channel
    (
     .CLK(CLK),
     .RST(RST),
     .D(comm_d),
     .ENQ(comm_enq),
     .FULL(comm_full),
     .Q(comm_q),
     .DEQ(comm_deq),
     .EMPTY(comm_empty)
     );
endmodule

//------------------------------------------------------------------------------  
module UartTx #
  (
   parameter SYS_CLK_FREQ = 200,
   parameter BAUDRATE = 1000000
   )
  (
   input CLK,
   input RST,
   input [7:0] DATA,
   input WE,
   output reg TXD,
   output reg READY
   );
  reg [8:0] mem;
  reg [3:0] cnt;
  
  reg [32:0] waitnum;
  localparam SERIAL_WCNT = SYS_CLK_FREQ * 1000000 / BAUDRATE;
  
  always @ (posedge CLK) begin
    if(RST) begin
      mem           <= 9'h1ff;
      waitnum       <= 1;
      READY         <= 1'b1; //no busy
      TXD           <= 1'b1;
      cnt           <= 0;
    end else if( READY ) begin
      TXD       <= 1'b1;
      waitnum   <= 1;
      if(WE)begin
        mem   <= {DATA, 1'b0};
        READY <= 1'b0;
        cnt   <= 10;
      end
    end else if( waitnum >= SERIAL_WCNT ) begin //busy
      TXD       <= mem[0];
      mem       <= {1'b1, mem[8:1]};
      waitnum   <= 1;
      cnt       <= cnt - 1;
      if(cnt <= 0) begin //finish
        READY <= 1'b1;
      end
    end else begin
      waitnum   <= waitnum +1;
    end
  end
endmodule

module UartRx #
  (
   parameter SYS_CLK_FREQ = 200,
   parameter BAUDRATE = 1000000
   )
  (
   input CLK, RST, RXD,
   output reg [7:0] DATA,
   output reg EN
   );
  
  reg    [3:0]   stage;
  reg    [32:0]  cnt;             // counter to latch D0, D1, ..., D7
  reg    [32:0]  cnt_start;       // counter to detect the Start Bit
  localparam SERIAL_WCNT = SYS_CLK_FREQ * 1000000 / BAUDRATE;
  
  localparam SS_SER_WAIT = 'd0; // RS232C deserializer, State WAIT
  localparam SS_SER_RCV0 = 'd1; // RS232C deserializer, State Receive 0th bit
  // States Receive 1st bit to 7th bit are not used
  localparam SS_SER_DONE = 'd9; // RS232C deserializer, State DONE
  
  always @(posedge CLK)
    if (RST) cnt_start <= 0;
    else        cnt_start <= (RXD) ? 0 : cnt_start + 1;
  
  always @(posedge CLK)
    if(RST) begin
      EN     <= 0;
      stage  <= SS_SER_WAIT;
      cnt    <= 1;
      DATA   <= 0;
    end else if (stage == SS_SER_WAIT) begin // detect the Start Bit
      EN <= 0;
      stage <= (cnt_start == (SERIAL_WCNT >> 1)) ? SS_SER_RCV0 : stage;
    end else begin
      if (cnt != SERIAL_WCNT) begin
        cnt <= cnt + 1;
        EN <= 0;
      end else begin               // receive 1bit data
        stage  <= (stage == SS_SER_DONE) ? SS_SER_WAIT : stage + 1;
        EN     <= (stage == 8)  ? 1 : 0;
        DATA   <= {RXD, DATA[7:1]};
        cnt <= 1;
      end
    end
endmodule 

