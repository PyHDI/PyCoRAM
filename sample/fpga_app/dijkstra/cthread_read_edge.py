COMM_SIZE = 2 ** 4
STREAM_SIZE= 2 ** 10
DATA_BITWIDTH = 32

instream = CoramInStream(idx=0, datawidth=DATA_BITWIDTH*2, size=STREAM_SIZE)
channel = CoramChannel(idx=0, datawidth=DATA_BITWIDTH, size=COMM_SIZE)

def read_edge():
    addr = channel.read()
    instream.write_nonblocking(addr, 2) # prefetch the first entry
    size = channel.read()
    instream.write_nonblocking(addr+DATA_BITWIDTH*4/8, size-1)

while True:
    read_edge()
