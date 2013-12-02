f = open('dftdemo.hex', 'r')
lines = f.read().split('\n')
fout = open('mem-dft.hex', 'w')
step = 2
for line in lines:
    for i in range(len(line), 0, -step):
        fout.write(line[i-step:i])
        fout.write('\n')
