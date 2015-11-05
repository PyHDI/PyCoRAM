TOPMODULE=dijkstra
RTL=dijkstra.v
THREAD=cthread_dijkstra.py cthread_heap.py cthread_read_edge.py cthread_read_node.py cthread_write_node_update.py cthread_write_node_visited.py
TEST=testbench.v
USERTEST=--usertest=$(TEST)
ROOTDIR=../../../
MEM=./data/out.bin
MEMIMG=--memimg=$(MEM)
CONFIG=$(ROOTDIR)/default.config
INCLUDE=-I $(ROOTDIR)/include/
include $(ROOTDIR)/base.mk
