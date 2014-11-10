#-------------------------------------------------------------------------------
# Parameters
#-------------------------------------------------------------------------------
#SIMD_WIDTH = 8 # should be power of 2
#SIMD_WIDTH = 4 # should be power of 2
#SIMD_WIDTH = 2 # should be power of 2
SIMD_WIDTH = 1 # should be power of 2

DSIZE = 4
RAM_SIZE = 1024 * 4 # entry

# default value
mem_offset = 0
dma_size = 128
data_size = 1024

#-------------------------------------------------------------------------------
# IO channel
#-------------------------------------------------------------------------------
iochannel = CoramIoChannel(idx=0, datawidth=32)

#-------------------------------------------------------------------------------
# Computation
#-------------------------------------------------------------------------------
ram = CoramMemory(idx=0, datawidth=8*DSIZE*SIMD_WIDTH, size=RAM_SIZE)
channel = CoramChannel(0, 8*DSIZE)

#-------------------------------------------------------------------------------
def pointer_read_memory():
    if dma_size == 0 or data_size == 0: return 0

    read_addr = mem_offset
    read_size = data_size

    channel.write(0) # start

    while read_size > 0:
        ram.write_nonblocking(0, read_addr, dma_size if dma_size < read_size else read_size)
        read_size -= dma_size if dma_size < read_size else read_size
        ram.wait()
        channel.write(dma_size)
        read_addr = channel.read()

    ram.wait()
    channel.write(0) # stop

    cyclecount = channel.read()
    return cyclecount

#-------------------------------------------------------------------------------
def main():
    global mem_offset
    global dma_size
    global data_size

    mem_offset = iochannel.read()
    print("thread: mem_offset=%d" % mem_offset)

    dma_size = iochannel.read()
    print("thread: dma_size=%d" % dma_size)

    data_size = iochannel.read()
    print("thread: data_size=%d" % data_size)

    print("thread: pointer_read_memory")
    cyclecount = pointer_read_memory()
    iochannel.write(cyclecount)

#-------------------------------------------------------------------------------
while True:
    main()
