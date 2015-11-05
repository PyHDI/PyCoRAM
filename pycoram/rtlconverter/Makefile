PYTHON=python3
#OPT=-m pdb
CONVERTER=run_rtlconverter.py
INCLUDE=-I ../../include/
SRCS=../../sample/test/single_memory/userlogic.v
TOPMODULE=userlogic
OUT=out.v

.PHONY: run
run:
	$(PYTHON) $(OPT) $(CONVERTER) $(SRCS) $(INCLUDE) -t $(TOPMODULE) -o $(OUT)

.PHONY: clean
clean:
	rm -rf *.pyc __pycache__ parsetab.py *.out $(OUT)
