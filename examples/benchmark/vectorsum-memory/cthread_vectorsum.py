#-------------------------------------------------------------------------------
# Parameters
#-------------------------------------------------------------------------------
#SIMD_WIDTH = 8 # should be power of 2
#SIMD_WIDTH = 4 # should be power of 2
#SIMD_WIDTH = 2 # should be power of 2
SIMD_WIDTH = 1 # should be power of 2

DSIZE = 4

RAM_SIZE = 1024 * 1 # entry
USED_RAM_SIZE = 1024 * 1 # entry

# default value
data_size = 1024
mem_offset = 0
cyclecount = 0

#-------------------------------------------------------------------------------
# IO channel
#-------------------------------------------------------------------------------
iochannel = CoramIoChannel(idx=0, datawidth=32)

#-------------------------------------------------------------------------------
# Computation
#-------------------------------------------------------------------------------
ram = CoramMemory(idx=0, datawidth=8*DSIZE*SIMD_WIDTH, size=RAM_SIZE, length=2, scattergather=False)
channel = CoramChannel(0, 8*DSIZE)

def vectorsum():
    read_addr = mem_offset
    sum = 0

    ram.write(0, read_addr+0*USED_RAM_SIZE*DSIZE*SIMD_WIDTH, USED_RAM_SIZE)
    channel.write(USED_RAM_SIZE)

    ram.write(RAM_SIZE, read_addr+1*USED_RAM_SIZE*DSIZE*SIMD_WIDTH, USED_RAM_SIZE)
    channel.write(USED_RAM_SIZE)

    for i in range(((data_size / (USED_RAM_SIZE * SIMD_WIDTH)) - 2) / 2):
        read_addr += (USED_RAM_SIZE*DSIZE*SIMD_WIDTH) * 2
        
        channel.read()
        ram.write(0, read_addr, USED_RAM_SIZE)
        channel.write(USED_RAM_SIZE)

        channel.read()
        ram.write(RAM_SIZE, read_addr+USED_RAM_SIZE*DSIZE*SIMD_WIDTH, USED_RAM_SIZE)
        channel.write(USED_RAM_SIZE)

    sum = channel.read()
    sum = channel.read()

    channel.write(0)

    global cyclecount
    cyclecount = channel.read()

    return sum

#-------------------------------------------------------------------------------
def main():
    global mem_offset
    global data_size

    mem_offset = iochannel.read()
    print("thread: mem_offset=%d" % mem_offset)

    data_size = iochannel.read()
    print("thread: data_size=%d" % data_size)

    print("thread: vectorsum")
    rslt = vectorsum()

    iochannel.write(rslt)
    iochannel.write(cyclecount)

#-------------------------------------------------------------------------------
while True:
    main()
