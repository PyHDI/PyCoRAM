.PHONY: clean
clean:
	make clean -C bandwidth
	make clean -C uart_loader
	make clean -C simd
	make clean -C sum

.PHONY: build
build:
	make build -C bandwidth
	make build -C uart_loader
	make build -C simd
	make build -C sum

.PHONY: sim
sim:
	make sim -C bandwidth
	make sim -C uart_loader
	make sim -C simd
	make sim -C sum

.PHONY: vcs_sim
vcs_sim:
	make vcs_sim -C bandwidth
	make vcs_sim -C uart_loader
	make vcs_sim -C simd
	make vcs_sim -C sum

.PHONY: test
test:
	make test -C bandwidth
	make test -C uart_loader
	make test -C simd
	make test -C sum

.PHONY: vcs_test
vcs_test:
	make vcs_test -C bandwidth
	make vcs_test -C uart_loader
	make vcs_test -C simd
	make vcs_test -C sum
