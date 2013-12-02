PYTHON=python3.3
#OPT=-m pdb

CONVERTER=rtlconverter.py

INCLUDE=-I ../include/
SRCS=../input/tests/single_memory/userlogic.v
TOPMODULE=userlogic
#SRCS=../input/Gemm/*.v ../input/Gemm/converted/*.v ../include/coram2pycoram.v
#TOPMODULE=mkCogemm
OUT=out.v

.PHONY: run
run:
	$(PYTHON) $(OPT) $(CONVERTER) $(SRCS) $(INCLUDE) -t $(TOPMODULE) -o $(OUT)

.PHONY: clean
clean:
	rm -rf *.pyc __pycache__ parsetab.py *.out $(OUT)
