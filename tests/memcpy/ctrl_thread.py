DSIZE = 4 # = 32 bit
RAMSIZE = 1024

iochannel = CoramIoChannel(idx=0, datawidth=32)
ram = CoramMemory(idx=0, datawidth=DSIZE*8, size=RAMSIZE, length=1, scattergather=False)
channel = CoramChannel(idx=0, datawidth=32, size=16) # Unused

def body():
    # wait request
    src = iochannel.read()
    dst = iochannel.read()
    size = iochannel.read()

    while True:
        chunk_size = size if size < RAMSIZE * DSIZE else RAMSIZE * DSIZE
        ram.write(0, src, chunk_size/DSIZE) # from DRAM to BlockRAM
        ram.read(0, dst, chunk_size/DSIZE) # from BlockRAM to DRAM
        size -= chunk_size
        src += chunk_size
        dst += chunk_size
        if size == 0: break

    # notification
    iochannel.write(1) 

while True:
    body()
