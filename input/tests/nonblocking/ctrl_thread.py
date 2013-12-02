def ctrl_thread():
    ram = CoramMemory(idx=0, datawidth=32, size=1024, length=1, scattergather=False)
    channel = CoramChannel(idx=0, datawidth=32, size=16)
    addr = 0
    sum = 0
    for i in range(8):
        ram.write_nonblocking(0, addr, 32)
        ram.write_nonblocking(32*1, addr+32*4*1, 32)
        ram.write_nonblocking(32*2, addr+32*4*2, 32)
        ram.write_nonblocking(32*3, addr+32*4*3, 32)
        ram.wait()
        channel.write(addr)
        sum = channel.read()
        addr += 512
    print('sum=', sum)

ctrl_thread()
