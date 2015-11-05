PYTHON=python3
#PYTHON=python
#OPT=-m pdb
#OPT=-m cProfile -s time
#OPT=-m cProfile -o profile.rslt

# If you installed pycoram in your environment
TARGET=pycoram

# If you directly execute run_pycoram.py without installation
LTARGET=$(PYTHON) $(OPT) $(ROOTDIR)/pycoram/run_pycoram.py

################################################################################
IPVER=v1_00_a
OUTPUTDIR=pycoram_$(TOPMODULE)_$(IPVER)
INPUT=$(RTL) $(THREAD) $(CONFIG)
OPTIONS=$(MEMIMG) $(USERTEST)
ARGS=$(INCLUDE) -t $(TOPMODULE) $(OPTIONS)

################################################################################
.PHONY: all
all: sim

.PHONY: build
build:
	$(TARGET) $(ARGS) $(INPUT) 

.PHONY: lbuild
lbuild:
	$(LTARGET) $(ARGS) $(INPUT) 

.PHONY: sim
sim:
	make compile -C $(OUTPUTDIR)/test
	make run -C $(OUTPUTDIR)/test

.PHONY: vcs_sim
vcs_sim:
	make vcs_compile -C $(OUTPUTDIR)/test
	make vcs_run -C $(OUTPUTDIR)/test

.PHONY: test
test: build sim

.PHONY: vcs_test
vcs_test: build vcs_sim

.PHONY: view
view:
	make view -C $(OUTPUTDIR)/test

.PHONY: check_syntax
check_syntax:
	iverilog $(INCLUDE) -tnull -Wall $(RTL)

.PHONY: clean
clean:
	rm -rf *.pyc __pycache__ parsetab.py *.out $(OUTPUTDIR)
