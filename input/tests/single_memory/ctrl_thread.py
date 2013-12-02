def ctrl_thread():
    ram = CoramMemory(idx=0, datawidth=32, size=1024, length=1, scattergather=False)
    channel = CoramChannel(idx=0, datawidth=32, size=16)
    addr = 0
    sum = 0
    for i in range(8):
        ram.write(0, addr, 128) # from DRAM to BlockRAM
        channel.write(addr)
        sum = channel.read()
        addr += 512
    print('sum=', sum)

ctrl_thread()
