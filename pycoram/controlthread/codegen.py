#-------------------------------------------------------------------------------
# codegen.py
# 
# Code Generator
#
# Copyright (C) 2013, Shinya Takamaeda-Yamazaki
# License: Apache 2.0
#-------------------------------------------------------------------------------
import os
import sys
import math
import fractions

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))) )

if sys.version_info[0] >= 3:
    import controlthread.maketree as maketree
else:
    import maketree as maketree

import pyverilog
import pyverilog.vparser
import pyverilog.vparser.ast as vast
import pyverilog.dataflow.optimizer as vopt
import pyverilog.dataflow.dataflow as vdflow
import pyverilog.utils.scope as vscope
from pyverilog.ast_code_generator.codegen import ASTCodeGenerator

#-------------------------------------------------------------------------------
def log2(v):
    return int(math.ceil(math.log(v, 2)))

#-------------------------------------------------------------------------------
class CodeGenerator(object):
    def __init__(self, threadname, coram_memories, coram_instreams, coram_outstreams,
                 coram_channels, coram_registers,
                 coram_iochannels, coram_ioregisters,
                 scope, fsm,
                 signalwidth=64,
                 ext_addrwidth=64, 
                 ext_max_datawidth=512,
                 fsm_name='state'):
        self.threadname = threadname

        self.coram_memories = {}
        self.coram_instreams = {}
        self.coram_outstreams = {}
        self.coram_channels = {}
        self.coram_registers = {}
        self.coram_iochannels = {}
        self.coram_ioregisters = {}
        
        for c in coram_memories.values():
            if c.name in self.coram_memories: continue
            self.coram_memories[c.name] = c
        for c in coram_instreams.values():
            if c.name in self.coram_instreams: continue
            self.coram_instreams[c.name] = c
        for c in coram_outstreams.values():
            if c.name in self.coram_outstreams: continue
            self.coram_outstreams[c.name] = c
        for c in coram_channels.values():
            if c.name in self.coram_channels: continue
            self.coram_channels[c.name] = c
        for c in coram_registers.values():
            if c.name in self.coram_registers: continue
            self.coram_registers[c.name] = c
        for c in coram_iochannels.values():
            if c.name in self.coram_iochannels: continue
            self.coram_iochannels[c.name] = c
        for c in coram_ioregisters.values():
            if c.name in self.coram_ioregisters: continue
            self.coram_ioregisters[c.name] = c

        self.scope = scope
        self.fsm = fsm

        self.signalwidth = signalwidth
        self.ext_addrwidth = ext_addrwidth
        self.ext_max_datawidth = ext_max_datawidth
        if ext_max_datawidth % 8 != 0 or math.log(ext_max_datawidth/8, 2) % 1.0 != 0.0:
            raise ValueError("CoRAM external data width should be greater than 8 and power of 2.")
        self.fsm_name = fsm_name

        self.vopt = vopt.VerilogOptimizer({}, default_width=signalwidth)
        self.binds = {}
        self.const_binds = {}
        self.parameters = set([])

        self.new_fsm_binds = []

        self._prepareConstant()
        self._optimizeCoramArguments()

    #-------------------------------------------------------------------------
    def _prepareConstant(self):
        self.binds = self.scope.getBinds()
        for name, bindlist in sorted(self.binds.items(), key=lambda x:x[1][0][0]): # younger state order
            if len(bindlist) > 1: continue
            for state, value, cond in bindlist:
                opt_dfvalue = self.vopt.optimize(maketree.getDFTree(value))
                if isinstance(opt_dfvalue, vdflow.DFEvalValue):
                    varname = vscope.ScopeChain( (vscope.ScopeLabel(name),) )
                    self.vopt.setConstant(varname, opt_dfvalue)
                    termtypes = set(['Parameter'])
                    term = vdflow.Term(varname, termtypes, vdflow.DFEvalValue(31), vdflow.DFEvalValue(0))
                    self.vopt.setTerm(varname, term)
                    self.const_binds[name] = maketree.makeASTTree(opt_dfvalue)

    #-------------------------------------------------------------------------
    def _optimize(self, node):
        opt_dfnode = self.vopt.optimize(maketree.getDFTree(node))
        opt_node = maketree.makeASTTree(opt_dfnode)
        return opt_node

    #-------------------------------------------------------------------------
    def _optimizeCoramArguments(self):
        for memname, mem in self.coram_memories.items():
            self.__set_coram_parameters(mem)
        for memname, mem in self.coram_instreams.items():
            self.__set_coram_parameters(mem)
        for memname, mem in self.coram_outstreams.items():
            self.__set_coram_parameters(mem)
        for memname, mem in self.coram_channels.items():
            self.__set_coram_parameters(mem)
        for memname, mem in self.coram_registers.items():
            self.__set_coram_parameters(mem)
        for memname, mem in self.coram_iochannels.items():
            self.__set_coram_parameters(mem)
        for memname, mem in self.coram_ioregisters.items():
            self.__set_coram_parameters(mem)

    #-------------------------------------------------------------------------
    def __set_coram_parameters(self, obj):
        datawidth = self._optimize(obj.datawidth)
        if not isinstance(datawidth, vast.IntConst):
            raise TypeError("CoRAM argument should be a constant.")
        obj.datawidth = int(datawidth.value)
        if obj.datawidth % 8 != 0 or math.log(obj.datawidth/8, 2) % 1.0 != 0.0:
            raise ValueError("CoRAM data width should be greater than 8 and power of 2.")

        size = self._optimize(obj.size)
        if not isinstance(size, vast.IntConst):
            raise TypeError("CoRAM argument should be a constant.")
        obj.size = int(size.value)

        length = self._optimize(obj.length) if obj.length is not None else None
        if length is not None and not isinstance(length, vast.IntConst):
            raise TypeError("CoRAM argument should be a constant.")
        obj.length = int(length.value) if length is not None else None
        obj.loglength = log2(obj.length) if length is not None else 0

        scattergather = self._optimize(obj.scattergather) if obj.scattergather is not None else None
        if scattergather is not None and not isinstance(scattergather, vast.IntConst):
            raise TypeError("CoRAM argument should be a constant.")
        obj.scattergather = (int(scattergather.value) > 0) if scattergather is not None else None

        obj.addrwidth = log2(obj.size)
        obj.addroffset = log2(int(obj.datawidth / 8))

        req_ext_datawidth = (obj.datawidth if length is None else 
                             obj.datawidth if obj.scattergather is None else
                             obj.datawidth if not obj.scattergather else
                             obj.datawidth * obj.length)
        ext_datawidth = fractions.gcd(req_ext_datawidth, self.ext_max_datawidth)
        obj.ext_datawidth = ext_datawidth

        obj.numranks = (None if obj.length is None else
                        int(math.ceil(req_ext_datawidth / ext_datawidth)))
        obj.lognumranks = log2(obj.numranks) if obj.numranks is not None else 0

        obj.numpages = (None if obj.length is None else
                        1 if obj.scattergather else obj.length)
        obj.lognumpages = log2(obj.numpages) if obj.numpages is not None else 0

    #----------------------------------------------------------------------------
    def _insertCommand(self):
        # initial value (finish)
        self.fsm.setBind(vast.Identifier('finish'), vast.IntConst('0'), 0)

        already_defined = set([])

        # initial value (memory)
        for memname, mem in self.coram_memories.items():
            prefix = []
            prefix.append(mem.name)
            prefix.append('_')
            prefix_str = ''.join(prefix)
            if prefix_str in already_defined: continue
            already_defined.add(prefix_str)
            self.fsm.setBind(vast.Identifier(''.join(prefix+['read_enable'])), vast.IntConst('0'), 0)
            self.fsm.setBind(vast.Identifier(''.join(prefix+['write_enable'])), vast.IntConst('0'), 0)

        # initial value (instream)
        for memname, mem in self.coram_instreams.items():
            prefix = []
            prefix.append(mem.name)
            prefix.append('_')
            prefix_str = ''.join(prefix)
            if prefix_str in already_defined: continue
            already_defined.add(prefix_str)
            self.fsm.setBind(vast.Identifier(''.join(prefix+['write_enable'])), vast.IntConst('0'), 0)

        # initial value (outstream)
        for memname, mem in self.coram_outstreams.items():
            prefix = []
            prefix.append(mem.name)
            prefix.append('_')
            prefix_str = ''.join(prefix)
            if prefix_str in already_defined: continue
            already_defined.add(prefix_str)
            self.fsm.setBind(vast.Identifier(''.join(prefix+['read_enable'])), vast.IntConst('0'), 0)

        # initial value (channel)
        for memname, mem in self.coram_channels.items():
            prefix = []
            prefix.append(mem.name)
            prefix.append('_')
            prefix_str = ''.join(prefix)
            if prefix_str in already_defined: continue
            already_defined.add(prefix_str)
            self.fsm.setBind(vast.Identifier(''.join(prefix+['enq'])), vast.IntConst('0'), 0)
            self.fsm.setBind(vast.Identifier(''.join(prefix+['deq'])), vast.IntConst('0'), 0)

        # initial value (register)
        for memname, mem in self.coram_registers.items():
            prefix = []
            prefix.append(mem.name)
            prefix.append('_')
            prefix_str = ''.join(prefix)
            if prefix_str in already_defined: continue
            already_defined.add(prefix_str)
            self.fsm.setBind(vast.Identifier(''.join(prefix+['we'])), vast.IntConst('0'), 0)

        # initial value (I/O channel)
        for memname, mem in self.coram_iochannels.items():
            prefix = []
            prefix.append(mem.name)
            prefix.append('_')
            prefix_str = ''.join(prefix)
            if prefix_str in already_defined: continue
            already_defined.add(prefix_str)
            self.fsm.setBind(vast.Identifier(''.join(prefix+['enq'])), vast.IntConst('0'), 0)
            self.fsm.setBind(vast.Identifier(''.join(prefix+['deq'])), vast.IntConst('0'), 0)

        # initial value (I/O register)
        for memname, mem in self.coram_ioregisters.items():
            prefix = []
            prefix.append(mem.name)
            prefix.append('_')
            prefix_str = ''.join(prefix)
            if prefix_str in already_defined: continue
            already_defined.add(prefix_str)
            self.fsm.setBind(vast.Identifier(''.join(prefix+['we'])), vast.IntConst('0'), 0)

        self._clear_fsm_binds()
        for state, bindlist in self.fsm.bind.items():
            for bind in bindlist:
                self._insertCommand_bind(bind, state)
        self._apply_fsm_binds()

    def _clear_fsm_binds(self):
        self.new_fsm_binds = []

    def _append_fsm_bind(self, dst, value, st=None, cond=None):
        self.new_fsm_binds.append( (dst, value, st, cond) )

    def _apply_fsm_binds(self):
        for (dst, value, st, cond) in self.new_fsm_binds:
            self.fsm.setBind(dst, value, st, cond)

    def _insertCommand_bind(self, bind, state):
        if bind.dst is not None or not isinstance(bind.value, vast.SystemCall):
            return
        #--------------------------------------------------------------------------
        if bind.value.syscall == 'coram_memory_read':
            ramname = bind.value.args[0].name
            scattergather = self.coram_memories[ramname].scattergather
            __ramname = ramname + '(SG)' if scattergather else ramname
            ext_addr = bind.value.args[2]
            core_addr = bind.value.args[1]
            size = bind.value.args[3]
            maximum_size = (self.coram_memories[ramname].size if self.coram_memories[ramname].length is None 
                            else self.coram_memories[ramname].size * self.coram_memories[ramname].length)
            phy_core_addr = vast.Times(core_addr, vast.IntConst(self.coram_memories[ramname].length)) if scattergather else core_addr
            sg_size = vast.Divide(size, vast.IntConst(self.coram_memories[ramname].length)) if scattergather else size
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s read issue"
                                                                     " size:%%d"
                                                                     " B[%%d]->D[%%d]") % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, core_addr, ext_addr,
                                               )),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')))
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s read done"
                                                                     " size:%%d"
                                                                     " B[%%d]->D[%%d]") % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, core_addr, ext_addr,
                                               )),
                                  state+2,
                                  vast.Eq(vast.Identifier(ramname+'_busy'), vast.IntConst('0')))
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s too large request"
                                                                     " size:%%d > capacity:%%d") % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, vast.IntConst(str(maximum_size)),
                                               )),
                                  state,
                                  vast.Land(vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')),
                                            vast.GreaterThan(size, vast.IntConst(str(maximum_size)))))
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s illegal local address"
                                                                     " capacity:%%d B[%%d:%%d]") % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   vast.IntConst(str(maximum_size)), core_addr,
                                                   vast.Minus(vast.Plus(core_addr, sg_size), vast.IntConst('1')),
                                               )),
                                  state,
                                  vast.Land(vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')),
                                            vast.GreaterThan(vast.Plus(phy_core_addr, size),
                                                             vast.IntConst(str(maximum_size)))))
                                

        elif bind.value.syscall == 'coram_memory_write':
            ramname = bind.value.args[0].name
            scattergather = self.coram_memories[ramname].scattergather
            __ramname = ramname + '(SG)' if scattergather else ramname
            ext_addr = bind.value.args[2]
            core_addr = bind.value.args[1]
            size = bind.value.args[3]
            maximum_size = (self.coram_memories[ramname].size if self.coram_memories[ramname].length is None 
                            else self.coram_memories[ramname].size * self.coram_memories[ramname].length)
            phy_core_addr = vast.Times(core_addr, vast.IntConst(self.coram_memories[ramname].length)) if scattergather else core_addr
            sg_size = vast.Divide(size, vast.IntConst(self.coram_memories[ramname].length)) if scattergather else size
            self._append_fsm_bind(None, 
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s write issue"
                                                                     " size:%%d"
                                                                     " B[%%d]<-D[%%d]") % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, core_addr, ext_addr,
                                               )),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')))
            self._append_fsm_bind(None, 
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s write done"
                                                                     " size:%%d"
                                                                     " B[%%d]<-D[%%d]") % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, core_addr, ext_addr,
                                               )),
                                  state+2,
                                  vast.Eq(vast.Identifier(ramname+'_busy'), vast.IntConst('0')))
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s too large request"
                                                                     " size:%%d > capacity:%%d") % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, vast.IntConst(str(maximum_size)),
                                               )),
                                  state,
                                  vast.Land(vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')),
                                            vast.GreaterThan(size, vast.IntConst(str(maximum_size)))))
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s illegal local address"
                                                                     " capacity:%%d B[%%d:%%d]") % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   vast.IntConst(str(maximum_size)), core_addr,
                                                   vast.Minus(vast.Plus(core_addr, sg_size), vast.IntConst('1')),
                                               )),
                                  state,
                                  vast.Land(vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')),
                                            vast.GreaterThan(vast.Plus(phy_core_addr, size),
                                                             vast.IntConst(str(maximum_size)))))

        elif bind.value.syscall == 'coram_memory_read_nonblocking':
            ramname = bind.value.args[0].name
            scattergather = self.coram_memories[ramname].scattergather
            __ramname = ramname + '(SG)' if scattergather else ramname
            ext_addr = bind.value.args[2]
            core_addr = bind.value.args[1]
            size = bind.value.args[3]
            maximum_size = (self.coram_memories[ramname].size if self.coram_memories[ramname].length is None 
                            else self.coram_memories[ramname].size * self.coram_memories[ramname].length)
            phy_core_addr = vast.Times(core_addr, vast.IntConst(self.coram_memories[ramname].length)) if scattergather else core_addr
            sg_size = vast.Divide(size, vast.IntConst(self.coram_memories[ramname].length)) if scattergather else size
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s read nonblk"
                                                                     " size:%%d"
                                                                     " B[%%d]->D[%%d]") % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, core_addr, ext_addr,
                                               )),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')))
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s too large request"
                                                                     " size:%%d > capacity:%%d") % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, vast.IntConst(str(maximum_size)),
                                               )),
                                  state,
                                  vast.Land(vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')),
                                            vast.GreaterThan(size, vast.IntConst(str(maximum_size)))))
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s illegal local address"
                                                                     " capacity:%%d B[%%d:%%d]") % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   vast.IntConst(str(maximum_size)), core_addr,
                                                   vast.Minus(vast.Plus(core_addr, sg_size), vast.IntConst('1')),
                                               )),
                                  state,
                                  vast.Land(vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')),
                                            vast.GreaterThan(vast.Plus(phy_core_addr, size),
                                                             vast.IntConst(str(maximum_size)))))

        elif bind.value.syscall == 'coram_memory_write_nonblocking':
            ramname = bind.value.args[0].name
            scattergather = self.coram_memories[ramname].scattergather
            __ramname = ramname + '(SG)' if scattergather else ramname
            ext_addr = bind.value.args[2]
            core_addr = bind.value.args[1]
            size = bind.value.args[3]
            maximum_size = (self.coram_memories[ramname].size if self.coram_memories[ramname].length is None 
                            else self.coram_memories[ramname].size * self.coram_memories[ramname].length)
            phy_core_addr = vast.Times(core_addr, vast.IntConst(self.coram_memories[ramname].length)) if scattergather else core_addr
            sg_size = vast.Divide(size, vast.IntConst(self.coram_memories[ramname].length)) if scattergather else size
            self._append_fsm_bind(None, 
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s write nonblk"
                                                                     " size:%%d"
                                                                     " B[%%d]<-D[%%d]") % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, core_addr, ext_addr,
                                               )),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')))
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s too large request"
                                                                     " size:%%d > capacity:%%d") % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, vast.IntConst(str(maximum_size))
                                               )),
                                  state,
                                  vast.Land(vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')),
                                            vast.GreaterThan(size, vast.IntConst(str(maximum_size)))))
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s illegal local address"
                                                                     " capacity:%%d B[%%d:%%d]") % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   vast.IntConst(str(maximum_size)), core_addr, 
                                                   vast.Minus(vast.Plus(core_addr, sg_size), vast.IntConst('1')),
                                               )),
                                  state,
                                  vast.Land(vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')),
                                            vast.GreaterThan(vast.Plus(phy_core_addr, size),
                                                             vast.IntConst(str(maximum_size)))))

        elif bind.value.syscall == 'coram_memory_wait':
            ramname = bind.value.args[0].name
            scattergather = self.coram_memories[ramname].scattergather
            __ramname = ramname + '(SG)' if scattergather else ramname
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s wait"
                                                                 ) % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                               )),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_busy'), vast.IntConst('0')))

        elif bind.value.syscall == 'coram_memory_test':
            ramname = bind.value.args[0].name
            scattergather = self.coram_memories[ramname].scattergather
            __ramname = ramname + '(SG)' if scattergather else ramname
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s memory:%s test"
                                                                 ) % (self.threadname, __ramname)),
                                                   vast.SystemCall('stime', ()),
                                               )),
                                  state)

        #--------------------------------------------------------------------------
        elif bind.value.syscall == 'coram_instream_write':
            ramname = bind.value.args[0].name
            ext_addr = bind.value.args[1]
            size = bind.value.args[2]
            self._append_fsm_bind(None, 
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s instream:%s write issue"
                                                                     " size:%%d"
                                                                     " <-D[%%d]") % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, ext_addr,
                                               )),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')))
            self._append_fsm_bind(None, 
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s instream:%s write done"
                                                                     " size:%%d"
                                                                     " <-D[%%d]") % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, ext_addr,
                                               )),
                                  state+2,
                                  vast.Eq(vast.Identifier(ramname+'_busy'), vast.IntConst('0')))

        elif bind.value.syscall == 'coram_instream_write_nonblocking':
            ramname = bind.value.args[0].name
            ext_addr = bind.value.args[1]
            size = bind.value.args[2]
            self._append_fsm_bind(None, 
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s instream:%s write nonblk"
                                                                     " size:%%d"
                                                                     " <-D[%%d]") % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, ext_addr,
                                               )),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')))

        elif bind.value.syscall == 'coram_instream_wait':
            ramname = bind.value.args[0].name
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s instream:%s wait"
                                                                 ) % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                               )),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_busy'), vast.IntConst('0')))

        elif bind.value.syscall == 'coram_instream_test':
            ramname = bind.value.args[0].name
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s instream:%s test"
                                                                 ) % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                               )),
                                  state)

        #--------------------------------------------------------------------------
        elif bind.value.syscall == 'coram_outstream_read':
            ramname = bind.value.args[0].name
            ext_addr = bind.value.args[1]
            size = bind.value.args[2]
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s outstream:%s read issue"
                                                                     " size:%%d"
                                                                     " ->D[%%d]") % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, ext_addr,
                                               )),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')))
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s outstream:%s read done"
                                                                     " size:%%d"
                                                                     " ->D[%%d]") % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, ext_addr,
                                               )),
                                  state+2,
                                  vast.Eq(vast.Identifier(ramname+'_busy'), vast.IntConst('0')))

        elif bind.value.syscall == 'coram_outstream_read_nonblocking':
            ramname = bind.value.args[0].name
            ext_addr = bind.value.args[1]
            size = bind.value.args[2]
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s outstream:%s read nonblk"
                                                                     " size:%%d"
                                                                     " ->D[%%d]") % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   size, ext_addr,
                                               )),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_ready'), vast.IntConst('1')))

        elif bind.value.syscall == 'coram_outstream_wait':
            ramname = bind.value.args[0].name
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s outstream:%s wait"
                                                                 ) % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                               )),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_busy'), vast.IntConst('0')))

        elif bind.value.syscall == 'coram_outstream_test':
            ramname = bind.value.args[0].name
            self._append_fsm_bind(None,
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s outstream:%s test"
                                                                 ) % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                               )),
                                  state)

        #--------------------------------------------------------------------------
        elif bind.value.syscall == 'coram_channel_read':
            ramname = bind.value.args[0].name
            self._append_fsm_bind(None, 
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s channel:%s read"
                                                                     " data:%%d") % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   vast.Identifier(ramname+'_q'))),
                                  state+1)

        elif bind.value.syscall == 'coram_channel_write':
            ramname = bind.value.args[0].name
            write_data = bind.value.args[1]
            self._append_fsm_bind(None, 
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s channel:%s write"
                                                                     " data:%%d") % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   write_data)),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_almost_full'), vast.IntConst('0')))

        #--------------------------------------------------------------------------
        elif bind.value.syscall == 'coram_register_read':
            ramname = bind.value.args[0].name
            self._append_fsm_bind(None, 
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s register:%s read"
                                                                     " data:%%d") % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   vast.Identifier(ramname+'_q'))),
                                  state)

        elif bind.value.syscall == 'coram_register_write':
            ramname = bind.value.args[0].name
            write_data = bind.value.args[1]
            self._append_fsm_bind(None, 
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s register:%s write"
                                                                     " data:%%d") % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   write_data)),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_we'), vast.IntConst('1')))

        #--------------------------------------------------------------------------
        elif bind.value.syscall == 'coram_iochannel_read':
            ramname = bind.value.args[0].name
            self._append_fsm_bind(None, 
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s iochannel:%s read"
                                                                     " data:%%d") % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   vast.Identifier(ramname+'_q'))),
                                  state+1)

        elif bind.value.syscall == 'coram_iochannel_write':
            ramname = bind.value.args[0].name
            write_data = bind.value.args[1]
            self._append_fsm_bind(None, 
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s iochannel:%s write"
                                                                     " data:%%d") % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   write_data)),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_almost_full'), vast.IntConst('0')))

        #--------------------------------------------------------------------------
        elif bind.value.syscall == 'coram_ioregister_read':
            ramname = bind.value.args[0].name
            self._append_fsm_bind(None, 
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s ioregister:%s read"
                                                                     " data:%%d") % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   vast.Identifier(ramname+'_q'))),
                                  state)

        elif bind.value.syscall == 'coram_ioregister_write':
            ramname = bind.value.args[0].name
            write_data = bind.value.args[1]
            self._append_fsm_bind(None, 
                                  vast.SystemCall('display',
                                                  (vast.StringConst(("[CoRAM] time:%%d thread:%s ioregister:%s write"
                                                                     " data:%%d") % (self.threadname, ramname)),
                                                   vast.SystemCall('stime', ()),
                                                   write_data)),
                                  state,
                                  vast.Eq(vast.Identifier(ramname+'_we'), vast.IntConst('1')))
    
    #--------------------------------------------------------------------------
    def _insertFinish(self):
        finish_m2 = self.fsm.count
        finish_m1 = self.fsm.count + 1
        finish = self.fsm.count + 2
        self.fsm.set(finish_m2, finish_m1)
        self.fsm.set(finish_m1, finish)
        self.fsm.setBind(None,
                         vast.SystemCall('display',
                                         (vast.StringConst(("[CoRAM] time:%%d thread:%s"
                                                            " finished") % self.threadname),
                                          vast.SystemCall('stime', ()))),
                         finish_m1)
        self.fsm.setBind(vast.Identifier('finish'), vast.IntConst('1'), finish_m1)

    #----------------------------------------------------------------------------
    def _generateModulePort(self):
        portlist = []
        # system input
        portlist.append( vast.Ioport(vast.Input('CLK')) )
        portlist.append( vast.Ioport(vast.Input('RST')) )

        # finish signal
        portlist.append( vast.Ioport(vast.Output('finish'), vast.Reg('finish')) )

        already_inserted = set([])

        # CoRAM memory port
        for memname, mem in self.coram_memories.items():
            prefix = []
            prefix.append(mem.name)
            prefix.append('_')
            prefix_str = ''.join(prefix)
            if prefix_str in already_inserted: continue
            already_inserted.add(prefix_str)

            ext_addrwidth = vast.Width(vast.IntConst(str(self.ext_addrwidth-1)), vast.IntConst('0'))
            core_addrwidth = vast.Width(vast.IntConst(str(self.ext_addrwidth-1)), vast.IntConst('0'))
            size_addrwidth = vast.Width(vast.IntConst(str(self.ext_addrwidth)), vast.IntConst('0'))
            datawidth = vast.Width(vast.IntConst(str(mem.datawidth-1)), vast.IntConst('0'))

            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['ext_addr']), width=ext_addrwidth),
                                         vast.Reg(''.join(prefix+['ext_addr']), width=ext_addrwidth)) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['core_addr']), width=core_addrwidth),
                                         vast.Reg(''.join(prefix+['core_addr']), width=core_addrwidth)) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['read_enable'])),
                                         vast.Reg(''.join(prefix+['read_enable']))) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['write_enable'])),
                                         vast.Reg(''.join(prefix+['write_enable']))) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['word_size']), width=size_addrwidth),
                                         vast.Reg(''.join(prefix+['word_size']), width=size_addrwidth)) )
            portlist.append( vast.Ioport(vast.Input(''.join(prefix+['ready']))) )
            portlist.append( vast.Ioport(vast.Input(''.join(prefix+['busy']))) )

        # CoRAM instream port
        for memname, mem in self.coram_instreams.items():
            prefix = []
            prefix.append(mem.name)
            prefix.append('_')
            prefix_str = ''.join(prefix)
            if prefix_str in already_inserted: continue
            already_inserted.add(prefix_str)

            ext_addrwidth = vast.Width(vast.IntConst(str(self.ext_addrwidth-1)), vast.IntConst('0'))
            size_addrwidth = vast.Width(vast.IntConst(str(self.ext_addrwidth)), vast.IntConst('0'))
            datawidth = vast.Width(vast.IntConst(str(mem.datawidth-1)), vast.IntConst('0'))

            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['ext_addr']), width=ext_addrwidth),
                                         vast.Reg(''.join(prefix+['ext_addr']), width=ext_addrwidth)) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['write_enable'])),
                                         vast.Reg(''.join(prefix+['write_enable']))) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['word_size']), width=size_addrwidth),
                                         vast.Reg(''.join(prefix+['word_size']), width=size_addrwidth)) )
            portlist.append( vast.Ioport(vast.Input(''.join(prefix+['ready']))) )
            portlist.append( vast.Ioport(vast.Input(''.join(prefix+['busy']))) )

        # CoRAM outstream port
        for memname, mem in self.coram_outstreams.items():
            prefix = []
            prefix.append(mem.name)
            prefix.append('_')
            prefix_str = ''.join(prefix)
            if prefix_str in already_inserted: continue
            already_inserted.add(prefix_str)

            ext_addrwidth = vast.Width(vast.IntConst(str(self.ext_addrwidth-1)), vast.IntConst('0'))
            size_addrwidth = vast.Width(vast.IntConst(str(self.ext_addrwidth)), vast.IntConst('0'))
            datawidth = vast.Width(vast.IntConst(str(mem.datawidth-1)), vast.IntConst('0'))

            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['ext_addr']), width=ext_addrwidth),
                                         vast.Reg(''.join(prefix+['ext_addr']), width=ext_addrwidth)) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['read_enable'])),
                                         vast.Reg(''.join(prefix+['read_enable']))) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['word_size']), width=size_addrwidth),
                                         vast.Reg(''.join(prefix+['word_size']), width=size_addrwidth)) )
            portlist.append( vast.Ioport(vast.Input(''.join(prefix+['ready']))) )
            portlist.append( vast.Ioport(vast.Input(''.join(prefix+['busy']))) )

        # Channel Port
        for memname, mem in self.coram_channels.items():
            prefix = []
            prefix.append(mem.name)
            prefix.append('_')
            prefix_str = ''.join(prefix)
            if prefix_str in already_inserted: continue
            already_inserted.add(prefix_str)

            datawidth = vast.Width(vast.IntConst(str(mem.datawidth-1)), vast.IntConst('0'))

            portlist.append( vast.Ioport(vast.Input(''.join(prefix+['q']), width=datawidth)) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['deq'])),
                                         vast.Reg(''.join(prefix+['deq']))) )
            portlist.append( vast.Ioport(vast.Input(''.join(prefix+['empty']))) )

            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['d']), width=datawidth),
                                         vast.Reg(''.join(prefix+['d']), width=datawidth)) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['enq'])),
                                         vast.Reg(''.join(prefix+['enq']))) )
            portlist.append( vast.Ioport(vast.Input(''.join(prefix+['almost_full']))) )

        # Register Port
        for memname, mem in self.coram_registers.items():
            prefix = []
            prefix.append(mem.name)
            prefix.append('_')
            prefix_str = ''.join(prefix)
            if prefix_str in already_inserted: continue
            already_inserted.add(prefix_str)

            datawidth = vast.Width(vast.IntConst(str(mem.datawidth-1)), vast.IntConst('0'))

            portlist.append( vast.Ioport(vast.Input(''.join(prefix+['q']), width=datawidth)) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['we'])),
                                         vast.Reg(''.join(prefix+['we']))) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['d']), width=datawidth),
                                         vast.Reg(''.join(prefix+['d']), width=datawidth)) )

        # I/O Channel Port
        for memname, mem in self.coram_iochannels.items():
            prefix = []
            prefix.append(mem.name)
            prefix.append('_')
            prefix_str = ''.join(prefix)
            if prefix_str in already_inserted: continue
            already_inserted.add(prefix_str)

            datawidth = vast.Width(vast.IntConst(str(mem.datawidth-1)), vast.IntConst('0'))

            portlist.append( vast.Ioport(vast.Input(''.join(prefix+['q']), width=datawidth)) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['deq'])),
                                         vast.Reg(''.join(prefix+['deq']))) )
            portlist.append( vast.Ioport(vast.Input(''.join(prefix+['empty']))) )

            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['d']), width=datawidth),
                                         vast.Reg(''.join(prefix+['d']), width=datawidth)) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['enq'])),
                                         vast.Reg(''.join(prefix+['enq']))) )
            portlist.append( vast.Ioport(vast.Input(''.join(prefix+['almost_full']))) )

        # I/O Register Port
        for memname, mem in self.coram_ioregisters.items():
            prefix = []
            prefix.append(mem.name)
            prefix.append('_')
            prefix_str = ''.join(prefix)
            if prefix_str in already_inserted: continue
            already_inserted.add(prefix_str)

            datawidth = vast.Width(vast.IntConst(str(mem.datawidth-1)), vast.IntConst('0'))

            portlist.append( vast.Ioport(vast.Input(''.join(prefix+['q']), width=datawidth)) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['we'])),
                                         vast.Reg(''.join(prefix+['we']))) )
            portlist.append( vast.Ioport(vast.Output(''.join(prefix+['d']), width=datawidth),
                                         vast.Reg(''.join(prefix+['d']), width=datawidth)) )

        return portlist

    #----------------------------------------------------------------------------
    def _generateVariableDefinition(self):
        signalwidth = vast.Width(vast.IntConst(str(self.signalwidth-1)), vast.IntConst('0'))
        signallist = []

        for frame in self.scope.scopeframes:
            for variable in frame.variables:
                vname = frame.searchVariable(variable)
                if (vname in self.coram_memories or 
                    vname in self.coram_instreams or 
                    vname in self.coram_outstreams or 
                    vname in self.coram_channels or 
                    vname in self.coram_registers or
                    vname in self.coram_iochannels or 
                    vname in self.coram_ioregisters):
                    continue
                if vname in self.const_binds:
                    signallist.append( vast.Parameter(vname, self.const_binds[vname]) )
                    self.parameters.add( vname )
                    continue
                signallist.append( vast.Reg(vname, width=signalwidth) )
        return signallist

    #----------------------------------------------------------------------------
    def _generateFsm(self):
        items = []
        fsm_width = vast.Width(vast.IntConst(str(log2(self.fsm.count)-1+1)), vast.IntConst('0'))
        items.append( vast.Reg(self.fsm_name, width=fsm_width) )

        fsm_statement = []

        fsm_reset_subs = vast.NonblockingSubstitution(vast.Identifier(self.fsm_name), vast.IntConst('0'))
        fsm_reset = vast.Block( (fsm_reset_subs,) )

        fsm_caselist = []
        for src, nodelist in self.fsm.dict.items():
            case_cond = (vast.IntConst(str(src)),)
            case_stmt = []
            for node in nodelist:
                if node.cond is None: # normal
                    case_stmt.append(vast.NonblockingSubstitution(vast.Identifier(self.fsm_name),
                                                                  vast.IntConst(str(node.dst))))
                else: # branch
                    opt_cond = self._optimize(node.cond)
                    transcond = vast.IfStatement(opt_cond,
                                                 vast.NonblockingSubstitution(vast.Identifier(self.fsm_name),
                                                                              vast.IntConst(str(node.dst))),
                                                 vast.NonblockingSubstitution(vast.Identifier(self.fsm_name),
                                                                              vast.IntConst(str(node.elsedst))))
                    case_stmt.append(transcond)

            fsm_caselist.append( vast.Case(case_cond, vast.Block(tuple(case_stmt))) )

        fsm_case = vast.CaseStatement(vast.Identifier(self.fsm_name), tuple(fsm_caselist))
        fsm_main = fsm_case

        fsm_if = vast.IfStatement(vast.Eq(vast.Identifier('RST'), vast.IntConst('1')), fsm_reset, fsm_main)
        fsm_statement.append(fsm_if)

        fsm_senslist = (vast.Sens(vast.Identifier('CLK'),'posedge'),)
        fsm_always = vast.Always(vast.SensList(fsm_senslist), vast.Block(tuple(fsm_statement)))
        items.append(fsm_always)

        return items

    #----------------------------------------------------------------------------
    def _generateBind(self):
        items = []
        bind_statement = []
        bind_caselist = {}
        for state, bindlist in self.fsm.bind.items():
            case_cond = (vast.IntConst(str(state)),)
            case_stmt = []

            for bind in bindlist:
                if bind.dst is not None: # normal statement
                    if bind.dst.name in self.parameters:
                        continue
                    if bind.cond is None:
                        opt_value = self._optimize(bind.value)
                        case_stmt.append( vast.NonblockingSubstitution(bind.dst, opt_value) )
                    else:
                        opt_value = self._optimize(bind.value)
                        opt_cond = self._optimize(bind.cond)
                        case_stmt.append( vast.IfStatement(opt_cond, vast.NonblockingSubstitution(bind.dst, opt_value), None) )
                elif isinstance(bind.value, vast.SystemCall):
                    if (bind.value.syscall == 'coram_memory_read' or 
                        bind.value.syscall == 'coram_memory_write' or
                        bind.value.syscall == 'coram_memory_read_nonblocking' or 
                        bind.value.syscall == 'coram_memory_write_nonblocking' or
                        bind.value.syscall == 'coram_memory_test' or
                        bind.value.syscall == 'coram_memory_wait' or
                        bind.value.syscall == 'coram_instream_write' or
                        bind.value.syscall == 'coram_instream_write_nonblocking' or
                        bind.value.syscall == 'coram_instream_test' or
                        bind.value.syscall == 'coram_instream_wait' or
                        bind.value.syscall == 'coram_outstream_read' or
                        bind.value.syscall == 'coram_outstream_read_nonblocking' or
                        bind.value.syscall == 'coram_outstream_test' or
                        bind.value.syscall == 'coram_outstream_wait' or
                        bind.value.syscall == 'coram_channel_read' or
                        bind.value.syscall == 'coram_channel_write' or
                        bind.value.syscall == 'coram_register_read' or
                        bind.value.syscall == 'coram_register_write' or 
                        bind.value.syscall == 'coram_iochannel_read' or
                        bind.value.syscall == 'coram_iochannel_write' or
                        bind.value.syscall == 'coram_ioregister_read' or
                        bind.value.syscall == 'coram_ioregister_write'):
                        continue
                    if bind.cond is None:
                        case_stmt.append( vast.SingleStatement(bind.value) )
                    else:
                        case_stmt.append( vast.IfStatement(bind.cond, vast.SingleStatement(bind.value), None) )
                else:
                    if bind.cond is None:
                        case_stmt.append( vast.SingleStatement(bind.value) )
                    else:
                        case_stmt.append( vast.IfStatement(bind.cond, vast.SingleStatement(bind.value), None) )

            if state not in bind_caselist:
                bind_caselist[state] = vast.Case(case_cond, vast.Block(tuple(case_stmt)))
            else:
                new_case_stmt = tuple(bind_caselist[state].statement + case_stmt)
                bind_caselist[state] = vast.Case(case_cond, vast.Block(new_case_stmt))

        bind_case = vast.CaseStatement(vast.Identifier(self.fsm_name), tuple(bind_caselist.values()))
        bind_statement.append(bind_case)

        bind_senslist = (vast.Sens(vast.Identifier('CLK'),'posedge'), )
        bind_always = vast.Always(vast.SensList(bind_senslist), vast.Block(tuple(bind_statement)))
        items.append(bind_always)
        
        return items

    #----------------------------------------------------------------------------
    def _generateSource(self, paramlist, portlist, signallist, items):
        m_paramlist = vast.Paramlist(tuple(paramlist))
        m_portlist = vast.Portlist(tuple(portlist))
        m_items = tuple(signallist + items)
        module = vast.ModuleDef(self.threadname, m_paramlist, m_portlist, m_items)
        description = vast.Description( (module,) )
        source = vast.Source(self.threadname, description )
        return source

    #----------------------------------------------------------------------------
    def _generateCode(self, source):
        asttocode = ASTCodeGenerator()
        code = asttocode.visit(source)
        return code

    #----------------------------------------------------------------------------
    def generate(self):
        paramlist = []
        portlist = []
        signallist = []
        items = []

        self._insertCommand()
        self._insertFinish()
        portlist.extend(self._generateModulePort())
        signallist.extend(self._generateVariableDefinition())
        items.extend(self._generateFsm())
        items.extend(self._generateBind())
        source = self._generateSource(paramlist, portlist, signallist, items)
        code = self._generateCode(source)
        return code
