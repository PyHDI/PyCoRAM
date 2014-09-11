.PHONY: clean
clean:
	make clean -C simd_sum_512
	make clean -C simd_sum_256
	make clean -C simd_sum_128
	make clean -C simd_sum_64
	make clean -C simd_sum_32

.PHONY: build
build:
	make build -C simd_sum_512
	make build -C simd_sum_256
	make build -C simd_sum_128
	make build -C simd_sum_64
	make build -C simd_sum_32

.PHONY: test
test:
	make test -C simd_sum_512
	make test -C simd_sum_256
	make test -C simd_sum_128
	make test -C simd_sum_64
	make test -C simd_sum_32

.PHONY: vcs_test
vcs_test:
	make vcs_test -C simd_sum_512
	make vcs_test -C simd_sum_256
	make vcs_test -C simd_sum_128
	make vcs_test -C simd_sum_64
	make vcs_test -C simd_sum_32

DSTDIR=~/pcores_pycoram/

.PHONY: copy
copy:
	cp -r simd_sum_512/pycoram_userlogic_v1_00_a $(DSTDIR)/simd512_pycoram_userlogic_v1_00_a
	cp -r simd_sum_256/pycoram_userlogic_v1_00_a $(DSTDIR)/simd256_pycoram_userlogic_v1_00_a
	cp -r simd_sum_128/pycoram_userlogic_v1_00_a $(DSTDIR)/simd128_pycoram_userlogic_v1_00_a
	cp -r simd_sum_64/pycoram_userlogic_v1_00_a $(DSTDIR)/simd64_pycoram_userlogic_v1_00_a
	cp -r simd_sum_32/pycoram_userlogic_v1_00_a $(DSTDIR)/simd32_pycoram_userlogic_v1_00_a
