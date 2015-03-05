.PHONY: clean
clean:
	make clean -C matrix-mult-init
	make clean -C matrix-mult-init-no-iochannel
	make clean -C matrix-mult-stream-crc
	make clean -C matrix-mult-stream-light-crc
	make clean -C stencil-9p-init
	make clean -C stencil-9p-init-no-iochannel
	make clean -C stencil-9p-light
	make clean -C stencil-9p-light-merged
	make clean -C uart_loader_flush

.PHONY: build
build:
	make build -C matrix-mult-init
	make build -C matrix-mult-init-no-iochannel
	make build -C matrix-mult-stream-crc
	make build -C matrix-mult-stream-light-crc
	make build -C stencil-9p-init
	make build -C stencil-9p-init-no-iochannel
	make build -C stencil-9p-light
	make build -C stencil-9p-light-merged
	make build -C uart_loader_flush

.PHONY: sim
sim:
	make sim -C matrix-mult-init
	make sim -C matrix-mult-init-no-iochannel
	make sim -C matrix-mult-stream-crc
	make sim -C matrix-mult-stream-light-crc
	make sim -C stencil-9p-init
	make sim -C stencil-9p-init-no-iochannel
	make sim -C stencil-9p-light
	make sim -C stencil-9p-light-merged
	make sim -C uart_loader_flush

.PHONY: vcs_sim
vcs_sim:
	make vcs_sim -C matrix-mult-init
	make vcs_sim -C matrix-mult-init-no-iochannel
	make vcs_sim -C matrix-mult-stream-crc
	make vcs_sim -C matrix-mult-stream-light-crc
	make vcs_sim -C stencil-9p-init
	make vcs_sim -C stencil-9p-init-no-iochannel
	make vcs_sim -C stencil-9p-light
	make vcs_sim -C stencil-9p-light-merged
	make vcs_sim -C uart_loader_flush

.PHONY: test
test:
	make test -C matrix-mult-init
	make test -C matrix-mult-init-no-iochannel
	make test -C matrix-mult-stream-crc
	make test -C matrix-mult-stream-light-crc
	make test -C stencil-9p-init
	make test -C stencil-9p-init-no-iochannel
	make test -C stencil-9p-light
	make test -C stencil-9p-light-merged
	make test -C uart_loader_flush

.PHONY: vcs_test
vcs_test:
	make vcs_test -C matrix-mult-init
	make vcs_test -C matrix-mult-init-no-iochannel
	make vcs_test -C matrix-mult-stream-crc
	make vcs_test -C matrix-mult-stream-light-crc
	make vcs_test -C stencil-9p-init
	make vcs_test -C stencil-9p-init-no-iochannel
	make vcs_test -C stencil-9p-light
	make vcs_test -C stencil-9p-light-merged
	make vcs_test -C uart_loader_flush
