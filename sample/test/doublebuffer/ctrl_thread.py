DATA_SIZE = 1024 * 256 # entry
RAM_SIZE = 1024 * 16 # entry

REPEAT = DATA_SIZE / RAM_SIZE

read_ram0 = CoramMemory(0, 32, RAM_SIZE)
read_ram1 = CoramMemory(1, 32, RAM_SIZE)
write_ram0 = CoramMemory(2, 32, RAM_SIZE)
write_ram1 = CoramMemory(3, 32, RAM_SIZE)
channel = CoramChannel(0, 32)

def ctrl_thread():
    read_addr = 0
    write_addr = DATA_SIZE * 4
    sum = 0

    read_ram0.write_nonblocking(0, read_addr, RAM_SIZE) # from DRAM to BlockRAM
    read_ram0.wait()
    channel.write(read_addr) # execution notify

    read_ram1.write_nonblocking(0, read_addr+RAM_SIZE*4, RAM_SIZE) # from DRAM to BlockRAM
    read_ram1.wait()
    channel.write(read_addr+RAM_SIZE*4) # execution notify

    for i in range((REPEAT-2)/2):
        read_addr += RAM_SIZE*4*2
        
        sum = channel.read()
        write_ram0.read_nonblocking(0, write_addr, RAM_SIZE) # from BlockRAM to DRAM
        read_ram0.write_nonblocking(0, read_addr, RAM_SIZE) # from DRAM to BlockRAM
        write_ram0.wait()
        read_ram0.wait()
        channel.write(read_addr) # execution notify

        sum = channel.read()
        write_ram1.read_nonblocking(0, write_addr+RAM_SIZE*4, RAM_SIZE) # from BlockRAM to DRAM
        read_ram1.write_nonblocking(0, read_addr+RAM_SIZE*4, RAM_SIZE) # from DRAM to BlockRAM
        write_ram1.wait()
        read_ram1.wait()
        channel.write(read_addr+RAM_SIZE*4) # execution notify

        write_addr += RAM_SIZE*4*2

    sum = channel.read()
    write_ram0.read_nonblocking(0, write_addr, RAM_SIZE) # from BlockRAM to DRAM
    write_ram0.wait()

    sum = channel.read()
    write_ram1.read_nonblocking(0, write_addr+RAM_SIZE*4, RAM_SIZE) # from BlockRAM to DRAM
    write_ram1.wait()

    print('sum=', sum)

ctrl_thread()
