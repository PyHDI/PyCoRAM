#!/usr/bin/python
import serial
import sys
import os
from struct import *

#ser = serial.Serial('/dev/ttyUSB0', 921600)
ser = serial.Serial('/dev/ttyACM0', 921600)
step_val = 0
print('step value = %d' % step_val)
step = pack('I', step_val)
ser.write(step)

rslt = ser.read(4)
rslt_value = unpack('I', rslt)
#print('rslt value = %d (len=%d)' % (rslt_value, len(rslt)))
print('rslt value = %d' % rslt_value)
print('len=%d' % len(rslt))
