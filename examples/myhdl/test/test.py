from myhdl import *
import myhdl_pycoram

def sub(CLK, RST, LED, object_id, sub_object_id):
    ADDR = Signal(intbv()[16:])
    D = Signal(intbv()[32:])
    WE = Signal(bool(0))
    Q = Signal(intbv()[32:])
    coram_memory = myhdl_pycoram.MyhdlCoramMemory1P(CLK, ADDR, D, WE, Q,
                                                    "cthread_test", 0, object_id, sub_object_id, 16, 32)

    @always(CLK.posedge)
    def logic():
        if RST == 1:
            WE.next = 0
            ADDR.next = 0
            D.next = 0
            LED.next = 0
        else:
            WE.next = 1
            ADDR.next = ADDR + 1
            D.next = D + 4
            LED.next = Q

    return instances()


def main(CLK, RST, LED0, LED1):
    s0 = sub(CLK, RST, LED0, 0, 0)
    s1 = sub(CLK, RST, LED1, 1, 0)
    return instances()

def convert():
    CLK = Signal(bool(0))
    RST = Signal(bool(0))
    LED0 = Signal(intbv()[8:])
    LED1 = Signal(intbv()[8:])
    
    toVerilog(main,
              CLK, RST, LED0, LED1)

convert()

