#-------------------------------------------------------------------------------
# bin2hex.py
# 
# binary to Verilog HDL memory image in HEX
#
# Copyright (C) 2013, Shinya Takamaeda-Yamazaki
# License: Apache 2.0
#-------------------------------------------------------------------------------

import os
import sys

import struct

def bin2hex(ifilename, ofilename, size):
    ifile = open(ifilename, 'rb')
    ofile = open(ofilename, 'w')
    line = []
    index = 0

    buf = ifile.read(1)
    while buf:
        line.append("%02x" % struct.unpack("B", buf)[0])
        if (index % size) == (size -1):
            line.append('\n')
            ofile.write(''.join(reversed(line)))
            line = []
        buf = ifile.read(1)
        index += 1

def bin2hex_bank(ifilename, ofilename, size):
    ifile = open(ifilename, 'rb')
    ofilelist = []
    for i in range(size):
        ofilelist.append( open( ("%03d" % i) + ofilename, 'w') )

    index = 0
    buf = ifile.read(1)
    while buf:
        ofilelist[ index % size ].write( ("%02x\n" % struct.unpack("B", buf)[0]) )
        buf = ifile.read(1)
        index += 1

if __name__ == '__main__':
    from optparse import OptionParser
    INFO = "Binary to Verilog HDL memory image in HEX"
    VERSION = "ver.1.0.0"
    USAGE = "Usage: python bin2hex.py filename"

    def showVersion():
        print(INFO)
        print(VERSION)
        print(USAGE)
        sys.exit()

    optparser = OptionParser()
    optparser.add_option("-v","--version",action="store_true",dest="showversion",
                         default=False,help="Show the version")
    optparser.add_option("--size",dest="size",type='int',
                         default=64,help="Chunk size, default=64")
    optparser.add_option("-o","--output",dest="outputfile",
                         default="out.hex",help="Output file name, default=out.hex")
    optparser.add_option("--bank",action="store_true",dest="bank",
                         default=False,help="Banked hex file mode")
    (options, args) = optparser.parse_args()
    
    filelist = args
    if options.showversion:
        showVersion()

    for f in filelist:
        if not os.path.exists(f): raise IOError("file not found: %s" % f)

    if len(filelist) == 0:
        showVersion()

    if options.bank:
        bin2hex_bank(args[0], options.outputfile, options.size)
    else:
        bin2hex(args[0], options.outputfile, options.size)
