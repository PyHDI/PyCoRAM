TARGET=./input/tests/single_memory/

.PHONY: all
all: sim

.PHONY: build
build:
	make build -C $(TARGET)

.PHONY: sim
sim:
	make sim -C $(TARGET)

.PHONY: vcs_sim
vcs_sim:
	make vcs_sim -C $(TARGET)

.PHONY: view
view:
	make view -C $(TARGET)

.PHONY: clean
clean:
	rm -rf *.pyc __pycache__ parsetab.py *.out *.html
	make clean -C controlthread
	make clean -C rtlconverter
	make clean -C utils
	make clean -C input
