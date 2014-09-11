NUM_LINES = 512
NUM_WAYS = 1
LINE_SIZE = 16
DATA_WIDTH = 32

CMD_MISS_CLEAN = 1
CMD_MISS_DIRTY = 2
CMD_FLUSH = 3

mem = CoramMemory(idx=0, datawidth=DATA_WIDTH, size=NUM_LINES*LINE_SIZE/(DATA_WIDTH/8), length=NUM_WAYS, scattergather=False)
channel = CoramChannel(idx=0, datawidth=32, size=16)

def miss_clean():
    way = channel.read()
    index = channel.read()
    next_tag = channel.read()
    addr = index * LINE_SIZE / (DATA_WIDTH/8) + way * NUM_LINES * LINE_SIZE / (DATA_WIDTH/8)
    next_memaddr = next_tag * NUM_LINES * LINE_SIZE + index * LINE_SIZE
    mem.write(addr, next_memaddr, LINE_SIZE/(DATA_WIDTH/8) )
    channel.write(0)

def miss_dirty():
    way = channel.read()
    index = channel.read()
    tag = channel.read()
    next_tag = channel.read()
    addr = index * LINE_SIZE / (DATA_WIDTH/8) + way * NUM_LINES * LINE_SIZE / (DATA_WIDTH/8)
    memaddr = tag * NUM_LINES * LINE_SIZE + index * LINE_SIZE
    mem.read(addr, memaddr, LINE_SIZE/(DATA_WIDTH/8) )
    next_memaddr = next_tag * NUM_LINES * LINE_SIZE + index * LINE_SIZE
    mem.write(addr, next_memaddr, LINE_SIZE/(DATA_WIDTH/8) )
    channel.write(0)

def flush():
    way = channel.read()
    index = channel.read()
    tag = channel.read()
    addr = index * LINE_SIZE / (DATA_WIDTH/8) + way * NUM_LINES * LINE_SIZE / (DATA_WIDTH/8)
    memaddr = tag * NUM_LINES * LINE_SIZE + index * LINE_SIZE
    mem.read(addr, memaddr, LINE_SIZE/(DATA_WIDTH/8) )
    channel.write(0)

def cache_step():
    cmd = channel.read()
    if cmd == CMD_MISS_CLEAN:
        print('miss clean')
        miss_clean()
    if cmd == CMD_MISS_DIRTY:
        print('miss dirty')
        miss_dirty()
    if cmd == CMD_FLUSH:
        print('flush')
        flush()

def cache_main():
    while True:
        cache_step()

cache_main()
