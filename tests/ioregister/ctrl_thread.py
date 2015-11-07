def ctrl_thread():
    ioregister = CoramIoRegister(idx=0, datawidth=32, size=32)
    ram = CoramMemory(idx=0, datawidth=32, size=1024, length=1, scattergather=False)
    channel = CoramChannel(idx=0, datawidth=32, size=16)
    addr = 0
    sum = 0

    # initialization of IO register RAM
    ioregister.write(0, 0) # ioregister[0] = 0
    
    ioval = 0
    while ioval == 0:
        ioval = ioregister.read(0)
        print('ioval=',ioval)
        
    for i in range(8):
        ram.write(0, addr, 128) # from DRAM to BlockRAM
        channel.write(addr)
        sum = channel.read()
        addr += 512
    print('sum=', sum)

    ioregister.write(0, 0)
    ioregister.write(1, sum)
    
    for i in range(10000):
        pass

ctrl_thread()
