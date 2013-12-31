RTL=st.v
THREAD=cthread_st.py
TEST=testbench.v
MEM=330stencil512.hex
TOPMODULE=st

MEMIMG=--memimg=$(MEM)
USERTEST=--usertest=$(TEST)

INPUT=$(RTL) $(THREAD)

################################################################################
ROOTDIR=../../

PYTHON=python3.3
#OPT=-m pdb
#OPT=-m cProfile -o profile.rslt
TARGET=$(ROOTDIR)/pycoram.py

IPVER=v1_00_a
OUTPUTDIR=pycoram_$(TOPMODULE)_$(IPVER)
INCLUDE=-I $(ROOTDIR)/include/ -I ./core/
EXTADDRWIDTH=--extaddrwidth=32
SIGNALWIDTH=--signalwidth=64
SIMADDRWIDTH=--simaddrwidth=24
HPERIOD_ULOGIC=--hperiod_ulogic=5
HPERIOD_CTHREAD=--hperiod_cthread=5
HPERIOD_AXI=--hperiod_axi=5
SINGLE_CLOCK=--singleclock
#NOAXI=--noaxi

OPTIONS=$(EXTADDRWIDTH) $(EXTDATAWIDTH) $(SIGNALWIDTH) $(MEMIMG) $(USERTEST) $(SIMADDRWIDTH) $(HPERIOD_ULOGIC) $(HPERIOD_CTHREAD) $(HPERIOD_AXI) $(SINGLE_CLOCK) $(NOAXI)
ARGS=$(INCLUDE) -t $(TOPMODULE) --ipver=$(IPVER) $(OPTIONS)

################################################################################
.PHONY: all
all: sim

.PHONY: build
build:
	$(PYTHON) $(OPT) $(TARGET) $(ARGS) $(INPUT) 

.PHONY: sim
sim:
	make compile -C $(OUTPUTDIR)/test
	make run -C $(OUTPUTDIR)/test

.PHONY: vcs_sim
vcs_sim:
	make vcs_compile -C $(OUTPUTDIR)/test
	make vcs_run -C $(OUTPUTDIR)/test

.PHONY: view
view:
	make view -C $(OUTPUTDIR)/test

.PHONY: clean
clean:
	rm -rf *.pyc __pycache__ parsetab.py *.out $(OUTPUTDIR)
