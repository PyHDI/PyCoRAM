.PHONY: clean
clean:
	make clean -C cache
	make clean -C heap
	make clean -C heap_ocm

.PHONY: build
build:
	make build -C cache
	make build -C heap
	make build -C heap_ocm

.PHONY: sim
sim:
	make sim -C cache
	make sim -C heap
	make sim -C heap_ocm

.PHONY: vcs_sim
vcs_sim:
	make vcs_sim -C cache
	make vcs_sim -C heap
	make vcs_sim -C heap_ocm

.PHONY: test
test:
	make test -C cache
	make test -C heap
	make test -C heap_ocm

.PHONY: vcs_test
vcs_test:
	make vcs_test -C cache
	make vcs_test -C heap
	make vcs_test -C heap_ocm
