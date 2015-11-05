#-------------------------------------------------------------------------------
# cthread_send
#-------------------------------------------------------------------------------
iochannel = CoramIoChannel(idx=0, datawidth=32)
send_channel = CoramChannel(idx=0, datawidth=32)

def send_step():
    v = iochannel.read()
    send_channel.write(v)
    send_channel.read()

def send_main():
    while True:
        send_step()

#-------------------------------------------------------------------------------
send_main()

