#-------------------------------------------------------------------------------
# for memory initialization and to notify the execution cycle count
#-------------------------------------------------------------------------------
INIT_BRAM_SIZE = 128
#INIT_DRAM_SIZE = 1024 * 1024 * 512
INIT_DRAM_SIZE = 1024 * 1024 * 128
#INIT_DRAM_SIZE = 1024 * 256 # for simulation
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
#DATA_SIZE = 1024 * 1024 * 512 # byte
DATA_SIZE = 1024 * 1024 * 128 # byte
#DATA_SIZE = 1024 * 256 # byte, for simulation
RAM_SIZE = 1024 * 1 # entry
USED_RAM_SIZE = 1024 * 1 # entry
SIMD_SIZE = 512
REPEAT = ((DATA_SIZE / (USED_RAM_SIZE * (SIMD_SIZE / 8))) - 2) / 2

ram0 = CoramMemory(0, SIMD_SIZE, RAM_SIZE)
ram1 = CoramMemory(1, SIMD_SIZE, RAM_SIZE)
channel = CoramChannel(0, 64)

def main():
    print("main thread")
    read_addr = 0
    sum = 0

    ram0.write_nonblocking(0, read_addr+0*USED_RAM_SIZE*(SIMD_SIZE/8), USED_RAM_SIZE)
    ram0.wait()
    channel.write(USED_RAM_SIZE)

    ram1.write_nonblocking(0, read_addr+1*USED_RAM_SIZE*(SIMD_SIZE/8), USED_RAM_SIZE)
    ram1.wait()
    channel.write(USED_RAM_SIZE)

    for i in range(REPEAT):
        print("loop %d" % i)
        read_addr += (USED_RAM_SIZE*(SIMD_SIZE/8)) * 2
        
        sum = channel.read()
        ram0.write_nonblocking(0, read_addr, USED_RAM_SIZE)
        ram0.wait()
        channel.write(USED_RAM_SIZE)

        sum = channel.read()
        ram1.write_nonblocking(0, read_addr+USED_RAM_SIZE*(SIMD_SIZE/8), USED_RAM_SIZE)
        ram1.wait()
        channel.write(USED_RAM_SIZE)

    sum = channel.read()
    sum = channel.read()
    print('sum=', sum)
    channel.write(0)

#-------------------------------------------------------------------------------
while True:
    initialize()
    main()
    finalize()
