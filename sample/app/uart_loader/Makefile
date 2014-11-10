TOPMODULE=loader
RTL=loader.v
THREAD=cthread_recv.py cthread_send.py
#TEST=testbench.v
TEST=testbench_repeat.v
USERTEST=--usertest=$(TEST)
MEM=../../mem-incr.hex
MEMIMG=--memimg=$(MEM)
ROOTDIR=../../../
CONFIG=$(ROOTDIR)/sample/default.config
INCLUDE=-I $(ROOTDIR)/include/
include $(ROOTDIR)/sample/base.mk
