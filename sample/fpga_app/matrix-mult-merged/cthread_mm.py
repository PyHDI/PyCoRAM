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

DSIZE = 4

MM_MEM_A_SIZE = 512 # entry (Max Matrix Size = 512)
MM_MEM_B_SIZE = 512 # entry (used as double bufferred)
MM_MEM_C_SIZE = 512 # entry (Max Matrix Size = 512)

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
mem_a = CoramMemory(idx=0, datawidth=8*DSIZE, length=3, size=MM_MEM_A_SIZE, scattergather=False)
channel = CoramChannel(idx=0, datawidth=8*DSIZE)

#-------------------------------------------------------------------------------
def mm_set_matrix_size(matrix_size):
    channel.write(matrix_size)
        
#-------------------------------------------------------------------------------
def mm_comp_column(matrix_size):
    global b_page
    check_sum = 0
    b_addr = b_offset

    read_size = 0
    rest_read_size = 0
    for i in range(matrix_size):
        rest_read_size += matrix_size

    read_size = (rest_read_size if rest_read_size < MM_MEM_B_SIZE/2 else MM_MEM_B_SIZE/2)
    rest_read_size = (0 if rest_read_size < MM_MEM_B_SIZE/2 else rest_read_size - MM_MEM_B_SIZE/2)

    if not b_page:
        mem_a.write(MM_MEM_A_SIZE+0, b_addr, read_size) # page 0
    else:
        mem_a.write(MM_MEM_A_SIZE+MM_MEM_B_SIZE/2, b_addr, read_size) # page 1
    channel.write(read_size) # computation size
    b_addr += read_size * DSIZE
    b_page = not b_page

    read_size = (rest_read_size if rest_read_size < MM_MEM_B_SIZE/2 else MM_MEM_B_SIZE/2)
    rest_read_size = (0 if rest_read_size < MM_MEM_B_SIZE/2 else rest_read_size - MM_MEM_B_SIZE/2)

    if not b_page:
        mem_a.write(MM_MEM_A_SIZE+0, b_addr, read_size) # page 0
    else:
        mem_a.write(MM_MEM_A_SIZE+MM_MEM_B_SIZE/2, b_addr, read_size) # page 1
    channel.write(read_size) # computation size
    b_addr += read_size * DSIZE
    b_page = not b_page

    while rest_read_size > 0:
        check_sum = channel.read()

        read_size = (rest_read_size if rest_read_size < MM_MEM_B_SIZE/2 else MM_MEM_B_SIZE/2)
        rest_read_size = (0 if rest_read_size < MM_MEM_B_SIZE/2 else rest_read_size - MM_MEM_B_SIZE/2)

        if not b_page:
            mem_a.write(MM_MEM_A_SIZE+0, b_addr, read_size) # page 0
        else:
            mem_a.write(MM_MEM_A_SIZE+MM_MEM_B_SIZE/2, b_addr, read_size) # page 1
        channel.write(read_size) # computation size
        b_addr += read_size * DSIZE
        b_page = not b_page

    check_sum = channel.read()
    check_sum = channel.read()
    
    return check_sum

#-------------------------------------------------------------------------------
def mm_computation(matrix_size):
    a_addr = a_offset
    c_addr = c_offset
    check_sum = 0
    for i in range(matrix_size):
        mem_a.write(0, a_addr, matrix_size)
        check_sum = mm_comp_column(matrix_size)
        mem_a.read(MM_MEM_A_SIZE+MM_MEM_B_SIZE+0, c_addr, matrix_size)
        a_addr += matrix_size * DSIZE
        c_addr += matrix_size * DSIZE
    channel.write(0) # reset main pipeline
    return check_sum

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
    check_sum = mm_computation(matrix_size)

    iochannel.write(check_sum)

#-------------------------------------------------------------------------------
while True:
    mm_main()
