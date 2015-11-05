.PHONY: clean
clean:
	find . -maxdepth 1 -type d |grep "./" | xargs -I {} make clean -C {} 

.PHONY: build
build:
	find . -maxdepth 1 -type d |grep "./" | xargs -I {} make clean -C {} 

.PHONY: sim
sim:
	find . -maxdepth 1 -type d |grep "./" | xargs -I {} make clean -C {} 

.PHONY: vcs_sim
vcs_sim:
	find . -maxdepth 1 -type d |grep "./" | xargs -I {} make clean -C {} 

.PHONY: test
test:
	find . -maxdepth 1 -type d |grep "./" | xargs -I {} make clean -C {} 

.PHONY: vcs_test
vcs_test:
	find . -maxdepth 1 -type d |grep "./" | xargs -I {} make clean -C {} 
