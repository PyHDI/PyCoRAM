from myhdl import *

coram_obj_count = 0

#-------------------------------------------------------------------------------
# Single-Port CoRAM
#-------------------------------------------------------------------------------
def MyhdlCoramMemory1P(CLK, ADDR, D, WE, Q,
                       CORAM_THREAD_NAME="undefined",
                       CORAM_THREAD_ID=0,
                       CORAM_ID=0,
                       CORAM_SUB_ID=0,
                       CORAM_ADDR_LEN=10,
                       CORAM_DATA_WIDTH=32):

    @always(CLK.posedge)
    def logic():
        pass # do nothing

    Q.driven = "wire"

    MyhdlCoramMemory1P.verilog_code=\
"""
  CoramMemory1P
  #(
    .CORAM_THREAD_NAME( "$CORAM_THREAD_NAME" ),
    .CORAM_ID( $CORAM_ID ),
    .CORAM_SUB_ID( $CORAM_SUB_ID ),
    .CORAM_ADDR_LEN( $CORAM_ADDR_LEN ),
    .CORAM_DATA_WIDTH( $CORAM_DATA_WIDTH )
    )
  obj_$coram_obj_count
  (.CLK( $CLK ),
   .ADDR( $ADDR ),
   .D( $D ),
   .WE( $WE ),
   .Q( $Q )
   );
"""
    global coram_obj_count
    coram_obj_count += 1
    return logic

#-------------------------------------------------------------------------------
def MyhdlCoramMemoryBE1P(CLK, ADDR, D, WE, MASK, Q,
                         CORAM_THREAD_NAME="undefined",
                         CORAM_THREAD_ID=0,
                         CORAM_ID=0,
                         CORAM_SUB_ID=0,
                         CORAM_ADDR_LEN=10,
                         CORAM_DATA_WIDTH=32):

    @always(CLK.posedge)
    def logic():
        pass # do nothing

    Q.driven = "wire"

    MyhdlCoramMemoryBE1P.verilog_code=\
"""
  CoramMemoryBE1P
  #(
    .CORAM_THREAD_NAME( "$CORAM_THREAD_NAME" ),
    .CORAM_ID( $CORAM_ID ),
    .CORAM_SUB_ID( $CORAM_SUB_ID ),
    .CORAM_ADDR_LEN( $CORAM_ADDR_LEN ),
    .CORAM_DATA_WIDTH( $CORAM_DATA_WIDTH )
    )
  obj_$coram_obj_count
  (.CLK( $CLK ),
   .ADDR( $ADDR ),
   .D( $D ),
   .WE( $WE ),
   .MASK( $MASK ),
   .Q( $Q )
   );
"""
    global coram_obj_count
    coram_obj_count += 1
    return logic

#-------------------------------------------------------------------------------
# Dual-Port CoRAM
#-------------------------------------------------------------------------------
def MyhdlCoramMemory2P(CLK, ADDR0, D0, WE0, Q0, ADDR1, D1, WE1, Q1, 
                       CORAM_THREAD_NAME="undefined",
                       CORAM_THREAD_ID=0,
                       CORAM_ID=0,
                       CORAM_SUB_ID=0,
                       CORAM_ADDR_LEN=10,
                       CORAM_DATA_WIDTH=32):

    @always(CLK.posedge)
    def logic():
        pass # do nothing

    Q0.driven = "wire"
    Q1.driven = "wire"

    MyhdlCoramMemory2P.verilog_code=\
"""
  CoramMemory2P
  #(
    .CORAM_THREAD_NAME( "$CORAM_THREAD_NAME" ),
    .CORAM_ID( $CORAM_ID ),
    .CORAM_SUB_ID( $CORAM_SUB_ID ),
    .CORAM_ADDR_LEN( $CORAM_ADDR_LEN ),
    .CORAM_DATA_WIDTH( $CORAM_DATA_WIDTH )
    )
  obj_$coram_obj_count
  (.CLK( $CLK ),
   .ADDR0( $ADDR0 ),
   .D0( $D0 ),
   .WE0( $WE0 ),
   .Q0( $Q0 ),
   .ADDR1( $ADDR1 ),
   .D1( $D1 ),
   .WE1( $WE1 ),
   .Q1( $Q1 )
   );
"""
    global coram_obj_count
    coram_obj_count += 1
    return logic

#-------------------------------------------------------------------------------
def MyhdlCoramMemoryBE2P(CLK, ADDR0, D0, WE0, MASK0, Q0, ADDR1, D1, WE1, MASK1, Q1, 
                         CORAM_THREAD_NAME="undefined",
                         CORAM_THREAD_ID=0,
                         CORAM_ID=0,
                         CORAM_SUB_ID=0,
                         CORAM_ADDR_LEN=10,
                         CORAM_DATA_WIDTH=32):

    @always(CLK.posedge)
    def logic():
        pass # do nothing

    Q0.driven = "wire"
    Q1.driven = "wire"

    MyhdlCoramMemoryBE2P.verilog_code=\
"""
  CoramMemory2P
  #(
    .CORAM_THREAD_NAME( "$CORAM_THREAD_NAME" ),
    .CORAM_ID( $CORAM_ID ),
    .CORAM_SUB_ID( $CORAM_SUB_ID ),
    .CORAM_ADDR_LEN( $CORAM_ADDR_LEN ),
    .CORAM_DATA_WIDTH( $CORAM_DATA_WIDTH )
    )
  obj_$coram_obj_count
  (.CLK( $CLK ),
   .ADDR0( $ADDR0 ),
   .D0( $D0 ),
   .WE0( $WE0 ),
   .MASK0( $MASK0 ),
   .Q0( $Q0 ),
   .ADDR1( $ADDR1 ),
   .D1( $D1 ),
   .WE1( $WE1 ),
   .MASK1( $MASK1 ),
   .Q1( $Q1 )
   );
"""
    global coram_obj_count
    coram_obj_count += 1
    return logic

#-------------------------------------------------------------------------------
# CoRAM Input Stream (DRAM -> BRAM) (Non-Transparent FIFO with BlockRAM)
#-------------------------------------------------------------------------------
def MyhdlCoramInStream(CLK, RST, Q, DEQ, EMPTY, ALM_EMPTY,
                       CORAM_THREAD_NAME="undefined",
                       CORAM_THREAD_ID=0,
                       CORAM_ID=0,
                       CORAM_SUB_ID=0,
                       CORAM_ADDR_LEN=4,
                       CORAM_DATA_WIDTH=32):

    @always(CLK.posedge)
    def logic():
        pass # do nothing

    Q.driven = "wire"
    EMPTY.driven = "wire"
    ALM_EMPTY.driven = "wire"

    MyhdlCoramInStream.verilog_code=\
"""
  CoramInStream
  #(
    .CORAM_THREAD_NAME( "$CORAM_THREAD_NAME" ),
    .CORAM_ID( $CORAM_ID ),
    .CORAM_SUB_ID( $CORAM_SUB_ID ),
    .CORAM_ADDR_LEN( $CORAM_ADDR_LEN ),
    .CORAM_DATA_WIDTH( $CORAM_DATA_WIDTH )
    )
  obj_$coram_obj_count
  (.CLK( $CLK ),
   .RST( $RST ),
   .Q( $Q ),
   .DEQ( $DEQ ),
   .EMPTY( $EMPTY ),
   .ALM_EMPTY( $ALM_EMPTY )
   );
"""
    global coram_obj_count
    coram_obj_count += 1
    return logic


#-------------------------------------------------------------------------------
# CoRAM Output Stream (BRAM -> DRAM) (Non-Transparent FIFO with BlockRAM)
#-------------------------------------------------------------------------------
def MyhdlCoramOutStream(CLK, RST, D, ENQ, FULL, ALM_FULL,
                        CORAM_THREAD_NAME="undefined",
                        CORAM_THREAD_ID=0,
                        CORAM_ID=0,
                        CORAM_SUB_ID=0,
                        CORAM_ADDR_LEN=4,
                        CORAM_DATA_WIDTH=32):

    @always(CLK.posedge)
    def logic():
        pass # do nothing

    FULL.driven = "wire"
    ALM_FULL.driven = "wire"

    MyhdlCoramOutStream.verilog_code=\
"""
  CoramOutStream
  #(
    .CORAM_THREAD_NAME( "$CORAM_THREAD_NAME" ),
    .CORAM_ID( $CORAM_ID ),
    .CORAM_SUB_ID( $CORAM_SUB_ID ),
    .CORAM_ADDR_LEN( $CORAM_ADDR_LEN ),
    .CORAM_DATA_WIDTH( $CORAM_DATA_WIDTH )
    )
  obj_$coram_obj_count
  (.CLK( $CLK ),
   .RST( $RST ),
   .D( $D ),
   .ENQ( $ENQ ),
   .FULL( $FULL ),
   .ALM_FULL( $ALM_FULL )
   );
"""
    global coram_obj_count
    coram_obj_count += 1
    return logic

#-------------------------------------------------------------------------------
# CoRAM Channel (Non-Transparent FIFO with BlockRAM)
#-------------------------------------------------------------------------------
def MyhdlCoramChannel(CLK, RST,
                      D, ENQ, FULL, ALM_FULL,
                      Q, DEQ, EMPTY, ALM_EMPTY,
                      CORAM_THREAD_NAME="undefined",
                      CORAM_THREAD_ID=0,
                      CORAM_ID=0,
                      CORAM_SUB_ID=0,
                      CORAM_ADDR_LEN=4,
                      CORAM_DATA_WIDTH=32):

    @always(CLK.posedge)
    def logic():
        pass # do nothing

    Q.driven = "wire"
    EMPTY.driven = "wire"
    ALM_EMPTY.driven = "wire"
    FULL.driven = "wire"
    ALM_FULL.driven = "wire"

    MyhdlCoramChannel.verilog_code=\
"""
  CoramChannel
  #(
    .CORAM_THREAD_NAME( "$CORAM_THREAD_NAME" ),
    .CORAM_ID( $CORAM_ID ),
    .CORAM_SUB_ID( $CORAM_SUB_ID ),
    .CORAM_ADDR_LEN( $CORAM_ADDR_LEN ),
    .CORAM_DATA_WIDTH( $CORAM_DATA_WIDTH )
    )
  obj_$coram_obj_count
  (.CLK( $CLK ),
   .RST( $RST ),
   .D( $D ),
   .ENQ( $ENQ ),
   .FULL( $FULL ),
   .ALM_FULL( $ALM_FULL ),
   .Q( $Q ),
   .DEQ( $DEQ ),
   .EMPTY( $EMPTY ),
   .ALM_EMPTY( $ALM_EMPTY )
   );
"""
    global coram_obj_count
    coram_obj_count += 1
    return logic

#-------------------------------------------------------------------------------
# CoRAM Register
#-------------------------------------------------------------------------------
def MyhdlCoramRegister(CLK, RST, D, WE, Q,
                       CORAM_THREAD_NAME="undefined",
                       CORAM_THREAD_ID=0,
                       CORAM_ID=0,
                       CORAM_SUB_ID=0,
                       CORAM_ADDR_LEN=4,
                       CORAM_DATA_WIDTH=32):

    @always(CLK.posedge)
    def logic():
        pass # do nothing

    Q.driven = "wire"

    MyhdlCoramRegister.verilog_code=\
"""
  CoramRegister
  #(
    .CORAM_THREAD_NAME( "$CORAM_THREAD_NAME" ),
    .CORAM_ID( $CORAM_ID ),
    .CORAM_SUB_ID( $CORAM_SUB_ID ),
    .CORAM_ADDR_LEN( $CORAM_ADDR_LEN ),
    .CORAM_DATA_WIDTH( $CORAM_DATA_WIDTH )
    )
  obj_$coram_obj_count
  (.CLK( $CLK ),
   .D( $D ),
   .WE( $WE ),
   .Q( $Q )
   );
"""
    global coram_obj_count
    coram_obj_count += 1
    return logic

