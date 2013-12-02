PYTHON=python3.3
#OPT=-m pdb
TARGET=controlthread.py
INPUT=../input/tests/single_memory/ctrl_thread.py
#INPUT=../input/Gemm/gemm_thread_0.py ../input/Gemm/gemm_thread_1.py ../input/Gemm/gemm_thread_2.py ../input/Gemm/gemm_thread_3.py

.PHONY: compile
compile:
	$(PYTHON) $(OPT) $(TARGET) $(INPUT)

.PHONY: clean
clean:
	rm -rf *.pyc __pycache__ parsetab.py *.out *.v
