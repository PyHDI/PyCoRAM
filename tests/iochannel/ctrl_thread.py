def ctrl_thread():
    iochannel = CoramIoChannel(idx=0, datawidth=32)
    ram = CoramMemory(idx=0, datawidth=32, size=1024, length=1, scattergather=False)
    channel = CoramChannel(idx=0, datawidth=32, size=16)
    addr = 0
    sum = 0
    ioval = iochannel.read()
    for i in range(8):
        ram.write(0, addr, 128) # from DRAM to BlockRAM
        channel.write(addr)
        sum = channel.read()
        addr += 512
    print('sum=', sum)
    iochannel.write(sum)
    for i in range(1000):
        pass

ctrl_thread()
