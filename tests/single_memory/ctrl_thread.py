def ctrl_thread():
    ram = CoramMemory(idx=0, datawidth=32, size=1024, length=1, scattergather=False)
    channel = CoramChannel(idx=0, datawidth=32, size=16)
    addr = 0
    sum = 0
    for i in range(8):
        ram.write(0, addr, 128) # DRAM -> BRAM
        channel.write(addr)
        sum = channel.read()
        ram.read(0, addr + (1024 * 16), 128) # BRAM -> DRAM
        addr += 512
    print('sum=', sum)

ctrl_thread()
