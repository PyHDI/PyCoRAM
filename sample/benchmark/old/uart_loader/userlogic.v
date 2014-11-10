`include "pycoram.v"
`define THREAD_NAME "ctrl_thread"

module userlogic #
  (
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
   
   output [LED_WIDTH-1:0] led
   );

  init #
    (
     .SYS_CLK_FREQ(SYS_CLK_FREQ),
     .BAUDRATE(BAUDRATE),
     .LED_WIDTH(LED_WIDTH),
     .HAS_RETURN_VALUE(1)
     )
  inst_init
    (
     .CLK(CLK),
     .RST(RST),
     .USB_1_CTS(USB_1_CTS),
     .USB_1_RTS(USB_1_RTS),
     .USB_1_RX(USB_1_RX),
     .USB_1_TX(USB_1_TX),
     .led(led),
     .return_value(100) // test value
     );
  
endmodule
  
module init #  
  (
   parameter W_COMM_D = 64,
   parameter W_D = 32,
   parameter W_COMM_A = 4,
   parameter W_A = 7,
   parameter SYS_CLK_FREQ = 100,
   parameter BAUDRATE = 921600,
   parameter LED_WIDTH = 8,
   parameter HAS_RETURN_VALUE = 0
   )
  (
   input CLK,
   input RST,

   output USB_1_CTS, //= UART RTS
   input  USB_1_RTS, //= UART CTS
   output USB_1_RX,  //= UART_TX
   input  USB_1_TX,  //= UART_RX
   
   output reg [LED_WIDTH-1:0] led,
   input [63:0] return_value
   );

  reg [W_A-1:0] init_mem_addr;
  reg [W_D-1:0] init_mem_d;
  reg           init_mem_we;
  wire [W_D-1:0] init_mem_q;

  reg [W_COMM_D-1:0] init_channel_d;
  reg init_channel_enq;
  wire init_channel_full;
  wire [W_COMM_D-1:0] init_channel_q;
  reg init_channel_deq;
  wire init_channel_empty;

  reg [7:0] uart_tx_data;
  reg  uart_tx_en;
  wire uart_tx_ready;
  wire uart_txd;

  wire [7:0] uart_rx_data;
  wire uart_rx_en;
  wire uart_rxd;
  
  reg [7:0] state;
  reg [26:0] led_count;
  reg [63:0] cycle_count;
  reg [31:0] step;

  reg [63:0] cycle_count_buf;
  reg [63:0] return_value_buf;
  
  assign USB_1_RX = uart_txd;
  assign USB_1_CTS = 0;
  assign uart_rxd = USB_1_TX;
  
  always @(posedge CLK) begin
    if(RST) led_count <= 0;
    else led_count <= led_count + 1;
  end

  always @(posedge CLK) begin
    led <= (state == 'h0)? {led_count[26], 7'b0}:
           (state > 'h0 && state < 'h10)? {1'b0, led_count[26], 6'b0}:
           (state >= 'h10 && state < 'h20)? {2'b0, led_count[26], 5'b0}:
           (state == 'h20)? led_count[23:16]:
           {3'b0, led_count[26], 4'b0};
  end

  always @(posedge CLK) begin
    if(RST) begin
      state <= 0;
      init_mem_we <= 0;
      init_channel_enq <= 0;
      init_channel_deq <= 0;
      uart_tx_en <= 0;
      cycle_count <= 0;
    end else begin
      // default value
      init_mem_we <= 0;
      init_channel_enq <= 0;
      init_channel_deq <= 0;
      uart_tx_en <= 0;

      case(state)
        'h0: begin // receive step value from UART
          if(uart_rx_en) begin
            state <= 'h1;
            step <= {uart_rx_data, step[31:8]};
          end
        end
        'h1: begin
          state <= 'h2;
        end
        'h2: begin
          if(uart_rx_en) begin
            state <= 'h3;
            step <= {uart_rx_data, step[31:8]};
          end
        end
        'h3: begin
          state <= 'h4;
        end
        'h4: begin
          if(uart_rx_en) begin
            state <= 'h5;
            step <= {uart_rx_data, step[31:8]};
          end
        end
        'h5: begin
          state <= 'h6;
        end
        'h6: begin
          if(uart_rx_en) begin
            state <= 'h7;
            step <= {uart_rx_data, step[31:8]};
          end
        end
        'h7: begin
          if(!init_channel_full) begin
            init_channel_d <= step;
            init_channel_enq <= 1;
            state <= 'h8;
          end
        end
        'h8: begin
          state <= 'h10;
        end
        'h10: begin // initialize memory values
          init_mem_d <= 0;
          init_mem_we <= 0;
          init_mem_addr <= 0;
          state <= 'h11;
        end
        'h11: begin
          init_mem_addr <= 0;
          init_mem_we <= 1;
          state <= 'h12;
        end
        'h12: begin
          init_mem_addr <= init_mem_addr + 1;
          init_mem_d <= init_mem_d + step;
          init_mem_we <= 1;
          if(init_mem_addr == 2 ** W_A - 2) begin
            state <= 'h13;
          end
        end
        'h13: begin
          init_mem_d <= init_mem_d + step;
          init_mem_we <= 0;
          state <= 'h14;
        end
        'h14: begin
          if(!init_channel_full) begin
            init_channel_d <= init_mem_d;
            init_channel_enq <= 1;
            state <= 'h15;
          end
        end
        'h15: begin
          if(!init_channel_empty) begin
            init_channel_deq <= 1;
            state <= 'h16;            
          end
        end
        'h16: begin
          if(init_channel_q == 0) begin
            state <= 'h11;
          end else begin
            state <= 'h17; //to computation
            cycle_count <= 0;
          end
        end
        'h17: begin
          state <= 'h20; //to computation
        end
        'h20: begin
          // computation
          cycle_count <= cycle_count + 1;
          if(!init_channel_empty) begin
            init_channel_deq <= 1;
            cycle_count_buf <= cycle_count;
            if(HAS_RETURN_VALUE) begin
              return_value_buf <= return_value;
              state <= 'h30;
            end else begin
              state <= 'h40;
            end
          end
        end

        'h30: begin
          //dump
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= return_value_buf[7:0];
            state <= 'h31;
          end
        end
        'h31: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h32;
          end
        end
        'h32: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= return_value_buf[15:8];
            state <= 'h33;
          end
        end
        'h33: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h34;
          end
        end 
        'h34: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= return_value_buf[23:16];
            state <= 'h35;
          end
        end 
        'h35: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h36;
          end
        end 
        'h36: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= return_value_buf[31:24];
            state <= 'h37;
          end
        end
        'h37: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h38;
          end
        end 
        'h38: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= return_value_buf[39:32];
            state <= 'h39;
          end
        end 
        'h39: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h3a;
          end
        end 
        'h3a: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= return_value_buf[47:40];
            state <= 'h3b;
          end
        end
        'h3b: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h3c;
          end
        end
        'h3c: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= return_value_buf[55:48];
            state <= 'h3d;
          end
        end
        'h3d: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h3e;
          end
        end 
        'h3e: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= return_value_buf[63:56];
            state <= 'h3f;
          end
        end 
        'h3f: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h40;
          end
        end

        'h40: begin
          //dump
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= cycle_count_buf[7:0];
            state <= 'h41;
          end
        end
        'h41: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h42;
          end
        end
        'h42: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= cycle_count_buf[15:8];
            state <= 'h43;
          end
        end
        'h43: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h44;
          end
        end 
        'h44: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= cycle_count_buf[23:16];
            state <= 'h45;
          end
        end 
        'h45: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h46;
          end
        end 
        'h46: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= cycle_count_buf[31:24];
            state <= 'h47;
          end
        end
        'h47: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h48;
          end
        end 
        'h48: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= cycle_count_buf[39:32];
            state <= 'h49;
          end
        end 
        'h49: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h4a;
          end
        end 
        'h4a: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= cycle_count_buf[47:40];
            state <= 'h4b;
          end
        end
        'h4b: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h4c;
          end
        end
        'h4c: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= cycle_count_buf[55:48];
            state <= 'h4d;
          end
        end
        'h4d: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h4e;
          end
        end 
        'h4e: begin
          if(uart_tx_ready) begin
            uart_tx_en <= 1;
            uart_tx_data <= cycle_count_buf[63:56];
            state <= 'h4f;
          end
        end 
        'h4f: begin
          if(!uart_tx_ready) begin
            uart_tx_en <= 0;
            state <= 'h0; // to initial state
            $display("# execution time=%d", cycle_count_buf);
          end
        end
      endcase
    end
  end

  CoramMemory1P
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(128),
    .CORAM_ADDR_LEN(W_A),
    .CORAM_DATA_WIDTH(W_D)
    )
  inst_init_memory
  (.CLK(CLK),
   .ADDR(init_mem_addr),
   .D(init_mem_d),
   .WE(init_mem_we),
   .Q(init_mem_q)
   );
  
  CoramChannel
  #(
    .CORAM_THREAD_NAME(`THREAD_NAME),
    .CORAM_ID(128),
    .CORAM_ADDR_LEN(W_COMM_A),
    .CORAM_DATA_WIDTH(W_COMM_D)
    )
  inst_comm_channel
  (.CLK(CLK),
   .RST(RST),
   .D(init_channel_d),
   .ENQ(init_channel_enq),
   .FULL(init_channel_full),
   .Q(init_channel_q),
   .DEQ(init_channel_deq),
   .EMPTY(init_channel_empty)
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
  
