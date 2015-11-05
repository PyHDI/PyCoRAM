RAMSIZE=128
iochannel = CoramIoChannel(idx=0, datawidth=32)
ram = CoramMemory(idx=0, datawidth=32, size=RAMSIZE, length=1, scattergather=False)
channel = CoramChannel(idx=0, datawidth=32, size=16)

def main():
    sum = 0
    addr = iochannel.read()
    read_size = iochannel.read()
    size = 0

    while size < read_size:
        req_size = RAMSIZE if size + RAMSIZE <= read_size else read_size - size
        ram.write(0, addr, req_size) # from DRAM to BlockRAM
        channel.write(addr)
        addr += req_size * 4
        size += req_size
        sum = channel.read()

    print('sum=', sum)
    iochannel.write(sum)

while True:
    main()
