TOPMODULE=loader
RTL=loader.v
THREAD=cthread_recv.py cthread_send.py
#TEST=testbench.v
TEST=testbench_repeat.v
USERTEST=--usertest=$(TEST)
ROOTDIR=../../../
MEM=$(ROOTDIR)/mem-incr.hex
MEMIMG=--memimg=$(MEM)
CONFIG=$(ROOTDIR)/default.config
INCLUDE=-I $(ROOTDIR)/include/
include $(ROOTDIR)/base.mk
