.PHONY: clean
clean:
	make clean -C pointer_read_memory
	make clean -C pointer_read_stream
	make clean -C sequential_read
	make clean -C sequential_write
	make clean -C random_read
	make clean -C random_write

.PHONY: build
build:
	make build -C pointer_read_memory
	make build -C pointer_read_stream
	make build -C sequential_read
	make build -C sequential_write
	make build -C random_read
	make build -C random_write

.PHONY: sim
sim:
	make sim -C pointer_read_memory
	make sim -C pointer_read_stream
	make sim -C sequential_read
	make sim -C sequential_write
	make sim -C random_read
	make sim -C random_write

.PHONY: vcs_sim
vcs_sim:
	make vcs_sim -C pointer_read_memory
	make vcs_sim -C pointer_read_stream
	make vcs_sim -C sequential_read
	make vcs_sim -C sequential_write
	make vcs_sim -C random_read
	make vcs_sim -C random_write

.PHONY: test
test:
	make test -C pointer_read_memory
	make test -C pointer_read_stream
	make test -C sequential_read
	make test -C sequential_write
	make test -C random_read
	make test -C random_write

.PHONY: vcs_test
vcs_test:
	make vcs_test -C pointer_read_memory
	make vcs_test -C pointer_read_stream
	make vcs_test -C sequential_read
	make vcs_test -C sequential_write
	make vcs_test -C random_read
	make vcs_test -C random_write
