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

INIT_DATA_SIZE = 256 * 1024 # byte
DSIZE = 4

#INIT_MEM_SIZE = 128 # entry
INIT_MEM_SIZE = 32 # entry

MM_MEM_A_SIZE = 512 # entry (Max Matrix Size = 512)
#MM_MEM_B_SIZE = 256 # entry (used as double bufferred)
MM_MEM_B_SIZE = 128 # entry (used as double bufferred)
MM_MEM_C_SIZE = 512 # entry (Max Matrix Size = 512)

c_tmp_offset = 256 * 1024
a_tmp_offset = 4 * 1024 * 1024
b_tmp_offset = 5 * 1024 * 1024

a_offset = 1 * 1024 * 1024
b_offset = 2 * 1024 * 1024
c_offset = 3 * 1024 * 1024
b_page = False

#-------------------------------------------------------------------------------
# IO channel
#-------------------------------------------------------------------------------
iochannel = CoramIoChannel(idx=0, datawidth=32)

#-------------------------------------------------------------------------------
# Initialization (c->a, b)
#-------------------------------------------------------------------------------
init_mem_c = CoramMemory(idx=102, datawidth=8*DSIZE, size=INIT_MEM_SIZE*2)
init_mem_a = CoramMemory(idx=100, datawidth=8*DSIZE, size=INIT_MEM_SIZE)
init_mem_b = CoramMemory(idx=101, datawidth=8*DSIZE, size=INIT_MEM_SIZE)
init_channel = CoramChannel(idx=100, datawidth=8*DSIZE)

#-------------------------------------------------------------------------------
# Computation
# Memory B is transposed.
#-------------------------------------------------------------------------------
mem_a = CoramMemory(idx=0, datawidth=8*DSIZE, size=MM_MEM_A_SIZE)
mem_b = CoramMemory(idx=1, datawidth=8*DSIZE, size=MM_MEM_B_SIZE)
mem_c = CoramMemory(idx=2, datawidth=8*DSIZE, size=MM_MEM_C_SIZE)
channel = CoramChannel(idx=0, datawidth=8*DSIZE)

#-------------------------------------------------------------------------------
def mm_init(loader_size):
    init_channel.write(loader_size)
    c_addr = c_tmp_offset
    a_addr = a_tmp_offset
    b_addr = b_tmp_offset
    for i in range(INIT_DATA_SIZE / INIT_MEM_SIZE / DSIZE / 2):
        init_mem_c.write(0, c_addr, INIT_MEM_SIZE*2)
        init_channel.write(0)
        c_addr += INIT_MEM_SIZE * DSIZE * 2
        init_channel.read()
        init_mem_a.read_nonblocking(0, a_addr, INIT_MEM_SIZE)
        a_addr += INIT_MEM_SIZE * DSIZE
        init_mem_b.read_nonblocking(0, b_addr, INIT_MEM_SIZE)
        b_addr += INIT_MEM_SIZE * DSIZE
        init_mem_a.wait()
        init_mem_b.wait()

#-------------------------------------------------------------------------------
def mm_set_matrix_size(matrix_size):
    channel.write(matrix_size)

#-------------------------------------------------------------------------------
def mm_init_memory(matrix_size):
    whole_size = 0
    for i in range(matrix_size):
        whole_size += matrix_size

    copy_size = 0

    # copy init_data to matrix A
    b_read_addr = b_tmp_offset
    b_write_offset = b_offset
    b_write_addr = b_write_offset

    read_count = 0
    total_count = 0
    while total_count < whole_size:
        # BRAM size check
        copy_size = MM_MEM_C_SIZE if matrix_size > MM_MEM_C_SIZE else matrix_size

        tmp_minus = 0
        # copy size check
        if b_read_addr + (copy_size * DSIZE) >= b_tmp_offset + (INIT_DATA_SIZE / 2):
            minus_copy_size = ((b_read_addr + (copy_size * DSIZE)) - (b_tmp_offset + (INIT_DATA_SIZE / 2))) / DSIZE
            copy_size -= minus_copy_size
            tmp_minus = minus_copy_size

        if copy_size + total_count > whole_size:
            copy_size = whole_size - total_count

        # read data from init_data
        mem_c.write(0, b_read_addr, copy_size)

        # write data to matrix area (scatter)
        for j in range(copy_size):
            mem_c.read_nonblocking(j, b_write_addr, 1)
            b_write_addr += matrix_size * DSIZE # next row
            read_count += 1
            total_count += 1
            if total_count >= whole_size:
                break
            if read_count == matrix_size:
                b_write_offset += DSIZE # byte
                b_write_addr = b_write_offset
                read_count = 0
        
        # wait for previous write requests
        mem_c.wait()

        # next read address
        b_read_addr += copy_size * DSIZE
        
        # read address check
        if b_read_addr >= b_tmp_offset + (INIT_DATA_SIZE / 2):
            b_read_addr -= (INIT_DATA_SIZE / 2)
            
    # wait for all previous requests
    mem_c.wait()

    # copy init_data to matrix A
    a_read_addr = a_tmp_offset
    a_write_offset = a_offset
    a_write_addr = a_write_offset

    total_count = 0
    while total_count < whole_size:
        # BRAM size check
        copy_size = MM_MEM_C_SIZE if matrix_size > MM_MEM_C_SIZE else matrix_size

        # copy size check
        if a_read_addr + (copy_size * DSIZE) >= a_tmp_offset + (INIT_DATA_SIZE / 2):
            minus_copy_size = ((a_read_addr + (copy_size * DSIZE)) - (a_tmp_offset + (INIT_DATA_SIZE / 2))) / DSIZE
            copy_size -= minus_copy_size

        if copy_size + total_count > whole_size:
            copy_size = whole_size - total_count

        # read data from init_data
        mem_c.write(0, a_read_addr, copy_size)
        # write data to matrix area
        mem_c.read(0, a_write_addr, copy_size)

        total_count += copy_size

        # next read address
        a_write_offset += copy_size * DSIZE
        a_write_addr = a_write_offset
        a_read_addr += copy_size * DSIZE
        
        # read address check
        if a_read_addr >= a_tmp_offset + (INIT_DATA_SIZE / 2):
            a_read_addr -= (INIT_DATA_SIZE / 2)
        
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
        mem_b.write(0, b_addr, read_size) # page 0
    else:
        mem_b.write(MM_MEM_B_SIZE/2, b_addr, read_size) # page 1
    channel.write(read_size) # computation size
    b_addr += read_size * DSIZE
    b_page = not b_page

    read_size = (rest_read_size if rest_read_size < MM_MEM_B_SIZE/2 else MM_MEM_B_SIZE/2)
    rest_read_size = (0 if rest_read_size < MM_MEM_B_SIZE/2 else rest_read_size - MM_MEM_B_SIZE/2)

    if not b_page:
        mem_b.write(0, b_addr, read_size) # page 0
    else:
        mem_b.write(MM_MEM_B_SIZE/2, b_addr, read_size) # page 1
    channel.write(read_size) # computation size
    b_addr += read_size * DSIZE
    b_page = not b_page

    while rest_read_size > 0:
        check_sum = channel.read()

        read_size = (rest_read_size if rest_read_size < MM_MEM_B_SIZE/2 else MM_MEM_B_SIZE/2)
        rest_read_size = (0 if rest_read_size < MM_MEM_B_SIZE/2 else rest_read_size - MM_MEM_B_SIZE/2)

        if not b_page:
            mem_b.write(0, b_addr, read_size) # page 0
        else:
            mem_b.write(MM_MEM_B_SIZE/2, b_addr, read_size) # page 1
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
        mem_c.read(0, c_addr, matrix_size)
        a_addr += matrix_size * DSIZE
        c_addr += matrix_size * DSIZE
    channel.write(0) # reset main pipeline
    return check_sum

#-------------------------------------------------------------------------------
def mm_main():
    loader_size = iochannel.read()
    matrix_size = iochannel.read()
    print("thread: loader_size=%d" % loader_size)
    print("thread: matrix_size=%d" % matrix_size)

    print("thread: mm_init")
    mm_init(loader_size)

    print("thread: mm_set_matrix_size")
    mm_set_matrix_size(matrix_size)

    print("thread: mm_init_memory")
    mm_init_memory(matrix_size)

    print("thread: mm_computation")
    check_sum = mm_computation(matrix_size)

    iochannel.write(check_sum)

#-------------------------------------------------------------------------------
while True:
    mm_main()
