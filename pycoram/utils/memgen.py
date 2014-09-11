STEP = 128 * 1024
fout = open('mem.hex', 'w')
for i in range(STEP):
    s = '%02x\n' % (i & 0xff)
    fout.write(s)
    s = '%02x\n' % ((i >> 8) & 0xff)
    fout.write(s)
    s = '%02x\n' % ((i >> 16) & 0xff)
    fout.write(s)
    s = '%02x\n' % ((i >> 24) & 0xff)
    fout.write(s)
