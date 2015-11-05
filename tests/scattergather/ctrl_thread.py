WIDTH = 32
SIZE = 128
NUM_BANKS = 8

def ctrl_thread():
    ram = CoramMemory(0, WIDTH, SIZE, NUM_BANKS, True)
    channel = CoramChannel(0, 32)
    addr = 0
    sum = 0
    for i in range(4):
        ram.write(0, addr, SIZE)
        channel.write(addr)
        sum = channel.read()
        addr += (SIZE * NUM_BANKS * (WIDTH / 8))
    print('sum=', sum)

ctrl_thread()
