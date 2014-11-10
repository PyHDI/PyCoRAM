.PHONY: clean
clean:
	make clean -C dijkstra
	make clean -C matrix-mult
	make clean -C stencil-9p
	make clean -C sum
	make clean -C uart_loader

.PHONY: build
build:
	make build -C dijkstra
	make build -C matrix-mult
	make build -C stencil-9p
	make build -C sum
	make build -C uart_loader

.PHONY: sim
sim:
	make sim -C dijkstra
	make sim -C matrix-mult
	make sim -C matrix-mult-merged
	make sim -C stencil-9p
	make sim -C sum
	make sim -C uart_loader

.PHONY: vcs_sim
vcs_sim:
	make vcs_sim -C dijkstra
	make vcs_sim -C matrix-mult
	make vcs_sim -C stencil-9p
	make vcs_sim -C sum
	make vcs_sim -C uart_loader

.PHONY: test
test:
	make test -C dijkstra
	make test -C matrix-mult
	make test -C stencil-9p
	make test -C sum
	make test -C uart_loader

.PHONY: vcs_test
vcs_test:
	make vcs_test -C dijkstra
	make vcs_test -C matrix-mult
	make vcs_test -C stencil-9p
	make vcs_test -C sum
	make vcs_test -C uart_loader
