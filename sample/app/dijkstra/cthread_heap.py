OCM_SIZE = 2 ** 8
READ_MODE = 0
WRITE_MODE = 1
COMM_SIZE = 2 ** 4
STREAM_SIZE= 2 ** 10
DATA_BITWIDTH = 64
WORD_SIZE = DATA_BITWIDTH / 8

instream = CoramInStream(0, datawidth=DATA_BITWIDTH, size=STREAM_SIZE)
outstream = CoramOutStream(0, datawidth=DATA_BITWIDTH, size=STREAM_SIZE)
channel = CoramChannel(idx=0, datawidth=32, size=COMM_SIZE)
register = CoramRegister(idx=0, datawidth=32)

DOWN_LEFT = 0
DOWN_PARENT = 1
DOWN_RIGHT = 2
UP_PARENT = 1
UP_CHILD = 0

offset = 0
num_entries = 0

def downheap():
    if num_entries == 0:
        return
    if num_entries + 1 >= OCM_SIZE:
        instream.write_nonblocking(offset + num_entries * WORD_SIZE + WORD_SIZE, 1)
    index = 1
    while True:
        #if index * 2 > num_entries:
        if index * 2 > num_entries:
            #outstream.read_nonblocking(index * WORD_SIZE + offset, 1)
            if index >= OCM_SIZE:
                outstream.read_nonblocking(index * WORD_SIZE + offset, 1)
            break
        if (index * 2) >= OCM_SIZE:
            instream.write_nonblocking(index * WORD_SIZE * 2 + offset, 2)
        elif (index * 2) + 1 >= OCM_SIZE:
            instream.write_nonblocking(index * WORD_SIZE * 2 + offset + WORD_SIZE, 1)
        select = channel.read()
        #outstream.read_nonblocking(index * WORD_SIZE + offset, 1)
        if index >= OCM_SIZE:
            outstream.read_nonblocking(index * WORD_SIZE + offset, 1)
        if select == DOWN_LEFT:
            index = index * 2
        elif select == DOWN_RIGHT:
            index = index * 2 + 1
        else:
            break

def upheap():
    index = num_entries
    while index > 1:
        if (index / 2) >= OCM_SIZE:
            instream.write_nonblocking((index / 2) * WORD_SIZE + offset, 1)
        select = channel.read()
        #outstream.read_nonblocking(index * WORD_SIZE + offset, 1)
        if index >= OCM_SIZE:
            outstream.read_nonblocking(index * WORD_SIZE + offset, 1)
        index = index / 2
        if select == UP_PARENT: break
    #outstream.read_nonblocking(index * WORD_SIZE + offset, 1)
    if index >= OCM_SIZE:
        outstream.read_nonblocking(index * WORD_SIZE + offset, 1)
            
def heap():
    global offset
    global num_entries
    mode = channel.read()
    offset = register.read()
    if mode == 1:
        num_entries -= 1
        downheap()
    elif mode == 2:
        num_entries += 1
        upheap()
    elif mode == 0xff: # reset
        num_entries = 0

while True:
    heap()
