reg [W_D-1:0] _write_data;
reg _write_valid;
reg _read_request;

assign write_data = _write_data;
assign write_valid = _write_valid;
assign read_request = _read_request;

integer i;
integer stage;
reg [31:0] my_val, p_val;

localparam WRITE_SIZE = 128;
localparam READ_SIZE = 128;

initial begin
  _write_data = 0;
  _write_valid = 0;
  _read_request = 0;

  wait(~sim_resetn);
  wait(sim_resetn);
  
  #1000;

  nclk();

  for(i=0; i<WRITE_SIZE; i=i+1) begin
    _write_data = i + 'h100;
    _write_valid = 1;
    $display("---- write data=%d", _write_data);
    while(!write_ready) nclk();
    nclk();
    _write_valid = 0;
    nclk();
    
    _read_request = 1;
    $display("---- read issue");
    while(!read_valid) nclk();
    nclk();
    _read_request = 0;
    $display("---- read data=%d", read_data);
    nclk();
  end
  
/* -----\/----- EXCLUDED -----\/-----
  for(i=0; i<WRITE_SIZE; i=i+1) begin
    _write_data = i;
    //_write_data = 100 - i;
    _write_valid = 1;
    $display("---- write data=%d", _write_data);
    while(!write_ready) nclk();
    nclk();
    _write_valid = 0;
    nclk();
  end
    
  for(i=0; i<READ_SIZE; i=i+1) begin
    _read_request = 1;
    $display("---- read issue");
    while(!read_valid) nclk();
    nclk();
    _read_request = 0;
    $display("---- read data=%d", read_data);
    nclk();
  end
 -----/\----- EXCLUDED -----/\----- */
  
  _write_data = 0;
  _write_valid = 0;
  
  #10000;
  wait(uut.inst_uut.inst_dmac_stream_cthread_heap_coramoutstream_0.req_busy == 0);
  
  // memory dump
  stage = 0;
  for(i=1; i<=(WRITE_SIZE-READ_SIZE); i=i+1) begin
    if((i >> stage) > 0) begin
      $display("");
      stage = stage + 1;
    end
    p_val = {inst_dram_stub.memory[(i>>1)*4+3], inst_dram_stub.memory[(i>>1)*4+2], inst_dram_stub.memory[(i>>1)*4+1], inst_dram_stub.memory[(i>>1)*4+0]};
    my_val = {inst_dram_stub.memory[i*4+3], inst_dram_stub.memory[i*4+2], inst_dram_stub.memory[i*4+1], inst_dram_stub.memory[i*4+0]};
    $write("%d", my_val);
    if(p_val > my_val) $write("*");
  end

  $display("");
  $finish;
end
