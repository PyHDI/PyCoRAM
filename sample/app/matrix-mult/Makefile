.PHONY: clean
clean:
	make clean -C matrix-mult
	make clean -C matrix-mult-memory
	make clean -C matrix-mult-separate
	make clean -C matrix-mult-stream
	make clean -C matrix-mult-stream-light

.PHONY: build
build:
	make build -C matrix-mult
	make build -C matrix-mult-memory
	make build -C matrix-mult-separate
	make build -C matrix-mult-stream
	make build -C matrix-mult-stream-light

.PHONY: sim
sim:
	make sim -C matrix-mult
	make sim -C matrix-mult-memory
	make sim -C matrix-mult-separate
	make sim -C matrix-mult-stream
	make sim -C matrix-mult-stream-light

.PHONY: vcs_sim
vcs_sim:
	make vcs_sim -C matrix-mult
	make vcs_sim -C matrix-mult-memory
	make vcs_sim -C matrix-mult-separate
	make vcs_sim -C matrix-mult-stream
	make vcs_sim -C matrix-mult-stream-light

.PHONY: test
test:
	make test -C matrix-mult
	make test -C matrix-mult-memory
	make test -C matrix-mult-separate
	make test -C matrix-mult-stream
	make test -C matrix-mult-stream-light

.PHONY: vcs_test
vcs_test:
	make vcs_test -C matrix-mult
	make vcs_test -C matrix-mult-mememory
	make vcs_test -C matrix-mult-separate
	make vcs_test -C matrix-mult-stream
	make vcs_test -C matrix-mult-stream-light
