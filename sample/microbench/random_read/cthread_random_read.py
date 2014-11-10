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
address_width = 17
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
# XORSHIFT random generator
#-------------------------------------------------------------------------------
__x = 123456789
__y = 362436069
__z = 521288629
__w = 88675123 

def xorshift():
    global __x, __y, __z, __w;
    t = __x ^ (__x << 11)
    __x = __y
    __y = __z
    __z = __w
    __w = (__w ^ (__w >> 19)) ^ (t ^ (t >> 8))
    return __w

def reset_xorshift():
    global __x, __y, __z, __w;
    __x = 123456789
    __y = 362436069
    __z = 521288629
    __w = 88675123 

#-------------------------------------------------------------------------------
def random_read():
    if dma_size == 0 or data_size == 0: return 0

    address_mask = 0
    for i in range(address_width):
        if i < 6: continue # for address alignment
        address_mask |= (0x1 << i)

    read_addr = mem_offset + (xorshift() & address_mask)
    read_size = data_size

    channel.write(0) # start

    while read_size > 0:
        ram.write_nonblocking(0, read_addr, dma_size if dma_size < read_size else read_size)
        read_size -= dma_size if dma_size < read_size else read_size
        read_addr = mem_offset + (xorshift() & address_mask)

    ram.wait()
    channel.write(0) # stop

    reset_xorshift()

    cyclecount = channel.read()
    return cyclecount

#-------------------------------------------------------------------------------
def main():
    global mem_offset
    global address_width
    global dma_size
    global data_size

    mem_offset = iochannel.read()
    print("thread: mem_offset=%d" % mem_offset)

    address_width = iochannel.read()
    print("thread: address_width=%d" % address_width)

    dma_size = iochannel.read()
    print("thread: dma_size=%d" % dma_size)

    data_size = iochannel.read()
    print("thread: data_size=%d" % data_size)

    print("thread: random_read")
    cyclecount = random_read()
    iochannel.write(cyclecount)

#-------------------------------------------------------------------------------
while True:
    main()
