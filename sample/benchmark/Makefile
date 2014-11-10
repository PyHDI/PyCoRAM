.PHONY: clean
clean:
	make clean -C matrix-mult-memory
	make clean -C matrix-mult-stream
	make clean -C stencil-9p-memory
	make clean -C stencil-9p-stream
	make clean -C vectorsum-memory
	make clean -C vectorsum-stream
	make clean -C old

.PHONY: build
build:
	make build -C matrix-mult-memory
	make build -C matrix-mult-stream
	make build -C stencil-9p-memory
	make build -C stencil-9p-stream
	make build -C vectorsum-memory
	make build -C vectorsum-stream
	make build -C old

.PHONY: sim
sim:
	make sim -C matrix-mult-memory
	make sim -C matrix-mult-stream
	make sim -C stencil-9p-memory
	make sim -C stencil-9p-stream
	make sim -C vectorsum-memory
	make sim -C vectorsum-stream
	make sim -C old

.PHONY: vcs_sim
vcs_sim:
	make vcs_sim -C matrix-mult-memory
	make vcs_sim -C matrix-mult-stream
	make vcs_sim -C stencil-9p-memory
	make vcs_sim -C stencil-9p-stream
	make vcs_sim -C vectorsum-memory
	make vcs_sim -C vectorsum-stream
	make vcs_sim -C old

.PHONY: test
test:
	make test -C matrix-mult-memory
	make test -C matrix-mult-stream
	make test -C stencil-9p-memory
	make test -C stencil-9p-stream
	make test -C vectorsum-memory
	make test -C vectorsum-stream
	make test -C old

.PHONY: vcs_test
vcs_test:
	make vcs_test -C matrix-mult-memory
	make vcs_test -C matrix-mult-stream
	make vcs_test -C stencil-9p-memory
	make vcs_test -C stencil-9p-stream
	make vcs_test -C vectorsum-memory
	make vcs_test -C vectorsum-stream
	make vcs_test -C old
