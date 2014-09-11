iochannel = CoramIoChannel(idx=0, datawidth=32)
channel = CoramChannel(idx=0, datawidth=32)

#-------------------------------------------------------------------------------
heap_offset = 0 # frontier heap offset
start_addr = 0
goal_addr = 0

#-------------------------------------------------------------------------------
def wait_start():
    global heap_offset
    global start_addr
    global goal_addr
    heap_offset = iochannel.read()
    start_addr = iochannel.read()
    goal_addr = iochannel.read()
    print('heap_offset=%x' % heap_offset)
    print('start_addr=%x' % start_addr)
    print('goal_addr=%x' % goal_addr)

#-------------------------------------------------------------------------------
def find_shortest_path():
    channel.write(heap_offset)
    channel.write(start_addr)
    channel.write(goal_addr)
    cost = channel.read()
    return cost

#-------------------------------------------------------------------------------
def get_cycles():
    cycles = channel.read()
    return cycles

#-------------------------------------------------------------------------------
def return_answer(cost, cycles):
    print('cost=', cost)
    print('cycles=', cycles)
    iochannel.write(cost)
    iochannel.write(cycles)

#-------------------------------------------------------------------------------
def main():
    wait_start()
    cost = find_shortest_path()
    cycles = get_cycles()
    return_answer(cost, cycles)

while True:
    main()
