def ctrl_thread():
    print("thread 1")
    ram = CoramMemory(0, 32, 128)
    channel = CoramChannel(0, 32)
    addr = 2048
    sum = 0
    for i in range(4):
        ram.write(0, addr, 128)
        channel.write(addr)
        sum = channel.read()
        addr += 512
    print('thread1 sum=', sum)

ctrl_thread()
