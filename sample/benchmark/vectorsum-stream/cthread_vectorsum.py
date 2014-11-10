#-------------------------------------------------------------------------------
# Parameters
#-------------------------------------------------------------------------------
#SIMD_WIDTH = 8 # should be power of 2
#SIMD_WIDTH = 4 # should be power of 2
#SIMD_WIDTH = 2 # should be power of 2
SIMD_WIDTH = 1 # should be power of 2

DSIZE = 4

RAM_SIZE = 1024 * 1 # entry

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
stream = CoramInStream(idx=0, datawidth=8*DSIZE*SIMD_WIDTH, size=RAM_SIZE)
channel = CoramChannel(0, 8*DSIZE)

def vectorsum():
    stream.write_nonblocking(mem_offset, data_size / SIMD_WIDTH)
    channel.write(data_size / SIMD_WIDTH)

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
