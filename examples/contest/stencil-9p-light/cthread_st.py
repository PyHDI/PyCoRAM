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
mem0 = CoramMemory(idx=0, datawidth=8*DSIZE, size=SIZE) # source 0
mem1 = CoramMemory(idx=1, datawidth=8*DSIZE, size=SIZE) # source 1
mem2 = CoramMemory(idx=2, datawidth=8*DSIZE, size=SIZE) # source 2
mem_d0 = CoramMemory(idx=4, datawidth=8*DSIZE, size=SIZE) # destination 0
channel = CoramChannel(idx=0, datawidth=8*DSIZE)

#-------------------------------------------------------------------------------
def st_set_mesh_size(mesh_size):
    channel.write(mesh_size)
        
#-------------------------------------------------------------------------------
def st_step(mesh_size, read_start, write_start):
    read_page = 0
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
        pos = hot_spot

        mem0.wait()
        mem1.wait()
        mem2.wait()

        channel.write(pos)
        channel.read()

        if read_page == 0:
            mem0.write_nonblocking(0, read_addr, mesh_size)
        elif read_page == 1:
            mem1.write_nonblocking(0, read_addr, mesh_size)
        elif read_page == 2:
            mem2.write_nonblocking(0, read_addr, mesh_size)
        
        read_page = 0 if read_page == 2 else read_page + 1
        read_addr += mesh_size * DSIZE

        mem_d0.read_nonblocking(1, write_addr, mesh_size-2)
        write_addr += mesh_size * DSIZE
        mem_d0.wait()

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
        pos = (init_sum << 2) | (calc_sum << 1)
        channel.write(pos)
        read_addr += mesh_size * DSIZE
        check_sum = channel.read()
    channel.write(0xff) # reset main pipeline
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
