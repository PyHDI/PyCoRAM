.PHONY: clean
clean:
	make clean -C fpga_app
	make clean -C fpga_test
	make clean -C sample_app
	make clean -C test

.PHONY: build
build:
	make build -C fpga_app
	make build -C fpga_test
	make build -C sample_app
	make build -C test

.PHONY: sim
sim:
	make sim -C fpga_app
	make sim -C fpga_test
	make sim -C sample_app
	make sim -C test

.PHONY: vcs_sim
vcs_sim:
	make vcs_sim -C fpga_app
	make vcs_sim -C fpga_test
	make vcs_sim -C sample_app
	make vcs_sim -C test

.PHONY: test
test:
	make test -C fpga_app
	make test -C fpga_test
	make test -C sample_app
	make test -C test

.PHONY: vcs_test
vcs_test:
	make vcs_test -C fpga_app
	make vcs_test -C fpga_test
	make vcs_test -C sample_app
	make vcs_test -C test
