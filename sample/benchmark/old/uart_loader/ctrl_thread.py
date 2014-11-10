#-------------------------------------------------------------------------------
# for memory initialization and to notify the execution cycle count
#-------------------------------------------------------------------------------
INIT_BRAM_SIZE = 128
INIT_DRAM_SIZE = 1024 * 8
DSIZE = 4
init_memory = CoramMemory(128, 32, INIT_BRAM_SIZE)
init_channel = CoramChannel(128, 64)

def initialize():
    init_channel.read()
    for dram_addr in range(0, INIT_DRAM_SIZE, INIT_BRAM_SIZE * DSIZE):
        init_channel.read(0)
        init_memory.read(0, dram_addr, INIT_BRAM_SIZE)
        if dram_addr >= INIT_DRAM_SIZE - (INIT_BRAM_SIZE * DSIZE): 
            init_channel.write(1)
        else:
            init_channel.write(0)

def finalize():
    init_channel.write(0)

#-------------------------------------------------------------------------------
# user-defined main method
#-------------------------------------------------------------------------------
def main():
    print("main user-method")
    pass

#-------------------------------------------------------------------------------
while True:
    initialize()
    main()
    finalize()
