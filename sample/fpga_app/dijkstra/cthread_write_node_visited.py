COMM_SIZE = 2 ** 4
STREAM_SIZE= 2 ** 10
DATA_BITWIDTH = 32

outstream = CoramOutStream(idx=0, datawidth=DATA_BITWIDTH, size=STREAM_SIZE)
channel = CoramChannel(idx=0, datawidth=DATA_BITWIDTH, size=COMM_SIZE)

def write_node_visited():
    addr = channel.read()
    outstream.read_nonblocking(addr, 1)

while True:
    write_node_visited()
