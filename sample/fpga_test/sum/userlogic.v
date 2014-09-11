`include "pycoram.v"
`define THREAD_NAME "ctrl_thread"

module userlogic #  
  (
   parameter W_A = 10,
   parameter W_D = 32,
   parameter SIZE = 128,
   parameter SYS_CLK_FREQ = 100,
   parameter BAUDRATE = 921600,
   parameter LED_WIDTH = 8
   )
  (
   input CLK,
   input RST,
   
   output USB_1_CTS, //= UART RTS
   input  USB_1_RTS, //= UART CTS
   output USB_1_RX,  //= UART_TX
   input  USB_1_TX,  //= UART_RX
   
   output reg [LED_WIDTH-1:0] led
   );

  reg [W_A-1:0] mem_addr;
  reg [W_D-1:0] mem_d;
  reg           mem_we;
  wire [W_D-1:0] mem_q;
  
  reg [W_D-1:0]  comm_d;
  reg            comm_enq;
  wire           comm_full;
  wire [W_D-1:0] comm_q;
  reg            comm_deq;
  wire           comm_empty;
  
  reg [7:0] state;

  localparam MAX_DONE_CNT = 1024 * 2;
  reg [31:0] maybe_done_cnt;
  reg maybe_done;
  reg [31:0] sum;
  reg [31:0] sum_buf;
  
  reg [7:0] uart_tx_data;
  reg  uart_tx_en;
  wire uart_tx_ready;
  wire uart_txd;

  wire [7:0] uart_rx_data;
  wire uart_rx_en;
  wire uart_rxd;

  reg [31:0] step;
  
  reg [7:0] uart_state;

  reg [26:0] led_count;
  always @(posedge CLK) begin
    if(RST) led_count <= 0;
    else led_count <= led_count + 1;
  end

  always @(posedge CLK) begin
    led <= (state == 'h0)? {led_count[26], sum[14:8]}:
           (state < 'h10)? {6'h0, led_count[23], 1'h0}:
           (state < 'h20)? {5'h0, led_count[23], 2'h0}:
           (state < 'h30)? {4'h0, led_count[23], 3'h0}:
           led_count[23:16];
  end
  
  assign USB_1_RX = uart_txd;
  assign USB_1_CTS = 0;
  assign uart_rxd = USB_1_TX;
  
  always @(posedge CLK) begin
    if(RST) begin
      state <= 'h0;
      mem_we <= 0;
      comm_deq <= 0;
      comm_enq <= 0;
    end else begin
      // default value
      comm_enq <= 0;
      comm_deq <= 0;

      // wait start
      if(state == 'h0) begin
        if(uart_rx_en) begin
          state <= 'h1;
          step <= {uart_rx_data, step[31:8]};
        end
      end else if(state == 'h1) begin
        state <= 'h2;
      end else if(state == 'h2) begin
        if(uart_rx_en) begin
          state <= 'h3;
          step <= {uart_rx_data, step[31:8]};
        end
      end else if(state == 'h3) begin
        state <= 'h4;
      end else if(state == 'h4) begin
        if(uart_rx_en) begin
          state <= 'h5;
          step <= {uart_rx_data, step[31:8]};
        end
      end else if(state == 'h5) begin
        state <= 'h6;
      end else if(state == 'h6) begin
        if(uart_rx_en) begin
          state <= 'h7;
          step <= {uart_rx_data, step[31:8]};
          comm_d <= {uart_rx_data, step[31:8]};
          comm_enq <= 1;
        end
      end else if(state == 'h7) begin
        comm_enq <= 0;
        state <= 'h10;
        
      // init
      end else if(state == 'h10) begin
        mem_d <= 0;
        mem_we <= 0;
        mem_addr <= 0;
        if(!comm_empty) begin
          comm_deq <= 1;
          comm_d <= 0;
          state <= 'h11;
        end
      end else if(state == 'h11) begin
        state <= 'h12;
        mem_addr <= 0;
        mem_we <= 1;
      end else if(state == 'h12) begin
        state <= 'h13;
        mem_addr <= mem_addr + 1;
        //mem_d <= mem_d + 1;
        mem_d <= mem_d + step;
        mem_we <= 1;
      end else if(state == 'h13) begin
        mem_addr <= mem_addr + 1;
        //mem_d <= mem_d + 1;
        mem_d <= mem_d + step;
        mem_we <= 1;
        if(mem_addr == SIZE-2) begin
          state <= 'h14;
        end
      end else if(state == 'h14) begin
        //mem_d <= mem_d + 1;
        mem_d <= mem_d + step;        
        mem_we <= 0;
        state <= 'h15;
      end else if(state == 'h15) begin
        state <= 'h16;
      end else if(state == 'h16) begin
        if(!comm_full) begin
          comm_d <= comm_d + 1;
          comm_enq <= 1;
          state <= 'h17;
        end
      end else if(state == 'h17) begin
        comm_enq <= 0;
        if(!comm_empty) begin
          comm_deq <= 1;
          state <= 'h18;
        end
      end else if(state == 'h18) begin
        if(comm_q != 0) begin
          state <= 'h11;
        end else begin
          state <= 'h21;
          sum <= 0;
          mem_d <= 0;
          mem_we <= 0;
          mem_addr <= 0;
        end

      // exec
      end else if(state == 'h21) begin
        state <= 'h22;
        mem_addr <= 0;
      end else if(state == 'h22) begin
        state <= 'h23;
        mem_addr <= mem_addr + 1;
      end else if(state == 'h23) begin
        mem_addr <= mem_addr + 1;
        sum <= sum + mem_q;
        if(mem_addr == SIZE-2) begin
          state <= 'h24;
        end
      end else if(state == 'h24) begin
        state <= 'h25;
        sum <= sum + mem_q;
      end else if(state == 'h25) begin
        state <= 'h26;
        sum <= sum + mem_q;
      end else if(state == 'h26) begin
        if(!comm_full) begin
          comm_d <= sum;
          comm_enq <= 1;
          state <= 'h27;
        end
      end else if(state == 'h27) begin
        comm_enq <= 0;
        if(uart_state == 10) begin
          state <= 'h28;
          comm_enq <= 1;
          comm_d <= sum;
        end else if(!comm_empty) begin
          comm_deq <= 1;
          state <= 'h21;
        end
      end else if(state == 'h28) begin
        comm_enq <= 0;
        state <= 'h0;
      end
    end
  end

  always @(posedge CLK) begin
    if(RST) begin
      maybe_done <= 0;
      maybe_done_cnt <= 0;
      uart_state <= 0;
      uart_tx_en <= 0;
    end else begin
      
      if(uart_state == 0 && state == 'h27) begin
        maybe_done_cnt <= maybe_done_cnt + 1;
      end else begin
        maybe_done_cnt <= 0;
      end
      
      if(uart_state == 0 && maybe_done_cnt == MAX_DONE_CNT-1) begin
        maybe_done <= 1;
      end else begin
        maybe_done <= 0;
      end
      
      case(uart_state)
        0: begin
          if(maybe_done) begin
            sum_buf <= sum;
            uart_state <= 1;
          end
        end
        1: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= sum_buf[7:0];
            uart_state <= 2;
          end
        end
        2: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            uart_state <= 3;
          end
        end
        3: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= sum_buf[15:8];
            uart_state <= 4;
          end
        end
        4: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            uart_state <= 5;
          end
        end
        5: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= sum_buf[23:16];
            uart_state <= 6;
          end
        end
        6: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            uart_state <= 7;
          end
        end
        7: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= sum_buf[31:24];
            uart_state <= 8;
          end
        end
        8: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            uart_state <= 9;
          end
        end
        9: begin
          if(uart_tx_ready) begin
            uart_state <= 10;
          end
        end
        10: begin
          uart_state <= 0;
        end
      endcase
    end
  end

  CoramMemory1P
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(W_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_data_memory
  (.CLK(CLK),
   .ADDR(mem_addr),
   .D(mem_d),
   .WE(mem_we),
   .Q(mem_q)
   );

  CoramChannel
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(0),
    .CORAM_ADDR_LEN(4),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_comm_channel
  (.CLK(CLK),
   .RST(RST),
   .D(comm_d),
   .ENQ(comm_enq),
   .FULL(comm_full),
   .Q(comm_q),
   .DEQ(comm_deq),
   .EMPTY(comm_empty)
   );

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
