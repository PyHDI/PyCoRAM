#-------------------------------------------------------------------------------
# coram_module.py
#
# PyCoRAM memory and channel components
#
# Copyright (C) 2013, Shinya Takamaeda-Yamazaki
# License: Apache 2.0
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Base Class
#-------------------------------------------------------------------------------
class CoramBase(object):
    def __init__(self, idx, datawidth, size, length, scattergather,
                 addrwidth=None, addroffset=None, loglength=None,
                 ext_datawidth=None, numranks=None, lognumranks=None,
                 numpages=None, lognumpages=None):
        self.idx = idx
        self.datawidth = datawidth # bit
        self.size = size # num entry (word)
        self.length = length
        self.scattergather = scattergather
        self.name = ''.join( (self.__class__.__name__.lower(), '_', str(self.idx)) )
        self.addrwidth = addrwidth
        self.addroffset = addroffset
        self.loglength = loglength
        self.ext_datawidth = ext_datawidth
        self.numranks = numranks
        self.lognumranks = lognumranks
        self.numpages = numpages
        self.lognumpages = lognumpages
    def __repr__(self):
        ret = []
        ret.append(self.__class__.__name__)
        ret.append('(ID:')
        ret.append(str(self.idx))
        if self.length is not None:
            ret.append(' Length:')
            ret.append(str(self.length))
        ret.append(' AddrWidth:')
        ret.append(str(self.addrwidth))
        ret.append(' DataWidth:')
        ret.append(str(self.datawidth))
        ret.append(')')
        return ''.join(ret)

#-------------------------------------------------------------------------------
# CoRAM Object Classes
#-------------------------------------------------------------------------------
class CoramMemory(CoramBase):
    def __init__(self, idx, datawidth=None, size=None, length=None, scattergather=None,
                 addrwidth=None, addroffset=None, loglength=None,
                 ext_datawidth=None, numranks=None, lognumranks=None,
                 numpages=None, lognumpages=None):
        CoramBase.__init__(self, idx=idx, datawidth=datawidth, size=size, length=length, scattergather=scattergather,
                           addrwidth=addrwidth, addroffset=addroffset, loglength=loglength,
                           ext_datawidth=ext_datawidth, numranks=numranks, lognumranks=lognumranks,
                           numpages=numpages, lognumpages=lognumpages)
    def read(self, ram_addr, mem_addr, size):
        pass
    def write(self, ram_addr, mem_addr, size):
        pass
    def read_nonblocking(self, ram_addr, mem_addr, size):
        pass
    def write_nonblocking(self, ram_addr, mem_addr, size):
        pass
    def wait(self):
        pass
    def test(self):
        return True

class CoramStream(CoramBase):
    def __init__(self, idx, datawidth=None, size=None, length=None, scattergather=None,
                 addrwidth=None, addroffset=None, loglength=None,
                 ext_datawidth=None, numranks=None, lognumranks=None,
                 numpages=None, lognumpages=None):
        CoramBase.__init__(self, idx=idx, datawidth=datawidth, size=size, length=length, scattergather=scattergather,
                           addrwidth=addrwidth, addroffset=addroffset, loglength=loglength,
                           ext_datawidth=ext_datawidth, numranks=numranks, lognumranks=lognumranks,
                           numpages=numpages, lognumpages=lognumpages)
    def read(self, mem_addr, size):
        pass
    def write(self, mem_addr, size):
        pass
    def read_nonblocking(self, mem_addr, size):
        pass
    def write_nonblocking(self, mem_addr, size):
        pass
    def wait(self):
        pass
    def test(self):
        return True

class CoramInStream(CoramStream): pass
class CoramOutStream(CoramStream): pass

class CoramChannel(CoramBase):
    def __init__(self, idx, datawidth=None, size=None, length=None, scattergather=None,
                 addrwidth=None, addroffset=None, loglength=None,
                 ext_datawidth=None, numranks=None, lognumranks=None,
                 numpages=None, lognumpages=None):
        CoramBase.__init__(self, idx=idx, datawidth=datawidth, size=size, length=length, scattergather=scattergather,
                           addrwidth=addrwidth, addroffset=addroffset, loglength=loglength,
                           ext_datawidth=ext_datawidth, numranks=numranks, lognumranks=lognumranks,
                           numpages=numpages, lognumpages=lognumpages)
    def read(self):
        return 0
    def write(self, value):
        pass

class CoramRegister(CoramBase):
    def __init__(self, idx, datawidth=None, size=None, length=None, scattergather=None,
                 addrwidth=None, addroffset=None, loglength=None,
                 ext_datawidth=None, numranks=None, lognumranks=None,
                 numpages=None, lognumpages=None):
        CoramBase.__init__(self, idx=idx, datawidth=datawidth, size=size, length=length, scattergather=scattergather,
                           addrwidth=addrwidth, addroffset=addroffset, loglength=loglength,
                           ext_datawidth=ext_datawidth, numranks=numranks, lognumranks=lognumranks,
                           numpages=numpages, lognumpages=lognumpages)
    def read(self):
        return 0
    def write(self, value):
        pass

class CoramIoChannel(CoramBase):
    def __init__(self, idx, datawidth=None, size=None, length=None, scattergather=None,
                 addrwidth=None, addroffset=None, loglength=None,
                 ext_datawidth=None, numranks=None, lognumranks=None,
                 numpages=None, lognumpages=None):
        CoramBase.__init__(self, idx=idx, datawidth=datawidth, size=size, length=length, scattergather=scattergather,
                           addrwidth=addrwidth, addroffset=addroffset, loglength=loglength,
                           ext_datawidth=ext_datawidth, numranks=numranks, lognumranks=lognumranks,
                           numpages=numpages, lognumpages=lognumpages)
    def read(self):
        return 0
    def write(self, value):
        pass

class CoramIoRegister(CoramBase):
    def __init__(self, idx, datawidth=None, size=None, length=None, scattergather=None,
                 addrwidth=None, addroffset=None, loglength=None,
                 ext_datawidth=None, numranks=None, lognumranks=None,
                 numpages=None, lognumpages=None):
        CoramBase.__init__(self, idx=idx, datawidth=datawidth, size=size, length=length, scattergather=scattergather,
                           addrwidth=addrwidth, addroffset=addroffset, loglength=loglength,
                           ext_datawidth=ext_datawidth, numranks=numranks, lognumranks=lognumranks,
                           numpages=numpages, lognumpages=lognumpages)
    def read(self):
        return 0
    def write(self, value):
        pass

class CoramSlaveStream(CoramBase):
    def __init__(self, idx, datawidth=None, size=None, length=None, scattergather=None,
                 addrwidth=None, addroffset=None, loglength=None,
                 ext_datawidth=None, numranks=None, lognumranks=None,
                 numpages=None, lognumpages=None):
        CoramBase.__init__(self, idx=idx, datawidth=datawidth, size=size, length=length, scattergather=scattergather,
                           addrwidth=addrwidth, addroffset=addroffset, loglength=loglength,
                           ext_datawidth=ext_datawidth, numranks=numranks, lognumranks=lognumranks,
                           numpages=numpages, lognumpages=lognumpages)
    def read(self):
        return 0
    def write(self, value):
        pass

#-------------------------------------------------------------------------------
# Management Class
#-------------------------------------------------------------------------------
class ControlThread(object):
    def __init__(self, name, memories, instreams, outstreams,
                 channels, registers, iochannels, ioregisters):
        self.name = name
        self.memories = memories
        self.instreams = instreams
        self.outstreams = outstreams
        self.channels = channels
        self.registers = registers
        self.iochannels = iochannels
        self.ioregisters = ioregisters
