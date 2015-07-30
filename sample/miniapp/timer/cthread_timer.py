ioregister = CoramIoRegister(idx=0, datawidth=32, size=32)
register = CoramRegister(idx=0, datawidth=32)
while True:
    val = register.read()
    ioregister.write(0, val)
