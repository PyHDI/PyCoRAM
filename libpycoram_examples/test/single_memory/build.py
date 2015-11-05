import sys
import os

# Path to pycoram.py in the project root directory
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))
from pycoram.pycoram import *

import ctrl_thread

ip = PycoramIp(topmodule='userlogic', if_type='axi',
               #usertest='testbench.v',
               memimg='../../mem-incr.hex')
               
ip.add_include_path("../../../include/")
ip.add_rtl("userlogic.v")
ip.add_controlthread(ctrl_thread.ctrl_thread, threadname='ctrl_thread')

ip.generate()
