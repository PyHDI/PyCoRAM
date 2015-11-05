#-------------------------------------------------------------------------------
# run_controlthread.py
#
# Python High-Level Synthesis for PyCoRAM Control Thread
#
# Copyright (C) 2013, Shinya Takamaeda-Yamazaki
# License: Apache 2.0
#-------------------------------------------------------------------------------
from __future__ import absolute_import
from __future__ import print_function
import os
import sys
from optparse import OptionParser

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

import pycoram.utils.version
from pycoram.controlthread.controlthread import ControlThreadGenerator

#-------------------------------------------------------------------------------
def main():
    INFO = "Python-to-Verilog Compiler for Control Thread Generation of PyCoRAM"
    VERSION = pycoram.utils.version.VERSION
    USAGE = "Usage: python run_controlthread.py filelist"

    def showVersion():
        print(INFO)
        print(VERSION)
        print(USAGE)
        sys.exit()
    
    optparser = OptionParser()
    optparser.add_option("-v","--version",action="store_true",dest="showversion",
                         default=False,help="Show the version")
    optparser.add_option("--dump",action="store_true",dest="dump",
                         default=False,help="Dump the internal information")

    (options, args) = optparser.parse_args()

    filelist = args
    if options.showversion:
        showVersion()

    for f in filelist:
        if not os.path.exists(f): raise IOError("file not found: " + f)

    if len(filelist) == 0:
        showVersion()

    for filename in filelist:
        threadgen = ControlThreadGenerator()
        (thread_name, ext) = os.path.splitext(os.path.basename(filename))
        output = thread_name + '.v'
        code = threadgen.compile(thread_name, filename=filename, dump=options.dump)
        f = open(output, 'w')
        f.write(code)
        f.close()

if __name__ == '__main__':
    main()
