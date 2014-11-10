def ctrl_thread():
    ram = CoramMemory(0, 32, 1024)
    channel = CoramChannel(0, 32)

    while True:
        addr = 0
        sum = 0
        channel.read()

        # init
        for i in range(8):
            ram.write(0, addr, 128) # from DRAM to BlockRAM
            channel.write(i)
            channel.read()
            ram.read(0, addr, 128) # from BlockRAM to DRAM
            addr += 512

        # exec
        addr = 0
        for i in range(8):
            ram.write(0, addr, 128) # from DRAM to BlockRAM
            channel.write(i)
            channel.read()
            addr += 512
        
        sum = channel.read()
        print('sum=', sum)

ctrl_thread()
