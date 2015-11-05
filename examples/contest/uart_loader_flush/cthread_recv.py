#-------------------------------------------------------------------------------
# cthread_recv
#-------------------------------------------------------------------------------
DSIZE = 4 # byte
LOADER_MEM_SIZE = 8 # entry
LOADER_DATA_SIZE = 512 * 1024 # byte (max)

iochannel = CoramIoChannel(idx=0, datawidth=32)
loader_mem = CoramMemory(idx=0, datawidth=8*DSIZE, size=LOADER_MEM_SIZE)
loader_channel = CoramChannel(idx=0, datawidth=8*DSIZE)

def loader_step():
    mem_offset = iochannel.read()
    loader_size = iochannel.read()
    addr = mem_offset
    for i in range(loader_size / LOADER_MEM_SIZE / DSIZE):
        loader_channel.read()
        loader_mem.read_nonblocking(0, addr, LOADER_MEM_SIZE)
        addr += LOADER_MEM_SIZE * DSIZE
        loader_mem.wait()
    print("load done")
    iochannel.write(mem_offset) # return the head address of loaded image

def loader_main():
    while True:
        loader_step()

#-------------------------------------------------------------------------------
loader_main()

