#-------------------------------------------------------------------------------
# Parameters
#-------------------------------------------------------------------------------
# Mesh size n = i * 16 (where i = 1, 2, 3, ...)

#BWRATE = 8
#BWRATE = 4
#BWRATE = 2
BWRATE = 1

DSIZE = 4
SIZE = 512 # word

# default value
a_offset = 1 * 1024 * 1024
b_offset = 2 * 1024 * 1024
cyclecount = 0

#-------------------------------------------------------------------------------
# IO channel
#-------------------------------------------------------------------------------
iochannel = CoramIoChannel(idx=0, datawidth=32)

#-------------------------------------------------------------------------------
# Computation
#-------------------------------------------------------------------------------
mem0 = CoramMemory(idx=0, datawidth=8*DSIZE*BWRATE, size=SIZE/BWRATE, length=4, scattergather=False)
mem_d0 = CoramOutStream(idx=0, datawidth=8*DSIZE*BWRATE, size=SIZE/BWRATE)

channel = CoramChannel(idx=0, datawidth=8*DSIZE)

#-------------------------------------------------------------------------------
def st_set_mesh_size(mesh_size):
    channel.write(mesh_size)
        
#-------------------------------------------------------------------------------
def st_step(mesh_size, read_start, read_buf2):
    read_page = 3
    read_addr = read_start

    mem0.write_nonblocking(0, read_addr, mesh_size/BWRATE)
    read_addr += mesh_size * DSIZE

    mem0.write_nonblocking(SIZE/BWRATE, read_addr, mesh_size/BWRATE)
    read_addr += mesh_size * DSIZE

    mem0.write_nonblocking((SIZE+SIZE)/BWRATE, read_addr, mesh_size/BWRATE)
    read_addr += mesh_size * DSIZE

    pos = ( (read_buf2 << 7) |
            (0x1 << 4) | # hot_spot
            (0x1 << read_page) )

    mem0.wait()

    for i in range(mesh_size - 2):
        channel.write(pos)

        if read_page == 0:
            mem0.write_nonblocking(0, read_addr, mesh_size/BWRATE)
            read_addr += mesh_size * DSIZE
        elif read_page == 1:
            mem0.write_nonblocking(SIZE/BWRATE, read_addr, mesh_size/BWRATE)
            read_addr += mesh_size * DSIZE
        elif read_page == 2:
            mem0.write_nonblocking((SIZE+SIZE)/BWRATE, read_addr, mesh_size/BWRATE)
            read_addr += mesh_size * DSIZE
        elif read_page == 3:
            mem0.write_nonblocking((SIZE+SIZE+SIZE)/BWRATE, read_addr, mesh_size/BWRATE)
            read_addr += mesh_size * DSIZE
        
        read_page = 0 if read_page == 3 else read_page + 1

        pos = ( (read_buf2 << 7) |
                (0x1 << read_page) )

        channel.read()
        mem0.wait()

#-------------------------------------------------------------------------------
def st_computation(num_iter, mesh_size):
    total_read_size = 0;
    for i in range(mesh_size - 2):
        total_read_size += mesh_size / BWRATE

    for i in range(num_iter / 2):
        mem_d0.read_nonblocking(b_offset+mesh_size*DSIZE, total_read_size)
        st_step(mesh_size, a_offset, False)
        mem_d0.wait()

        mem_d0.read_nonblocking(a_offset+mesh_size*DSIZE, total_read_size)
        st_step(mesh_size, b_offset, True)
        mem_d0.wait()

#-------------------------------------------------------------------------------
def st_sum(mesh_size):
    check_sum = 0
    read_addr = a_offset
    for i in range(mesh_size):
        mem0.write(0, read_addr, mesh_size/BWRATE)
        init_sum = 1 if i == 0 else 0
        calc_sum = 1
        pos = (init_sum << 6) | (calc_sum << 5)
        channel.write(pos)
        read_addr += mesh_size * DSIZE
        check_sum = channel.read()
    channel.write(0) # reset main pipeline

    global cyclecount
    cyclecount = channel.read()

    return check_sum

#-------------------------------------------------------------------------------
def st_main():
    global a_offset
    global b_offset

    mesh_size = iochannel.read()
    print("thread: mesh_size=%d" % mesh_size)
    num_iter = iochannel.read()
    print("thread: num_iter=%d" % num_iter)
    a_offset = iochannel.read()
    print("thread: a_offset=%d" % a_offset)
    b_offset = iochannel.read()
    print("thread: b_offset=%d" % b_offset)

    print("thread: st_set_mesh_size")
    st_set_mesh_size(mesh_size)

    print("thread: st_computation")
    st_computation(num_iter, mesh_size)

    print("thread: st_sum")
    check_sum = st_sum(mesh_size)

    iochannel.write(check_sum)
    iochannel.write(cyclecount)

#-------------------------------------------------------------------------------
while True:
    st_main()
