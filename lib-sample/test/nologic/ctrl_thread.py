import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))

from pycoram.pycoram import *

def fib(v):
    if v <= 0: return 0
    if v == 1: return 1
    ## Recursive call is not supported
    # return fib(v-1) + fib(v-2)
    r0 = 0
    r1 = 1
    for i in range(v-1):
        prev_r1 = r1
        r1 = r0 + r1
        r0 = prev_r1
    return r1

def ctrl_thread():
    iochannel = CoramIoChannel(idx=0, datawidth=32)
    while True:
        a = iochannel.read()
        rslt = fib(a)
        iochannel.write(rslt)
