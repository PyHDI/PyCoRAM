#-------------------------------------------------------------------------------
# 320_mm
# Processor Design Contest
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Parameters
#-------------------------------------------------------------------------------
# Matrix size n = i * 16 (where i = 1, 2, 3, ...)
# Max Matrix Size = 4096 (i = 256)
# Actual Max Matrix Size = 512 (according to the reference program)

#SIMD_WIDTH = 8 # should be power of 2
SIMD_WIDTH = 4 # should be power of 2
#SIMD_WIDTH = 2 # should be power of 2
#SIMD_WIDTH = 1 # should be power of 2
MAX_MATRIX_SIZE = 512
DSIZE = 4

MM_MEM_A_SIZE = MAX_MATRIX_SIZE / SIMD_WIDTH
MM_MEM_B_SIZE = MAX_MATRIX_SIZE / SIMD_WIDTH
MM_MEM_C_SIZE = MAX_MATRIX_SIZE / SIMD_WIDTH

# default value
a_offset = 1 * 1024 * 1024
b_offset = 2 * 1024 * 1024
c_offset = 3 * 1024 * 1024
b_page = False

#-------------------------------------------------------------------------------
# IO channel
#-------------------------------------------------------------------------------
iochannel = CoramIoChannel(idx=0, datawidth=32)

#-------------------------------------------------------------------------------
# Computation
# Memory B is transposed.
#-------------------------------------------------------------------------------
mem_a = CoramMemory(idx=0, datawidth=8*DSIZE*SIMD_WIDTH, size=MM_MEM_A_SIZE)
mem_b = CoramInStream(idx=0, datawidth=8*DSIZE*SIMD_WIDTH, size=MM_MEM_A_SIZE)
mem_c = CoramOutStream(idx=0, datawidth=8*DSIZE*SIMD_WIDTH, size=MM_MEM_A_SIZE)
channel = CoramChannel(idx=0, datawidth=8*DSIZE)

#-------------------------------------------------------------------------------
def mm_set_matrix_size(matrix_size):
    channel.write(matrix_size)
        
#-------------------------------------------------------------------------------
def mm_computation(matrix_size):
    a_addr = a_offset
    cyclecount = 0

    total_read_size = 0
    for i in range(matrix_size):
        total_read_size += matrix_size / SIMD_WIDTH

    mem_c.read_nonblocking(c_offset, total_read_size)

    for i in range(matrix_size):
        mem_a.write(0, a_addr, matrix_size / SIMD_WIDTH)
        mem_b.write_nonblocking(b_offset, total_read_size)
        channel.write(total_read_size)
        a_addr += matrix_size * DSIZE
        cyclecount = channel.read()

    mem_c.wait()
    channel.write(0) # reset main pipeline
    return cyclecount

#-------------------------------------------------------------------------------
def mm_main():
    global a_offset
    global b_offset
    global c_offset

    matrix_size = iochannel.read()
    print("thread: matrix_size=%d" % matrix_size)
    a_offset = iochannel.read()
    print("thread: a_offset=%d" % a_offset)
    b_offset = iochannel.read()
    print("thread: b_offset=%d" % b_offset)
    c_offset = iochannel.read()
    print("thread: c_offset=%d" % c_offset)

    print("thread: mm_set_matrix_size")
    mm_set_matrix_size(matrix_size)

    print("thread: mm_computation")
    cyclecount = mm_computation(matrix_size)

    iochannel.write(cyclecount)

#-------------------------------------------------------------------------------
while True:
    mm_main()
