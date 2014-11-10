.PHONY: clean
clean:
	make clean -C stencil-9p
	make clean -C stencil-9p-memory
	make clean -C stencil-9p-memory-base
	make clean -C stencil-9p-separate
	make clean -C stencil-9p-stream

.PHONY: build
build:
	make build -C stencil-9p
	make build -C stencil-9p-memory
	make build -C stencil-9p-memory-base
	make build -C stencil-9p-separate
	make build -C stencil-9p-stream

.PHONY: sim
sim:
	make sim -C stencil-9p
	make sim -C stencil-9p-memory
	make sim -C stencil-9p-memory-base
	make sim -C stencil-9p-separate
	make sim -C stencil-9p-stream

.PHONY: vcs_sim
vcs_sim:
	make vcs_sim -C stencil-9p
	make vcs_sim -C stencil-9p-memory
	make vcs_sim -C stencil-9p-memory-base
	make vcs_sim -C stencil-9p-separate
	make vcs_sim -C stencil-9p-stream

.PHONY: test
test:
	make test -C stencil-9p
	make test -C stencil-9p-memory
	make test -C stencil-9p-memory-base
	make test -C stencil-9p-separate
	make test -C stencil-9p-stream

.PHONY: vcs_test
vcs_test:
	make vcs_test -C stencil-9p
	make vcs_test -C stencil-9p-memory
	make vcs_test -C stencil-9p-memory-base
	make vcs_test -C stencil-9p-stream
	make vcs_test -C stencil-9p-separate
