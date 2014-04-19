reg [(W_A - 1):0] _addr;
reg [(W_D - 1):0] _d;
reg [0:0] _re;
reg [0:0] _we;

assign addr = _addr;
assign d = _d;
assign re = _re;
assign we = _we;

integer a;

integer sum;

initial begin
  _re = 0;
  _we = 0;
  _addr = 0;
  wait(stall == 0);
  nclk();

  for(a=0; a<16; a=a+1) begin
    _addr = a << 2;
    _we = 0;
    _re = 1;
    nclk();
    wait(stall == 0);
    #1;
    $display("# read  addr=%x, q=%x", addr, q);
    sum = q;
    
    _addr = (a << 2) + 'h10000;
    _we = 0;
    _re = 1;
    nclk();
    wait(stall == 0);
    #1;
    $display("# read  addr=%x, q=%x", addr, q);
    sum = sum + q;

/* -----\/----- EXCLUDED -----\/-----
    _addr = (a << 2) + 'h20000;
    _re = 1;
    _we = 0;
    nclk();
    wait(stall == 0);
    #1;
    $display("# read  addr=%x, q=%x", addr, q);
 -----/\----- EXCLUDED -----/\----- */

    _addr = (a << 2) + 'h20000;
    _re = 0;
    _we = 1;
    _d = sum;
    $display("# write addr=%x, d=%x", addr, d);
    nclk();
    wait(stall == 0);
    #1;

    _addr = (a << 2) + 'h30000;
    _we = 0;
    _re = 1;
    nclk();
    wait(stall == 0);
    #1;
    $display("# read  addr=%x, q=%x", addr, q);

    _addr = (a << 2) + 'h40000;
    _we = 0;
    _re = 1;
    nclk();
    wait(stall == 0);
    #1;
    $display("# read  addr=%x, q=%x", addr, q);

    _addr = (a << 2) + 'h20000;
    _re = 1;
    _we = 0;
    nclk();
    wait(stall == 0);
    #1;
    $display("# read  addr=%x, q=%x", addr, q);
    if(sum == q) $display("# OK sum=%x q=%x", sum, q);
    else $display("# NG sum=%x q=%x", sum, q);
    
  end
  _re = 0;
  _we = 0;

  #100;
  $finish;
end