#-------------------------------------------------------------------------------
# 330_stencil
# Processor Design Contest
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Parameters
#-------------------------------------------------------------------------------
# Mesh size n = i * 16 (where i = 1, 2, 3, ...)
# Max Mesh Size = 4096 (i = 256)
# Actual Max Mesh Size = 512 (according to the reference program)

DSIZE = 4
INIT_DATA_SIZE = 256 * 1024 # byte

INIT_MEM_SIZE = 8 # entry
SIZE = 512 # word

tmp_offset = 256 * 1024
a_offset = 1 * 1024 * 1024
b_offset = 2 * 1024 * 1024

#-------------------------------------------------------------------------------
# IO channel
#-------------------------------------------------------------------------------
iochannel = CoramIoChannel(idx=0, datawidth=32)

#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------
init_zero_mem = CoramMemory(idx=101, datawidth=8*DSIZE, size=INIT_MEM_SIZE)

#-------------------------------------------------------------------------------
# Computation
#-------------------------------------------------------------------------------
mem0 = CoramMemory(idx=0, datawidth=8*DSIZE, size=SIZE) # source 0
mem1 = CoramMemory(idx=1, datawidth=8*DSIZE, size=SIZE) # source 1
mem2 = CoramMemory(idx=2, datawidth=8*DSIZE, size=SIZE) # source 2
mem3 = CoramMemory(idx=3, datawidth=8*DSIZE, size=SIZE) # source 3
mem_d0 = CoramMemory(idx=4, datawidth=8*DSIZE, size=SIZE) # destination 0
mem_d1 = CoramMemory(idx=5, datawidth=8*DSIZE, size=SIZE) # destination 1
channel = CoramChannel(idx=0, datawidth=8*DSIZE)

#-------------------------------------------------------------------------------
def st_set_mesh_size(mesh_size):
    channel.write(mesh_size)

#-------------------------------------------------------------------------------
def st_init_memory(mesh_size):
    whole_size = 0
    for i in range(mesh_size):
        whole_size += mesh_size

    copy_size = 0

    # copy init_data to mesh A
    a_read_addr = tmp_offset
    a_write_offset = a_offset
    a_write_addr = a_write_offset

    total_count = 0
    while total_count < whole_size:
        # BRAM size check
        copy_size = SIZE if mesh_size > SIZE else mesh_size

        # copy size check
        if a_read_addr + (copy_size * DSIZE) >= tmp_offset + INIT_DATA_SIZE:
            minus_copy_size = ((a_read_addr + (copy_size * DSIZE)) - (tmp_offset + INIT_DATA_SIZE)) / DSIZE
            copy_size -= minus_copy_size

        if copy_size + total_count > whole_size:
            copy_size = whole_size - total_count

        # read data from init_data
        mem0.write(0, a_read_addr, copy_size)
        # write data to mesh area
        mem0.read(0, a_write_addr, copy_size)

        total_count += copy_size

        # next read address
        a_write_offset += copy_size * DSIZE
        a_write_addr = a_write_offset
        a_read_addr += copy_size * DSIZE
        
        # read address check
        if a_read_addr >= tmp_offset + INIT_DATA_SIZE:
            a_read_addr -= INIT_DATA_SIZE

    # copy zero data to mesh B
    b_write_offset = b_offset
    b_write_addr = b_write_offset
    total_count = 0
    while total_count < whole_size:
        copy_size = INIT_MEM_SIZE
        if copy_size + total_count > whole_size:
            copy_size = whole_size - total_count
        # write data to mesh area
        init_zero_mem.read(0, b_write_addr, copy_size)
        # next read address
        total_count += copy_size
        b_write_offset += copy_size * DSIZE
        b_write_addr = b_write_offset
        
#-------------------------------------------------------------------------------
def st_step(mesh_size, read_start, write_start):
    read_page = 3
    write_page = 0

    read_addr = read_start

    mem0.write(0, read_addr, mesh_size)
    read_addr += mesh_size * DSIZE

    mem1.write(0, read_addr, mesh_size)
    read_addr += mesh_size * DSIZE

    mem2.write(0, read_addr, mesh_size)
    read_addr += mesh_size * DSIZE

    write_addr = write_start + mesh_size * DSIZE + DSIZE

    for i in range(mesh_size - 2):
        hot_spot = 1 if i == 0 else 0
        pos = ( (hot_spot << 6) |
                ((0x1 << write_page) << 4) |
                (0x1 << read_page) )

        mem0.wait()
        mem1.wait()
        mem2.wait()
        mem3.wait()

        channel.write(pos)

        if read_page == 0:
            mem0.write_nonblocking(0, read_addr, mesh_size)
        elif read_page == 1:
            mem1.write_nonblocking(0, read_addr, mesh_size)
        elif read_page == 2:
            mem2.write_nonblocking(0, read_addr, mesh_size)
        elif read_page == 3:
            mem3.write_nonblocking(0, read_addr, mesh_size)
        
        read_page = 0 if read_page == 3 else read_page + 1
        read_addr += mesh_size * DSIZE

        channel.read()

        mem_d0.wait()
        mem_d1.wait()

        if write_page == 0:
            mem_d0.read_nonblocking(1, write_addr, mesh_size-2)
        elif write_page == 1:
            mem_d1.read_nonblocking(1, write_addr, mesh_size-2)

        write_addr += mesh_size * DSIZE
        write_page = 0 if write_page == 1 else write_page + 1

    mem_d0.wait()
    mem_d1.wait()

#-------------------------------------------------------------------------------
def st_computation(num_iter, mesh_size):
    for i in range(num_iter / 2):
        st_step(mesh_size, a_offset, b_offset)
        st_step(mesh_size, b_offset, a_offset)

#-------------------------------------------------------------------------------
def st_sum(mesh_size):
    check_sum = 0
    read_addr = a_offset
    for i in range(mesh_size):
        mem0.write(0, read_addr, mesh_size)
        init_sum = 1 if i == 0 else 0
        calc_sum = 1
        pos = (init_sum << 8) | (calc_sum << 7)
        channel.write(pos)
        read_addr += mesh_size * DSIZE
        check_sum = channel.read()
    channel.write(0) # reset main pipeline
    return check_sum

#-------------------------------------------------------------------------------
def st_main():
    mesh_size = iochannel.read()
    num_iter = iochannel.read()
    print("thread: mesh_size=%d" % mesh_size)
    print("thread: num_iter=%d" % num_iter)

    print("thread: st_set_mesh_size")
    st_set_mesh_size(mesh_size)

    print("thread: st_init_memory")
    st_init_memory(mesh_size)

    print("thread: st_computation")
    st_computation(num_iter, mesh_size)

    print("thread: st_sum")
    check_sum = st_sum(mesh_size)

    iochannel.write(check_sum)

#-------------------------------------------------------------------------------
while True:
    st_main()
