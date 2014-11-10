#-------------------------------------------------------------------------------
# Parameters
#-------------------------------------------------------------------------------
# Matrix size n = i * 16 (where i = 1, 2, 3, ...)
# Max Matrix Size = 512

#SIMD_WIDTH = 8 # should be power of 2
#SIMD_WIDTH = 4 # should be power of 2
#SIMD_WIDTH = 2 # should be power of 2
SIMD_WIDTH = 1 # should be power of 2

DSIZE = 4

MAX_MATRIX_SIZE = 512

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
mem_a = CoramMemory(idx=0, datawidth=8*DSIZE*SIMD_WIDTH, length=3, size=MM_MEM_A_SIZE, scattergather=False)
channel = CoramChannel(idx=0, datawidth=8*DSIZE)

#-------------------------------------------------------------------------------
def mm_set_matrix_size(matrix_size):
    channel.write(matrix_size)
        
#-------------------------------------------------------------------------------
def mm_comp_column(matrix_size, rest_read_size):
    global b_page
    b_addr = b_offset
    cyclecount = 0
    read_size = 0

    read_size = (rest_read_size if rest_read_size < MM_MEM_B_SIZE/2 else MM_MEM_B_SIZE/2)
    rest_read_size = (0 if rest_read_size < MM_MEM_B_SIZE/2 else rest_read_size - MM_MEM_B_SIZE/2)
    ramaddr = MM_MEM_A_SIZE if not b_page else MM_MEM_A_SIZE+MM_MEM_B_SIZE/2
    mem_a.write_nonblocking(ramaddr, b_addr, read_size)
    b_addr += read_size * DSIZE * SIMD_WIDTH
    b_page = not b_page
    mem_a.wait()
    channel.write(read_size) # computation size

    read_size = (rest_read_size if rest_read_size < MM_MEM_B_SIZE/2 else MM_MEM_B_SIZE/2)
    rest_read_size = (0 if rest_read_size < MM_MEM_B_SIZE/2 else rest_read_size - MM_MEM_B_SIZE/2)
    ramaddr = MM_MEM_A_SIZE if not b_page else MM_MEM_A_SIZE+MM_MEM_B_SIZE/2
    mem_a.write_nonblocking(ramaddr, b_addr, read_size)
    b_addr += read_size * DSIZE * SIMD_WIDTH
    b_page = not b_page
    mem_a.wait()
    channel.write(read_size) # computation size

    while rest_read_size > 0:
        read_size = (rest_read_size if rest_read_size < MM_MEM_B_SIZE/2 else MM_MEM_B_SIZE/2)
        rest_read_size = (0 if rest_read_size < MM_MEM_B_SIZE/2 else rest_read_size - MM_MEM_B_SIZE/2)
        ramaddr = MM_MEM_A_SIZE if not b_page else MM_MEM_A_SIZE+MM_MEM_B_SIZE/2
        cyclecount = channel.read()
        mem_a.write_nonblocking(ramaddr, b_addr, read_size)
        b_addr += read_size * DSIZE * SIMD_WIDTH
        b_page = not b_page
        mem_a.wait()
        channel.write(read_size) # computation size

    cyclecount = channel.read()
    cyclecount = channel.read()
    
    return cyclecount

#-------------------------------------------------------------------------------
def mm_computation(matrix_size):
    a_addr = a_offset
    c_addr = c_offset
    cyclecount = 0

    total_read_size = 0
    for i in range(matrix_size):
        total_read_size += matrix_size / SIMD_WIDTH

    for i in range(matrix_size):
        mem_a.write(0, a_addr, matrix_size / SIMD_WIDTH)
        cyclecount = mm_comp_column(matrix_size, total_read_size)
        mem_a.read_nonblocking(MM_MEM_A_SIZE+MM_MEM_B_SIZE+0, c_addr, matrix_size / SIMD_WIDTH)
        a_addr += matrix_size * DSIZE
        c_addr += matrix_size * DSIZE
        mem_a.wait()
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
