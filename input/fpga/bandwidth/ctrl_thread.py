#-------------------------------------------------------------------------------
# for memory initialization and to notify the execution cycle count
#-------------------------------------------------------------------------------
INIT_BRAM_SIZE = 128
#INIT_DRAM_SIZE = 1024 * 1024 * 256
#INIT_DRAM_SIZE = 1024 * 1024 * 64
INIT_DRAM_SIZE = 1024 * 256 # for simulation
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
#DATA_SIZE = 1024 * 1024 * 256 # byte
#DATA_SIZE = 1024 * 1024 * 64 # byte
DATA_SIZE = 1024 * 256 # byte, for simulation
RAM_SIZE = 1024 * 1 # entry
USED_RAM_SIZE = 1024 * 1 # entry
N_PAR = 8
REPEAT = ((DATA_SIZE / (USED_RAM_SIZE * 4 * N_PAR)) - 2) / 2

read_ram0 = CoramMemory(0, 32, RAM_SIZE, N_PAR, True)
read_ram1 = CoramMemory(1, 32, RAM_SIZE, N_PAR, True)
write_ram0 = CoramMemory(2, 32, RAM_SIZE, N_PAR, True)
write_ram1 = CoramMemory(3, 32, RAM_SIZE, N_PAR, True)
channel = CoramChannel(0, 64)

def main():
    print("main thread")
    read_addr = 0
    write_addr = DATA_SIZE
    sum = 0

    read_ram0.write_nonblocking(0, read_addr, USED_RAM_SIZE)
    read_ram1.write_nonblocking(0, read_addr+N_PAR*USED_RAM_SIZE*4, USED_RAM_SIZE)
    read_ram0.wait()
    channel.write(USED_RAM_SIZE) # as SIMD 
    read_ram1.wait()
    channel.write(USED_RAM_SIZE) # as SIMD

    for i in range(REPEAT):
        print("loop %d" % i)
        read_addr += (USED_RAM_SIZE*4) * 2 * N_PAR
        
        sum = channel.read()
        write_ram0.read_nonblocking(0, write_addr, USED_RAM_SIZE)
        read_ram0.write_nonblocking(0, read_addr, USED_RAM_SIZE)
        write_ram0.wait()
        read_ram0.wait()
        channel.write(USED_RAM_SIZE)

        sum = channel.read()
        write_ram1.read_nonblocking(0, write_addr+N_PAR*USED_RAM_SIZE*4, USED_RAM_SIZE)
        read_ram1.write_nonblocking(0, read_addr+N_PAR*USED_RAM_SIZE*4, USED_RAM_SIZE)
        write_ram1.wait()
        read_ram1.wait()
        channel.write(USED_RAM_SIZE)

        write_addr += (USED_RAM_SIZE*4) * 2 * N_PAR

    sum = channel.read()
    write_ram0.read_nonblocking(0, write_addr, USED_RAM_SIZE)
    sum = channel.read()
    write_ram1.read_nonblocking(0, write_addr+N_PAR*USED_RAM_SIZE*4, USED_RAM_SIZE)
    write_ram0.wait()
    write_ram1.wait()

    channel.write(0)

    print('sum=', sum)

#-------------------------------------------------------------------------------
while True:
    initialize()
    main()
    finalize()
