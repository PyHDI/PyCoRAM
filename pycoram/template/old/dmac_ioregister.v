module DMAC_IOREGISTER #
  (
   //---------------------------------------------------------------------------
   // parameters
   //---------------------------------------------------------------------------
   parameter W_D = 32, // should be 2^n

   parameter W_EXT_A = 32, // byte addressing
   parameter W_BOUNDARY_A = 12, // for 4KB boundary limitation of AXI
   parameter W_BLEN = 9, //log(MAX_BURST_LEN) + 1
   parameter MAX_BURST_LEN = 256, // burst length

   parameter FIFO_ADDR_WIDTH = 4,
   parameter ASYNC = 1
   )
  (
   //---------------------------------------------------------------------------
   // System I/O
   //---------------------------------------------------------------------------
   input CLK,
   input RST,

   //---------------------------------------------------------------------------
   // External (Data Channel) (Transparent FIFO)
   //---------------------------------------------------------------------------
   input      [W_D-1:0]     ext_write_data,
   output                   ext_write_deq,
   input                    ext_write_empty,
   output reg [W_D-1:0]     ext_read_data,
   output reg               ext_read_enq,
   input                    ext_read_almost_full,
   
   //---------------------------------------------------------------------------
   // External (Address Channel)
   //---------------------------------------------------------------------------
   input [W_EXT_A-1:0]      ext_addr, // byte addressing
   input                    ext_read_enable,
   input                    ext_write_enable,
   input [W_BLEN-1:0]       ext_word_size, // in word
   output                   ext_ready,

   //---------------------------------------------------------------------------
   // Control Thread
   //---------------------------------------------------------------------------
   input                    coram_clk,
   input                    coram_rst,

   input      [W_D-1:0]     coram_d,
   input                    coram_we,
   output reg [W_D-1:0]     coram_q
   );

  wire ext_write_we;
  
  reg [W_D-1:0] ext_write_data_cdc_from;
  reg ext_write_we_cdc_from;
  reg [W_D-1:0] ext_write_data_cdc_to;
  reg ext_write_we_cdc_to;
  reg [W_D-1:0] coram_d_cdc_from;
  reg coram_we_cdc_from;
  reg [W_D-1:0] coram_d_cdc_to;
  reg coram_we_cdc_to;
  
  assign ext_ready = 1;
  assign ext_write_deq = !ext_write_empty; // Transparent
  assign ext_write_we = !ext_write_empty;

  generate if(ASYNC) begin
    always @(posedge CLK) begin
      if(ext_write_we) ext_read_data <= ext_write_data;
      if(coram_we_cdc_to) ext_read_data <= coram_d_cdc_to;
    end

    always @(posedge coram_clk) begin
      if(ext_write_we_cdc_to) coram_q <= ext_write_data_cdc_to;
      if(coram_we) coram_q <= coram_d;
    end
    
    always @(posedge CLK) begin
      ext_write_we_cdc_from <= ext_write_we;
      ext_write_data_cdc_from <= ext_write_data;
    end
    always @(posedge coram_clk) begin
      ext_write_we_cdc_to <= ext_write_we_cdc_from;
      ext_write_data_cdc_to <= ext_write_data_cdc_from;
    end

    always @(posedge coram_clk) begin
      coram_we_cdc_from <= coram_we;
      coram_d_cdc_from <= coram_d;
    end
    always @(posedge CLK) begin
      coram_we_cdc_to <= coram_we_cdc_from;
      coram_d_cdc_to <= coram_d_cdc_from;
    end
  end else begin
    always @(posedge CLK) begin
      if(coram_we) begin
        ext_read_data <= coram_d;
        coram_q <= coram_d;
      end
      if(ext_write_we) begin
        ext_read_data <= ext_write_data;
        coram_q <= ext_write_data;
      end
    end
  end endgenerate
  
endmodule

