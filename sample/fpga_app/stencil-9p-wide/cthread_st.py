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

BWRATE = 2
DSIZE = 4
SIZE = 512 # word

# default value
a_offset = 1 * 1024 * 1024
b_offset = 2 * 1024 * 1024

#-------------------------------------------------------------------------------
# IO channel
#-------------------------------------------------------------------------------
iochannel = CoramIoChannel(idx=0, datawidth=32)

#-------------------------------------------------------------------------------
# Computation
#-------------------------------------------------------------------------------
mem0 = CoramMemory(idx=0, datawidth=8*DSIZE*BWRATE, size=SIZE/BWRATE, length=6, scattergather=False)
channel = CoramChannel(idx=0, datawidth=8*DSIZE)

#-------------------------------------------------------------------------------
def st_set_mesh_size(mesh_size):
    channel.write(mesh_size)
        
#-------------------------------------------------------------------------------
def st_step(mesh_size, read_start, write_start, read_buf2):
    read_page = 3
    write_page = 0

    read_addr = read_start

    mem0.write_nonblocking(0, read_addr, mesh_size/BWRATE)
    read_addr += mesh_size * DSIZE

    mem0.write_nonblocking(SIZE/BWRATE, read_addr, mesh_size/BWRATE)
    read_addr += mesh_size * DSIZE

    mem0.write_nonblocking((SIZE+SIZE)/BWRATE, read_addr, mesh_size/BWRATE)
    read_addr += mesh_size * DSIZE

    write_addr = write_start + mesh_size * DSIZE

    pos = ( (read_buf2 << 9) |
            (0x1 << 6) | # hot_spot
            ((0x1 << write_page) << 4) |
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
        
        if i > 0 and write_page == 1:
            mem0.read_nonblocking(4*SIZE/BWRATE, write_addr, mesh_size/BWRATE)
            write_addr += mesh_size * DSIZE
        elif i > 0 and write_page == 0:
            mem0.read_nonblocking(4*SIZE/BWRATE+SIZE/BWRATE, write_addr, mesh_size/BWRATE)
            write_addr += mesh_size * DSIZE

        read_page = 0 if read_page == 3 else read_page + 1
        write_page = 0 if write_page == 1 else write_page + 1

        pos = ( (read_buf2 << 9) |
                ((0x1 << write_page) << 4) |
                (0x1 << read_page) )

        mem0.wait()
        channel.read()

    if write_page == 1:
        mem0.read_nonblocking(4*SIZE/BWRATE, write_addr, mesh_size/BWRATE)
        write_addr += mesh_size * DSIZE
    elif write_page == 0:
        mem0.read_nonblocking(4*SIZE/BWRATE+SIZE/BWRATE, write_addr, mesh_size/BWRATE)
        write_addr += mesh_size * DSIZE

#-------------------------------------------------------------------------------
def st_computation(num_iter, mesh_size):
    for i in range(num_iter / 2):
        st_step(mesh_size, a_offset, b_offset, False)
        st_step(mesh_size, b_offset, a_offset, True)

#-------------------------------------------------------------------------------
def st_sum(mesh_size):
    check_sum = 0
    read_addr = a_offset
    for i in range(mesh_size):
        mem0.write(0, read_addr, mesh_size/BWRATE)
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

#-------------------------------------------------------------------------------
while True:
    st_main()
