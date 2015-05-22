#INPUT=n2048.gr
INPUT=USA-road-d.NY.gr
#INPUT=USA-road-d.CAL.gr
#INPUT=USA-road-d.COL.gr

#EDGES_PER_PAGE=128
EDGES_PER_PAGE=8

NUM_NODES = 100
NUM_EDGES = 2000
#NUM_NODES = 400
#NUM_EDGES = 80000

#GLOBAL_OFFSET=$(shell printf "%d" 0xa8000000)
GLOBAL_OFFSET=0

#MEM_SIZE     =$(shell printf "%d" 0x00100000)
#PAGE_OFFSET  =$(shell printf "%d" 0x00000100)
#NODE_OFFSET  =$(shell printf "%d" 0x00040000)
#IDTB_OFFSET  =$(shell printf "%d" 0x00080000)
#ADTB_OFFSET  =$(shell printf "%d" 0x00090000)

MEM_SIZE   =$(shell printf "%d" 0x08000000)
PAGE_OFFSET=$(shell printf "%d" 0x00000100)
NODE_OFFSET=$(shell printf "%d" 0x06000000)
IDTB_OFFSET=$(shell printf "%d" 0x07000000)
ADTB_OFFSET=$(shell printf "%d" 0x07400000)

.PHONY: convert
convert:
	python convert.py $(INPUT)

.PHONY: gen
gen:
	python memgen.py --mem_size=$(MEM_SIZE) --page_offset=$(PAGE_OFFSET) --node_offset=$(NODE_OFFSET) --idtb_offset=$(IDTB_OFFSET) --adtb_offset=$(ADTB_OFFSET) --global_offset=$(GLOBAL_OFFSET) --edges_per_page=$(EDGES_PER_PAGE) $(INPUT)
#	python bin2hex.py -o out.hex --size=1 out.bin 

.PHONY: random
random:
	python memgen_random.py --mem_size=$(MEM_SIZE) --page_offset=$(PAGE_OFFSET) --node_offset=$(NODE_OFFSET) --idtb_offset=$(IDTB_OFFSET) --adtb_offset=$(ADTB_OFFSET) --global_offset=$(GLOBAL_OFFSET) --edges_per_page=$(EDGES_PER_PAGE) --num_nodes=$(NUM_NODES) --num_edges=$(NUM_EDGES)

.PHONY: clean
clean:
	rm -f out.bin out.hex out.dat
