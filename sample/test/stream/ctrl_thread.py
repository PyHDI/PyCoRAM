def write_and_wait(stream, channel, eaddr, size):
    channel.write(eaddr)    
    stream.write(eaddr, size)
    sum = channel.read()
    return sum

def ctrl_thread():
    instream = CoramInStream(0, 32, 64)
    outstream = CoramOutStream(0, 32, 64)
    channel = CoramChannel(0, 32)
    addr = 0
    sum = 0
    for i in range(8):
        sum = write_and_wait(instream, channel, addr, 128)
        outstream.read(addr + (1024 * 16), 128)
        addr += 512
    print('sum=', sum)

ctrl_thread()

