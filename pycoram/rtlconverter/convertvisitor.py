#-------------------------------------------------------------------------------
# convertvisitor.py
# 
# Verilog AST convert visitor for PyCoRAM
#
# Copyright (C) 2013, Shinya Takamaeda-Yamazaki
# License: Apache 2.0
#-------------------------------------------------------------------------------
import sys
import os

import re
import copy
import collections

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))) )

import pyverilog.utils.util as util
import pyverilog.utils.verror as verror
from pyverilog.utils.scope import ScopeLabel, ScopeChain
from pyverilog.vparser.ast import *
import pyverilog.dataflow.dataflow as dataflow
from pyverilog.dataflow.visit import *
from pyverilog.dataflow.signalvisitor import SignalVisitor

#-------------------------------------------------------------------------------
class InstanceConvertVisitor(SignalVisitor):
    def __init__(self, moduleinfotable, top):
        SignalVisitor.__init__(self, moduleinfotable, top)
        self.new_moduleinfotable = ModuleInfoTable()
        self.coram_object = collections.defaultdict(list)

        self.rename_prefix = '_r'
        self.rename_prefix_count = 0
        self.used = set([])

        self.replaced_instance = {}
        self.replaced_instports = {}
        self.replaced_items = {}
        self.merged_replaced_instance = {} # replaced target used in next stage

        self.additionalport = [] # temporal variable

    #----------------------------------------------------------------------------
    def get_new_moduleinfotable(self):
        return self.new_moduleinfotable

    def getModuleDefinition(self, name):
        return self.new_moduleinfotable.dict[name].definition

    #----------------------------------------------------------------------------
    def getMergedReplacedInstance(self):
        self.mergeInstancelist()
        return self.merged_replaced_instance

    def getReplacedInstPorts(self):
        return self.replaced_instports

    def getReplacedItems(self):
        return self.replaced_items

    #----------------------------------------------------------------------------
    def getCoramObject(self):
        return self.coram_object

    #----------------------------------------------------------------------------
    def copyModuleInfo(self, src, dst):
        if dst not in self.new_moduleinfotable.dict:
            if src == dst:
                self.new_moduleinfotable.dict[dst] = self.moduleinfotable.dict[src]
            else:
                self.new_moduleinfotable.dict[dst] = copy.deepcopy(self.moduleinfotable.dict[src])
                self.new_moduleinfotable.dict[dst].definition.name = dst
        if (src != dst) and (dst not in self.moduleinfotable.dict):
            self.moduleinfotable.dict[dst] = copy.deepcopy(self.moduleinfotable.dict[src])

    #----------------------------------------------------------------------------
    def changeModuleName(self, dst, name):
        self.moduleinfotable.dict[dst].definition.name = name

    #----------------------------------------------------------------------------
    def isUsed(self, name):
        return (name in self.used)

    def setUsed(self, name):
        if name not in self.used: self.used.add(name)

    def rename(self, name):
        ret = name + self.rename_prefix + str(self.rename_prefix_count)
        self.rename_prefix_count += 1
        return ret

    #----------------------------------------------------------------------------
    def appendInstance(self, key, value):
        actualkey = id(key)
        if actualkey not in self.replaced_instance:
            self.replaced_instance[actualkey] = []
        self.replaced_instance[actualkey].append(value)

    def mergeInstancelist(self):
        for key, insts in self.replaced_instance.items():
            head = self.mergeInstances(key, insts)
            self.merged_replaced_instance[key] = head

    def mergeInstances(self, key, insts):
        head = None
        tail = None
        for inst in insts:
            if head is None: 
                head = inst
                tail = inst
            else:
                tail.false_statement = inst
                tail = tail.false_statement
        return head

    #----------------------------------------------------------------------------    
    def extendInstPorts(self, key, value):
        actualkey = id(key)
        if actualkey not in self.replaced_instports:
            self.replaced_instports[actualkey] = []
        self.replaced_instports[actualkey].extend(value)

    #----------------------------------------------------------------------------
    def extendItems(self, key, value):
        actualkey = id(key)
        if actualkey not in self.replaced_items:
            self.replaced_items[actualkey] = []
        self.replaced_items[actualkey].extend(value)

    #----------------------------------------------------------------------------
    def updateInstancePort(self, node, generate=False):
        new_node = copy.deepcopy(node)
        instance = new_node.instances[0]
        
        ioport = not (len(instance.portlist) == 0 or 
                      instance.portlist[0].portname is None)
        new_portlist = list(instance.portlist)
        if ioport:
            for i, a in enumerate(self.additionalport):
                new_portlist.append(PortArg(copy.deepcopy(a.name),
                                            Identifier(copy.deepcopy(a.name))))
        else:
            for a in self.additionalport:
                new_portlist.append(PortArg(None, Identifier(copy.deepcopy(a.name))))
        instance.portlist = tuple(new_portlist)

        if generate:
            blockstatement = []
            blockstatement.append(new_node)
            block = Block( tuple(blockstatement) )

            genconds = self.frames.getGenerateConditions()
            condlist = []
            for iter, val in genconds:
                if iter is None: # generate if
                    #condlist.append( val )
                    pass
                else: # generate for
                    name = iter[-1].scopename
                    condlist.append( Eq(Identifier(name), IntConst(str(val))) )

            cond = None
            for c in condlist:
                if cond is None:
                    cond = c
                else:
                    cond = Land(cond, c)

            if cond is None:
                cond = IntConst('1')

            ret = IfStatement(cond, block, None)
            self.appendInstance(node, ret)
        else:
            ret = new_node
            self.appendInstance(node, ret)

        module = self.getModuleDefinition(node.module)
        self.updateModulePort(module)

    #---------------------------------------------------------------------------- 
    def updateModulePort(self, node):
        new_portlist = list(node.portlist.ports)
        ioport = not (len(node.portlist.ports) == 0 or 
                      isinstance(node.portlist.ports[0], Port))
        if ioport:
            for a in self.additionalport:
                new_portlist.append(Ioport(copy.deepcopy(a)))
        else:
            for a in self.additionalport:
                new_portlist.append(Port(a.name, width=a.width, type=None))
        self.extendInstPorts(node, new_portlist)
        if not ioport:
            new_items = copy.deepcopy(self.additionalport)
            new_items.extend(list(node.items))
            self.extendItems(node, new_items)

    #----------------------------------------------------------------------------
    def convertCoramInstance(self, node, mode, generate=False, opt=None):
        threadname = None
        threadindex = None # unused

        ramid = None
        ramsubid = None

        addrmsb = None
        datamsb = None

        current = self.frames.getCurrent()
        param_names = self.moduleinfotable.getParamNames(node.module)

        for param_i, param in enumerate(node.parameterlist):
            param_name = param_names[param_i] if param.paramname is None else param.paramname 
            if param_name == 'CORAM_THREAD_NAME':
                threadname = copy.deepcopy(param.argname)
            elif param_name == 'CORAM_THREAD_ID':
                print("warning: CORAM_THREAD_INDEX is not used.")
                threadindex = copy.deepcopy(param.argname)
            elif param_name == 'CORAM_ID':
                ramid = copy.deepcopy(param.argname)
            elif param_name == 'CORAM_SUB_ID':
                ramsubid = copy.deepcopy(param.argname)
            elif param_name == 'CORAM_ADDR_LEN':
                addrmsb = copy.deepcopy(param.argname)
            elif param_name == 'CORAM_DATA_WIDTH':
                datamsb = copy.deepcopy(param.argname)
            else:
                raise NameError("No such parameter '%s' in %s" % (param_name, mode))

        addrwidth = None
        if addrmsb is not None:
            addrwidth = Width(Minus(addrmsb, IntConst('1')), IntConst('0'))
        else:
            addrwidth = ( Width(IntConst('3'), IntConst('0')) if mode == 'CoramChannel'
                          else Width(IntConst('9'), IntConst('0')) )

        datawidth = None
        if datamsb is not None:
            datawidth = Width(Minus(datamsb, IntConst('1')), IntConst('0'))
        else:
            datawidth = Width(IntConst('31'), IntConst('0'))

        if threadname is None:
            raise ValueError("CORAM_THREAD_NAME must be set in instance '%s'." % node.name)
        #if threadindex is None:
        #    raise ValueError("CORAM_THREAD_ID must be set in instance '%s'." % node.name)
        if ramid is None:
            raise ValueError("CORAM_ID must be set in instance '%s'." % node.name)
        if mode == 'CoramMemory' and ramsubid is None:
            #raise ValueError("CORAM_SUB_ID must be set in instance '%s'." % node.name)
            ramsubid = IntConst('0')

        evalthreadname = self.optimize(self.getTree(threadname, current))
        if not isinstance(evalthreadname, dataflow.DFEvalValue) or not isinstance(evalthreadname.value, str):
            raise TypeError("CORAM_THREAD_NAME should be string in thread '%s' in instance '%s' " % (str(threadname), node.name))
        evalthreadname_value = evalthreadname.value

        evalramid_value = self.optimize(self.getTree(ramid, current)).value
        evalramsubid_value = None
        if mode == 'CoramMemory':
            evalramsubid_value = self.optimize(self.getTree(ramsubid, current)).value
        evaladdrwidth_msb_value = self.optimize(self.getTree(addrwidth.msb, current)).value
        evaladdrwidth_lsb_value = self.optimize(self.getTree(addrwidth.lsb, current)).value
        evaldatawidth_msb_value = self.optimize(self.getTree(datawidth.msb, current)).value
        evaldatawidth_lsb_value = self.optimize(self.getTree(datawidth.lsb, current)).value

        evaladdrwidth = Width(IntConst(str(evaladdrwidth_msb_value)), IntConst(str(evaladdrwidth_lsb_value)))
        evaladdrwidth_p1 = Width(IntConst(str(evaladdrwidth_msb_value+1)), IntConst(str(evaladdrwidth_lsb_value)))
        evaldatawidth = Width(IntConst(str(evaldatawidth_msb_value)), IntConst(str(evaldatawidth_lsb_value)))

        nameprefix_list = [ evalthreadname_value, '_', mode.lower(), '_', str(evalramid_value) ]
        if mode == 'CoramMemory':
            nameprefix_list.append('_')
            nameprefix_list.append(str(evalramsubid_value))
        nameprefix = ''.join(nameprefix_list)

        self.addCoramObject(mode, 
                            evalthreadname_value, evalramid_value, evalramsubid_value,
                            (evaladdrwidth_msb_value, evaladdrwidth_lsb_value),
                            (evaldatawidth_msb_value, evaldatawidth_lsb_value) )

        if mode == 'CoramMemory':
            self.additionalport.append( Input(name=nameprefix+'_clk') )
            self.additionalport.append( Input(name=nameprefix+'_addr', width=evaladdrwidth) )
            self.additionalport.append( Input(name=nameprefix+'_d', width=evaldatawidth) )
            self.additionalport.append( Input(name=nameprefix+'_we') )
            self.additionalport.append( Output(name=nameprefix+'_q', width=evaldatawidth) )
        elif mode == 'CoramInStream':
            self.additionalport.append( Input(name=nameprefix+'_clk') )
            self.additionalport.append( Input(name=nameprefix+'_rst') )
            self.additionalport.append( Input(name=nameprefix+'_d', width=evaldatawidth) )
            self.additionalport.append( Input(name=nameprefix+'_enq') )
            self.additionalport.append( Output(name=nameprefix+'_almost_full') )
            self.additionalport.append( Output(name=nameprefix+'_room_enq', width=evaladdrwidth_p1) )
        elif mode == 'CoramOutStream':
            self.additionalport.append( Input(name=nameprefix+'_clk') )
            self.additionalport.append( Input(name=nameprefix+'_rst') )
            self.additionalport.append( Output(name=nameprefix+'_q', width=evaldatawidth) )
            self.additionalport.append( Input(name=nameprefix+'_deq') )
            self.additionalport.append( Output(name=nameprefix+'_empty') )
        elif mode == 'CoramChannel':
            self.additionalport.append( Input(name=nameprefix+'_clk') )
            self.additionalport.append( Input(name=nameprefix+'_rst') )
            self.additionalport.append( Input(name=nameprefix+'_d', width=evaldatawidth) )
            self.additionalport.append( Input(name=nameprefix+'_enq') )
            self.additionalport.append( Output(name=nameprefix+'_almost_full') )
            self.additionalport.append( Output(name=nameprefix+'_q', width=evaldatawidth) )
            self.additionalport.append( Input(name=nameprefix+'_deq') )
            self.additionalport.append( Output(name=nameprefix+'_empty') )
        elif mode == 'CoramRegister':
            self.additionalport.append( Input(name=nameprefix+'_clk') )
            self.additionalport.append( Input(name=nameprefix+'_d', width=evaldatawidth) )
            self.additionalport.append( Input(name=nameprefix+'_we') )
            self.additionalport.append( Output(name=nameprefix+'_q', width=evaldatawidth) )
        elif mode == 'CoramSlaveStream':
            self.additionalport.append( Input(name=nameprefix+'_clk') )
            self.additionalport.append( Input(name=nameprefix+'_rst') )
            self.additionalport.append( Input(name=nameprefix+'_d', width=evaldatawidth) )
            self.additionalport.append( Input(name=nameprefix+'_enq') )
            self.additionalport.append( Output(name=nameprefix+'_almost_full') )
            self.additionalport.append( Output(name=nameprefix+'_q', width=evaldatawidth) )
            self.additionalport.append( Input(name=nameprefix+'_deq') )
            self.additionalport.append( Output(name=nameprefix+'_empty') )

        new_node = copy.deepcopy(node)
        instance = new_node.instances[0]
        
        noportname = (len(instance.portlist) == 0 or
                      instance.portlist[0].portname is None)
        new_portlist = list(instance.portlist)
        
        if noportname:
            if mode == 'CoramMemory':
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_clk')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_addr')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_d')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_we')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_q')) )
            elif mode == 'CoramInStream':
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_clk')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_rst')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_d')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_enq')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_almost_full')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_room_enq')) )
            elif mode == 'CoramOutStream':
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_clk')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_rst')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_q')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_deq')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_empty')) )
            elif mode == 'CoramChannel':
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_clk')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_rst')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_d')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_enq')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_almost_full')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_q')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_deq')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_empty')) )
            elif mode == 'CoramRegister':
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_clk')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_d')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_we')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_q')) )
            elif mode == 'CoramSlaveStream':
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_clk')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_rst')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_d')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_enq')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_almost_full')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_q')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_deq')) )
                new_portlist.append( PortArg(None, Identifier(nameprefix+'_empty')) )
        else:
            if mode == 'CoramMemory':
                new_portlist.append( PortArg('coram_clk', Identifier(nameprefix+'_clk')) )
                new_portlist.append( PortArg('coram_addr', Identifier(nameprefix+'_addr')) )
                new_portlist.append( PortArg('coram_d', Identifier(nameprefix+'_d')) )
                new_portlist.append( PortArg('coram_we', Identifier(nameprefix+'_we')) )
                new_portlist.append( PortArg('coram_q', Identifier(nameprefix+'_q')) )
            elif mode == 'CoramInStream':
                new_portlist.append( PortArg('coram_clk', Identifier(nameprefix+'_clk')) )
                new_portlist.append( PortArg('coram_rst', Identifier(nameprefix+'_rst')) )
                new_portlist.append( PortArg('coram_d', Identifier(nameprefix+'_d')) )
                new_portlist.append( PortArg('coram_enq', Identifier(nameprefix+'_enq')) )
                new_portlist.append( PortArg('coram_almost_full', Identifier(nameprefix+'_almost_full')) )
                new_portlist.append( PortArg('coram_room_enq', Identifier(nameprefix+'_room_enq')) )
            elif mode == 'CoramOutStream':
                new_portlist.append( PortArg('coram_clk', Identifier(nameprefix+'_clk')) )
                new_portlist.append( PortArg('coram_rst', Identifier(nameprefix+'_rst')) )
                new_portlist.append( PortArg('coram_q', Identifier(nameprefix+'_q')) )
                new_portlist.append( PortArg('coram_deq', Identifier(nameprefix+'_deq')) )
                new_portlist.append( PortArg('coram_empty', Identifier(nameprefix+'_empty')) )
            elif mode == 'CoramChannel':
                new_portlist.append( PortArg('coram_clk', Identifier(nameprefix+'_clk')) )
                new_portlist.append( PortArg('coram_rst', Identifier(nameprefix+'_rst')) )
                new_portlist.append( PortArg('coram_d', Identifier(nameprefix+'_d')) )
                new_portlist.append( PortArg('coram_enq', Identifier(nameprefix+'_enq')) )
                new_portlist.append( PortArg('coram_almost_full', Identifier(nameprefix+'_almost_full')) )
                new_portlist.append( PortArg('coram_q', Identifier(nameprefix+'_q')) )
                new_portlist.append( PortArg('coram_deq', Identifier(nameprefix+'_deq')) )
                new_portlist.append( PortArg('coram_empty', Identifier(nameprefix+'_empty')) )
            elif mode == 'CoramRegister':
                new_portlist.append( PortArg('coram_clk', Identifier(nameprefix+'_clk')) )
                new_portlist.append( PortArg('coram_d', Identifier(nameprefix+'_d')) )
                new_portlist.append( PortArg('coram_we', Identifier(nameprefix+'_we')) )
                new_portlist.append( PortArg('coram_q', Identifier(nameprefix+'_q')) )
            elif mode == 'CoramSlaveStream':
                new_portlist.append( PortArg('coram_clk', Identifier(nameprefix+'_clk')) )
                new_portlist.append( PortArg('coram_rst', Identifier(nameprefix+'_rst')) )
                new_portlist.append( PortArg('coram_d', Identifier(nameprefix+'_d')) )
                new_portlist.append( PortArg('coram_enq', Identifier(nameprefix+'_enq')) )
                new_portlist.append( PortArg('coram_almost_full', Identifier(nameprefix+'_almost_full')) )
                new_portlist.append( PortArg('coram_q', Identifier(nameprefix+'_q')) )
                new_portlist.append( PortArg('coram_deq', Identifier(nameprefix+'_deq')) )
                new_portlist.append( PortArg('coram_empty', Identifier(nameprefix+'_empty')) )

        instance.portlist = tuple(new_portlist)

        if generate:
            blockstatement = []
            blockstatement.append(new_node)
            block = Block( tuple(blockstatement) )

            genconds = self.frames.getGenerateConditions()
            condlist = []
            for iter, val in genconds:
                if iter is None: # generate if
                    #condlist.append( val )
                    pass
                else: # generate for
                    name = iter[-1].scopename
                    condlist.append( Eq(Identifier(name), IntConst(str(val))) )

            cond = None
            for c in condlist:
                if cond is None:
                    cond = c
                else:
                    cond = Land(cond, c)

            if cond is None:
                cond = IntConst('1')

            ret = IfStatement(cond, block, None)
            self.appendInstance(node, ret)
        else:
            ret = new_node
            self.appendInstance(node, ret)

    #----------------------------------------------------------------------------
    def addCoramObject(self, mode, threadname, idx, subid, addrwidth, datawidth):
        self.coram_object[mode].append( (threadname, idx, subid, addrwidth, datawidth) )

    #----------------------------------------------------------------------------
    def start_visit(self):
        self.copyModuleInfo(self.top, self.top)
        node = self.getModuleDefinition(self.top)
        self.visit(node)
        self.updateModulePort(node)

    #----------------------------------------------------------------------------
    def visit_ModuleDef(self, node):
        new_node = self.getModuleDefinition(node.name)
        self.generic_visit(new_node)

    #----------------------------------------------------------------------------
    def visit_InstanceList(self, node):
        if len(node.instances) > 1: return
        
        m = re.match('(Coram.*)', node.module)
        if not m: # normal instance
            return self._visit_InstanceList_normal(node)
            
        memory = re.match('(CoramMemory).*', node.module)
        instream = re.match('(CoramInStream).*', node.module)
        outstream = re.match('(CoramOutStream).*', node.module)
        channel = re.match('(CoramChannel).*', node.module)
        register = re.match('(CoramRegister).*', node.module)
        slavestream = re.match('(CoramSlaveStream).*', node.module)
        mode = (memory.group(1) if memory else 
                instream.group(1) if instream else
                outstream.group(1) if outstream else
                channel.group(1) if channel else 
                register.group(1) if register else
                slavestream.group(1) if slavestream else
                'None')

        if mode == 'None':
            raise ValueError("Unknown CoRAM object type '%s'" % node.module)

        if self.frames.isGenerate():
            tmp = self.additionalport
            self.additionalport = []
            self.convertCoramInstance(node, mode, generate=True)
            tmp.extend(self.additionalport)
            self.additionalport = tmp
            return

        self.convertCoramInstance(node, mode, generate=False)

    #----------------------------------------------------------------------------
    def _visit_InstanceList_normal(self, node):
        if self.isUsed(node.module):
            tmp = self.additionalport
            self.additionalport = []
            new_module = self.rename(node.module)
            self.copyModuleInfo(node.module, new_module)
            prev_module_name = node.module
            node.module = new_module
            self.changeModuleName(node.module, node.module)
            SignalVisitor.visit_InstanceList(self, node)
            if self.additionalport:
                self.setUsed(node.module)
                self.updateInstancePort(node, generate=self.frames.isGenerate())
                tmp.extend(self.additionalport)
            self.additionalport = tmp
            node.module = prev_module_name
            self.changeModuleName(node.module, prev_module_name)
        else:
            tmp = self.additionalport
            self.additionalport = []
            self.copyModuleInfo(node.module, node.module)
            SignalVisitor.visit_InstanceList(self, node)
            if self.additionalport:
                self.setUsed(node.module)
                self.updateInstancePort(node, generate=self.frames.isGenerate())
                tmp.extend(self.additionalport)
            self.additionalport = tmp
        
#-------------------------------------------------------------------------------
def ischild(node, attr):
    if not isinstance(node, Node): return False
    excludes = ('coord', 'attr_names',)
    if attr.startswith('__'): return False
    if attr in excludes: return False
    attr_names = getattr(node, 'attr_names')
    if attr in attr_names: return False
    attr_test = getattr(node, attr)
    if hasattr(attr_test, '__call__'): return False
    return True

def children_items(node):
    children = [ attr for attr in dir(node) if ischild(node, attr) ]
    ret = []
    for c in children:
        ret.append( (c, getattr(node, c)) )
    return ret

class InstanceReplaceVisitor(NodeVisitor):
    """ replace instances in new_moduleinfotable by using object address """
    def __init__(self, replaced_instance, replaced_instports, replaced_items,
                 new_moduleinfotable):
        self.replaced_instance = replaced_instance
        self.replaced_instports = replaced_instports
        self.replaced_items = replaced_items
        self.new_moduleinfotable = new_moduleinfotable

    def getAST(self):
        modulelist = sorted([ m.definition for m in self.new_moduleinfotable.dict.values() ],
                            key=lambda x:x.name)
        new_modulelist = []
        for m in modulelist:
            new_modulelist.append( self.visit(m) )
        description = Description( tuple(new_modulelist) )
        source = Source('converted', description)
        return source

    def visit(self, node):
        method = 'visit_' + node.__class__.__name__
        visitor = getattr(self, method, self.generic_visit)
        ret = visitor(node)
        if ret is None: return node
        return ret

    def generic_visit(self, node):
        for name, child in children_items(node):
            ret = None
            if child is None: continue
            if (isinstance(child, list) or isinstance(child, tuple)):
                r = []
                for c in child:
                    r.append( self.visit(c) )
                ret = tuple(r)
            else:
                ret = self.visit(child)
            setattr(node, name, ret)
        return node
    
    def getReplacedNode(self, key):
        actualkey = id(key)
        return self.replaced_instance[actualkey]

    def hasReplacedNode(self, key):
        actualkey = id(key)
        return (actualkey in self.replaced_instance)

    def getReplacedInstPorts(self, key):
        actualkey = id(key)
        return self.replaced_instports[actualkey]

    def hasReplacedInstPorts(self, key):
        actualkey = id(key)
        return (actualkey in self.replaced_instports)

    def getReplacedItems(self, key):
        actualkey = id(key)
        return self.replaced_items[actualkey]

    def hasReplacedItems(self, key):
        actualkey = id(key)
        return (actualkey in self.replaced_items)

    def visit_InstanceList(self, node):
        if not self.hasReplacedNode(node):
            return self.generic_visit(node)
        return self.getReplacedNode(node)

    def visit_ModuleDef(self, node):
        if self.hasReplacedInstPorts(node):
            node.portlist.ports = tuple(self.getReplacedInstPorts(node))
        if self.hasReplacedItems(node):
            node.items = tuple(self.getReplacedItems(node))
        return self.generic_visit(node)
