#-------------------------------------------------------------------------------
# controlthread.py
#
# Python High-Level Synthesis for PyCoRAM Control Thread
#
# Copyright (C) 2013, Shinya Takamaeda-Yamazaki
# License: Apache 2.0
#-------------------------------------------------------------------------------
import os
import ast
import inspect
import sys
import re

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))) )

import utils.version

if sys.version_info[0] >= 3:
    from controlthread.scope import ScopeFrameList
    from controlthread.fsm import Fsm
    from controlthread.coram_module import CoramBase
    from controlthread.coram_module import CoramMemory
    from controlthread.coram_module import CoramInStream
    from controlthread.coram_module import CoramOutStream
    from controlthread.coram_module import CoramChannel
    from controlthread.coram_module import CoramRegister
    from controlthread.coram_module import CoramIoChannel
    from controlthread.coram_module import CoramIoRegister
    from controlthread.codegen import CodeGenerator
    import controlthread.maketree as maketree
    import controlthread.voperator as voperator
else:
    from scope import ScopeFrameList
    from fsm import Fsm
    from coram_module import CoramBase
    from coram_module import CoramMemory
    from coram_module import CoramInStream
    from coram_module import CoramOutStream
    from coram_module import CoramChannel
    from coram_module import CoramRegister
    from coram_module import CoramIoChannel
    from coram_module import CoramIoRegister
    from codegen import CodeGenerator
    import maketree as maketree
    import voperator as voperator
    
import pyverilog
import pyverilog.vparser
import pyverilog.vparser.ast as vast
import pyverilog.dataflow.optimizer as vopt

CORAM_MEMORY='CoramMemory'
CORAM_INSTREAM='CoramInStream'
CORAM_OUTSTREAM='CoramOutStream'
CORAM_CHANNEL='CoramChannel'
CORAM_REGISTER='CoramRegister'
CORAM_IOCHANNEL='CoramIoChannel'
CORAM_IOREGISTER='CoramIoRegister'

#-------------------------------------------------------------------------------
# Management Functions
#-------------------------------------------------------------------------------
class FunctionVisitor(ast.NodeVisitor):
    def __init__(self):
        self.functions = {}
    def getFunctions(self):
        return self.functions
    def visit_FunctionDef(self, node):
        self.functions[node.name] = node

#-------------------------------------------------------------------------------
class CompileVisitor(ast.NodeVisitor):
    def __init__(self, thread_name, functions, default_width=64):
        self.thread_name = thread_name
        self.coram_memories = {}
        self.coram_instreams = {}
        self.coram_outstreams = {}
        self.coram_channels = {}
        self.coram_registers = {}
        self.coram_iochannels = {}
        self.coram_ioregisters = {}
        self.objects = {}
        self.scope = ScopeFrameList()
        self.fsm = Fsm()
        self.import_list = {}
        self.importfrom_list = {}
        self.vopt = vopt.VerilogOptimizer({}, default_width=default_width)

        for func in functions.values():
            self.scope.addFunction(func)
        
    def dump(self):
        memories = {}
        instreams = {}
        outstreams = {}
        channels = {}
        registers = {}
        iochannels = {}
        ioregisters = {}
        memories_alias = {}
        instreams_alias = {}
        outstreams_alias = {}
        channels_alias = {}
        registers_alias = {}
        iochannels_alias = {}
        ioregisters_alias = {}
        for mk, mv in self.coram_memories.items():
            if mv.name not in memories: memories[mv.name] = mv
            if mv.name not in memories_alias: memories_alias[mv.name] = []
            memories_alias[mv.name].append( mk )
        for mk, mv in self.coram_instreams.items():
            if mv.name not in instreams: instreams[mv.name] = mv
            if mv.name not in instreams_alias: instreams_alias[mv.name] = []
            instreams_alias[mv.name].append( mk )
        for mk, mv in self.coram_outstreams.items():
            if mv.name not in outstreams: outstreams[mv.name] = mv
            if mv.name not in outstreams_alias: outstreams_alias[mv.name] = []
            outstreams_alias[mv.name].append( mk )
        for mk, mv in self.coram_channels.items():
            if mv.name not in channels: channels[mv.name] = mv
            if mv.name not in channels_alias: channels_alias[mv.name] = []
            channels_alias[mv.name].append( mk )
        for mk, mv in self.coram_registers.items():
            if mv.name not in registers: registers[mv.name] = mv
            if mv.name not in registers_alias: registers_alias[mv.name] = []
            registers_alias[mv.name].append( mk )
        for mk, mv in self.coram_iochannels.items():
            if mv.name not in iochannels: iochannels[mv.name] = mv
            if mv.name not in iochannels_alias: iochannels_alias[mv.name] = []
            iochannels_alias[mv.name].append( mk )
        for mk, mv in self.coram_ioregisters.items():
            if mv.name not in ioregisters: ioregisters[mv.name] = mv
            if mv.name not in ioregisters_alias: ioregisters_alias[mv.name] = []
            ioregisters_alias[mv.name].append( mk )

        print("----------------------------------------")
        print("CoRAM Objects in Control-Thread '%s', # FSM = %d" %
              (self.thread_name, self.getFsmCount()))

        if len(memories) > 0:
            print('  CoRAM CoramMemory:')
        for mk, mv in sorted(memories.items(), key=lambda x:int(str(x[1].idx))):
            slist = ['    ', str(mv), ' alias:']
            for a in memories_alias[mk]:
                slist.append(' ')
                slist.append(a)
            print(''.join(slist))

        if len(instreams) > 0:
            print('  CoRAM CoramInStream:')
        for mk, mv in sorted(instreams.items(), key=lambda x:int(str(x[1].idx))):
            slist = ['    ', str(mv), ' alias:']
            for a in instreams_alias[mk]:
                slist.append(' ')
                slist.append(a)
            print(''.join(slist))

        if len(outstreams) > 0:
            print('  CoRAM CoramOutstream:')
        for mk, mv in sorted(outstreams.items(), key=lambda x:int(str(x[1].idx))):
            slist = ['    ', str(mv), ' alias:']
            for a in outstreams_alias[mk]:
                slist.append(' ')
                slist.append(a)
            print(''.join(slist))

        if len(channels) > 0:
            print('  CoRAM CoramChannel:')
        for mk, mv in sorted(channels.items(), key=lambda x:int(str(x[1].idx))):
            slist = ['    ', str(mv), ' alias:']
            for a in channels_alias[mk]:
                slist.append(' ')
                slist.append(a)
            print(''.join(slist))

        if len(registers) > 0:
            print('  CoRAM CoramRegister:')
        for mk, mv in sorted(registers.items(), key=lambda x:int(str(x[1].idx))):
            slist = ['    ', str(mv), ' alias:']
            for a in registers_alias[mk]:
                slist.append(' ')
                slist.append(a)
            print(''.join(slist))

        if len(iochannels) > 0:
            print('  CoRAM CoramIoChannel:')
        for mk, mv in sorted(iochannels.items(), key=lambda x:int(str(x[1].idx))):
            slist = ['    ', str(mv), ' alias:']
            for a in iochannels_alias[mk]:
                slist.append(' ')
                slist.append(a)
            print(''.join(slist))

        if len(ioregisters) > 0:
            print('  CoRAM CoramIoRegister:')
        for mk, mv in sorted(ioregisters.items(), key=lambda x:int(str(x[1].idx))):
            slist = ['    ', str(mv), ' alias:']
            for a in ioregisters_alias[mk]:
                slist.append(' ')
                slist.append(a)
            print(''.join(slist))

    def getStatus(self):
        return (self.coram_memories,
                self.coram_instreams, self.coram_outstreams,
                self.coram_channels, self.coram_registers,
                self.coram_iochannels, self.coram_ioregisters,
                self.scope, self.fsm)

    #-------------------------------------------------------------------------
    def visit_Import(self, node):
        for alias in node.names:
            if alias.name in self.import_list:
                raise NameError("module %s is already imported." % alias.name)
            self.import_list[alias.name] = (alias.asname 
                                            if alias.asname is not None 
                                            else alias.name)
            if alias.name != 'coram':
                print("Warning: importing module '%s' is ignored." % alias.name)

    def visit_ImportFrom(self, node):
        if node.module not in self.importfrom_list:
            self.importfrom_list[node.module] = []
        for alias in node.names:
            if alias.name in self.importfrom_list[node.module]:
                raise NameError("module %s is already imported." % alias.name)
            self.importfrom_list[node.module].append(alias.asname 
                                                     if alias.asname is not None 
                                                     else alias.name)
            if node.module != 'coram':
                print("Warning: importing from module '%s' is ignored." % node.module)

    #-------------------------------------------------------------------------
    def visit_ClassDef(self, node):
        raise TypeError("class definition is not supported.")

    #-------------------------------------------------------------------------
    def visit_FunctionDef(self, node):
        self.scope.addFunction(node)
            
    def visit_Assign(self, node):
        if self.skip(): return
        right = self.visit(node.value)
        left = self.visit(node.targets[0])
        self.setBind(left, right)
        if isinstance(right, vast.Node):
            self.setFsm()
            self.incFsmCount()

    def visit_AugAssign(self, node):
        if self.skip(): return
        right = self.visit(node.value)
        left = self.visit(node.target)
        op = voperator.getVerilogOperator(node.op)
        if op is None: raise TypeError("Unsupported BinOp: %s" % str(node.op))
        rslt = op( left, right )
        self.setBind(left, rslt)
        if isinstance(right, vast.Node):
            self.setFsm()
            self.incFsmCount()

    def visit_IfExp(self, node):
        test = self.visit(node.test) # if condition
        body = self.visit(node.body)
        orelse = self.visit(node.orelse)
        rslt = vast.Cond(test, body, orelse)
        return rslt
        
    def visit_If(self, node):
        if self.skip(): return
        test = self.visit(node.test) # if condition

        cur_count = self.getFsmCount()
        self.incFsmCount()
        true_count = self.getFsmCount()

        self.pushScope()

        for b in node.body: # true statement
            self.visit(b)

        self.popScope()

        mid_count = self.getFsmCount()

        if len(node.orelse) == 0:
            self.setFsm(cur_count, true_count, test, mid_count)
            return

        self.incFsmCount()
        false_count = self.getFsmCount()

        self.pushScope()

        for b in node.orelse: # false statement
            self.visit(b)

        self.popScope()

        end_count = self.getFsmCount()
        self.setFsm(cur_count, true_count, test, false_count)
        self.setFsm(mid_count, end_count)

    def visit_While(self, node):
        if self.skip(): return

        # loop condition
        test = self.visit(node.test)

        begin_count = self.getFsmCount()
        self.incFsmCount()
        body_begin_count = self.getFsmCount()

        self.pushScope()

        for b in node.body:
            self.visit(b)

        self.popScope()

        body_end_count = self.getFsmCount()
        self.incFsmCount()
        loop_exit_count = self.getFsmCount()

        self.setFsm(begin_count, body_begin_count, test, loop_exit_count)
        self.setFsm(body_end_count, begin_count)

        unresolved_break = self.getUnresolvedBreak()
        for b in unresolved_break:
            self.setFsm(b, loop_exit_count)

        unresolved_continue = self.getUnresolvedContinue()
        for c in unresolved_continue:
            self.setFsm(c, begin_count)

        self.clearBreak()
        self.clearContinue()

        self.setFsmLoop(begin_count, body_end_count)

    def visit_For(self, node):
        if self.skip(): return
        if (isinstance(node.iter, ast.Call) and 
            isinstance(node.iter.func, ast.Name) and 
            node.iter.func.id == 'range'):
            # typical for-loop

            if len(node.iter.args) == 0: raise TypeError()
            begin_node = vast.IntConst('0') if len(node.iter.args) == 1 else self.visit(node.iter.args[0])
            end_node = self.visit(node.iter.args[0]) if len(node.iter.args) == 1 else self.visit(node.iter.args[1])
            step_node = vast.IntConst('1') if len(node.iter.args) < 3 else self.visit(node.iter.args[2])
            iter_node = self.visit(node.target)
            cond_node = vast.LessThan(iter_node, end_node)
            update_node = vast.Plus(iter_node, step_node)

            self.pushScope()
            
            # initialize
            self.setBind(iter_node, begin_node)
            self.setFsm()
            self.incFsmCount()

            # condition check
            check_count = self.getFsmCount()
            self.incFsmCount()
            body_begin_count = self.getFsmCount()

            for b in node.body:
                self.visit(b)

            self.popScope()

            body_end_count = self.getFsmCount()

            # update
            self.setBind(iter_node, update_node)
            self.incFsmCount()
            loop_exit_count = self.getFsmCount()

            self.setFsm(body_end_count, check_count)
            self.setFsm(check_count, body_begin_count, cond_node, loop_exit_count)

            unresolved_break = self.getUnresolvedBreak()
            for b in unresolved_break:
                self.setFsm(b, loop_exit_count)

            unresolved_continue = self.getUnresolvedContinue()
            for c in unresolved_continue:
                self.setFsm(c, body_end_count)
            
            self.clearBreak()
            self.clearContinue()

            self.setFsmLoop(check_count, body_end_count, iter_node, step_node)

    #--------------------------------------------------------------------------
    def visit_Call(self, node):
        if self.skip(): return

        if isinstance(node.func, ast.Name):
            return self._call_Name(node)

        if isinstance(node.func, ast.Attribute):
            return self._call_Attribute(node)

        raise NameError("function '%s' is not defined" % name)

    #--------------------------------------------------------------------------
    def _call_Name(self, node):
        name = node.func.id
        # search coram module
        if (name == CORAM_MEMORY or 
            name == CORAM_INSTREAM or name == CORAM_OUTSTREAM or 
            name == CORAM_CHANNEL or name == CORAM_REGISTER or
            name == CORAM_IOCHANNEL or name == CORAM_IOREGISTER):
            return self._call_Name_coram_module(node, name)

        # system task 
        if name == 'print': #($display)
            return self._call_Name_print(node)
        if name == 'int':
            return self._call_Name_int(node)

        # function call
        return self._call_Name_function(node, name)

    def _call_Name_coram_module(self, node, name):
        args = []
        keywords = []
        for i, arg in enumerate(node.args):
            args.append( self.visit(arg) )
        for key in node.keywords:
            keywords.append( self.visit(key.value) )

        instargs = {
            'idx' : None,
            'datawidth' : vast.IntConst('32'),
            'size' : vast.IntConst('16') if name == CORAM_CHANNEL or name == CORAM_IOCHANNEL else vast.IntConst('1024'),
            'length' : vast.IntConst('1') if name == CORAM_MEMORY else None,
            'scattergather' : vast.IntConst('0') if name == CORAM_MEMORY else None,
            }
        instargs_key = ('idx', 'datawidth', 'size', 'length', 'scattergather')

        for i, arg in enumerate(args):
            instargs[instargs_key[i]] = arg

        for i, key in enumerate(node.keywords):
            instargs[key.arg] = keywords[i]

        if name != CORAM_MEMORY and instargs['length'] is not None:
            raise TypeError("Non CoramMemory instances can not receive 'length' argument")
        if name != CORAM_MEMORY and instargs['scattergather'] is not None:
            raise TypeError("Non CoramMemory instances can not receive 'scattergather' argument")

        if name == CORAM_MEMORY:
            return CoramMemory(**instargs)
        if name == CORAM_INSTREAM:
            return CoramInStream(**instargs)
        if name == CORAM_OUTSTREAM:
            return CoramOutStream(**instargs)
        if name == CORAM_CHANNEL:
            return CoramChannel(**instargs)
        if name == CORAM_REGISTER:
            return CoramRegister(**instargs)
        if name == CORAM_IOCHANNEL:
            return CoramIoChannel(**instargs)
        if name == CORAM_IOREGISTER:
            return CoramIoRegister(**instargs)
        raise TypeError()

    def _call_Name_print(self, node):
        # prepare the argument values
        argvalues = []
        formatstring_list = [] 
        for arg in node.args:
            if isinstance(arg, ast.BinOp) and isinstance(arg.op, ast.Mod) and isinstance(arg.left, ast.Str):
                # format string in print statement
                values, form = self._print_binop_mod(arg)
                argvalues.extend( values )
                formatstring_list.append( form )
                formatstring_list.append(" ")
            else:
                value = self.visit(arg)
                if isinstance(value, vast.StringConst):
                    formatstring_list.append(value.value)
                    formatstring_list.append(" ")
                else:
                    argvalues.append( value )
                    formatstring_list.append("%d")
                    formatstring_list.append(" ")

        formatstring_list = formatstring_list[:-1]

        args = []
        args.append( vast.StringConst(''.join(formatstring_list)) )
        args.extend( argvalues )

        left = None
        right = vast.SystemCall('display', tuple(args))
        self.setBind(left, right)
        return right

    def _print_binop_mod(self, arg):
        values = []
        if isinstance(arg.right, ast.Tuple) or isinstance(arg.right, ast.List):
            for e in arg.right.elts:
                values.append( self.visit(e) )
        else:
            values.append( self.visit(arg.right) )
        form = arg.left.s
        return values, form

    def _call_Name_int(self, node):
        if len(node.args) > 1:
            raise TypeError("Too much arguments for 'int()'")
        argvalues = []
        for arg in node.args:
            argvalues.append( self.visit(arg) )
        return argvalues[0]

    def _call_Name_function(self, node, name):
        tree = self.getFunction(name)
        if tree is None:
            raise NameError("function '%s' is not defined" % name)

        # prepare the argument values
        args = []
        keywords = []
        for arg in node.args:
            args.append( self.visit(arg) )
        for key in node.keywords:
            keywords.append( self.visit(key.value) )

        # stack a new scope frame
        self.pushScope(ftype='call')

        # node.args -> variable and binding
        for pos, arg in enumerate(node.args):
            baseobj = tree.args.args[pos]
            argname = baseobj.id if isinstance(baseobj, ast.Name) else baseobj.arg
            left = vast.Identifier(self.getVariable(argname, store=True))
            right = args[pos]
            self.setBind(left, right)

        for pos, key in enumerate(node.keywords):
            left = vast.Identifier(self.getVariable(key.arg, store=True))
            right = keywords[pos]
            self.setBind(left, right)

        self.setFsm()
        self.incFsmCount()
   
        # visit the function definition
        ret = self.__visit_FunctionDef(tree)

        # fsm jump by return statement
        end_count = self.getFsmCount()
        unresolved_return = self.getUnresolvedReturn()
        for ret_count, value in unresolved_return:
            self.setFsm(ret_count, end_count)

        # clean-up jump conditions
        self.clearBreak()
        self.clearContinue()
        self.clearReturn()
        self.clearReturnVariable()

        # return to the previous scope frame
        self.popScope()

        return ret 

    def __visit_FunctionDef(self, node):
        self.generic_visit(node)
        retvar = self.getReturnVariable()
        if retvar is not None:
            return vast.Identifier(retvar)
        return vast.IntConst('0')

    def _coram_command(self, node):
        objname = self.getVariable(node.func.value.id)
        targ = self.getCoramMemory(objname)
        if targ is not None:
            return self._coram_memory_command(node, objname, targ)
        targ = self.getCoramInStream(objname)
        if targ is not None:
            return self._coram_instream_command(node, objname, targ)
        targ = self.getCoramOutStream(objname)
        if targ is not None:
            return self._coram_outstream_command(node, objname, targ)
        targ = self.getCoramChannel(objname)
        if targ is not None:
            return self._coram_channel_command(node, objname, targ)
        targ = self.getCoramRegister(objname)
        if targ is not None:
            return self._coram_register_command(node, objname, targ)
        targ = self.getCoramIoChannel(objname)
        if targ is not None:
            return self._coram_iochannel_command(node, objname, targ)
        targ = self.getCoramIoRegister(objname)
        if targ is not None:
            return self._coram_ioregister_command(node, objname, targ)
        raise NameError("Can not find a CoRAM object: %s" % objname)

    def _coram_memory_command(self, node, objname, targ):
        mode = node.func.attr
        if mode == 'read':
            return self._coram_memory_read(node, objname, targ)
        if mode == 'write':
            return self._coram_memory_write(node, objname, targ)
        if mode == 'read_nonblocking':
            return self._coram_memory_read_nonblocking(node, objname, targ)
        if mode == 'write_nonblocking':
            return self._coram_memory_write_nonblocking(node, objname, targ)
        if mode == 'wait':
            return self._coram_memory_wait(node, objname, targ)
        if mode == 'test':
            return self._coram_memory_test(node, objname, targ)
        raise NameError("CoRAM memory command '%s' is not defined" % mode )

    def _coram_instream_command(self, node, objname, targ):
        mode = node.func.attr
        if mode == 'write':
            return self._coram_instream_write(node, objname, targ)
        if mode == 'write_nonblocking':
            return self._coram_instream_write_nonblocking(node, objname, targ)
        if mode == 'wait':
            return self._coram_instream_wait(node, objname, targ)
        if mode == 'test':
            return self._coram_instream_test(node, objname, targ)
        raise NameError("CoRAM input stream command '%s' is not defined" % mode )

    def _coram_outstream_command(self, node, objname, targ):
        mode = node.func.attr
        if mode == 'read':
            return self._coram_outstream_read(node, objname, targ)
        if mode == 'read_nonblocking':
            return self._coram_outstream_read_nonblocking(node, objname, targ)
        if mode == 'wait':
            return self._coram_outstream_wait(node, objname, targ)
        if mode == 'test':
            return self._coram_outstream_test(node, objname, targ)
        raise NameError("CoRAM output stream command '%s' is not defined" % mode )

    def _coram_channel_command(self, node, objname, targ):
        mode = node.func.attr
        if mode == 'read':
            return self._coram_channel_read(node, objname, targ)
        if mode == 'write':
            return self._coram_channel_write(node, objname, targ)
        raise NameError("CoRAM channel command '%s' is not defined" % mode )

    def _coram_register_command(self, node, objname, targ):
        mode = node.func.attr
        if mode == 'read':
            return self._coram_register_read(node, objname, targ)
        if mode == 'write':
            return self._coram_register_write(node, objname, targ)
        raise NameError("CoRAM register command '%s' is not defined" % mode )

    def _coram_iochannel_command(self, node, objname, targ):
        mode = node.func.attr
        if mode == 'read':
            return self._coram_iochannel_read(node, objname, targ)
        if mode == 'write':
            return self._coram_iochannel_write(node, objname, targ)
        raise NameError("CoRAM I/O channel command '%s' is not defined" % mode )

    def _coram_ioregister_command(self, node, objname, targ):
        mode = node.func.attr
        if mode == 'read':
            return self._coram_ioregister_read(node, objname, targ)
        if mode == 'write':
            return self._coram_ioregister_write(node, objname, targ)
        raise NameError("CoRAM I/O register command '%s' is not defined" % mode )

    #--------------------------------------------------------------------------
    def _call_Attribute(self, node):
        attr_value = self.visit(node.func.value)
        if isinstance(attr_value, CoramBase):
            return self._coram_command(node)
        raise NameError("attribute '%s' is not CoRAM object" % str(ast.dump(node.func)))

    #--------------------------------------------------------------------------
    def _coram_memory_read(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_memory_read', tuple(args))
        self.setBind(left, right)

        # arguments
        ext_addr = args[2]
        core_addr = args[1]
        size = args[3]
        self.setBind(vast.Identifier(targ.name+'_ext_addr'), ext_addr)
        self.setBind(vast.Identifier(targ.name+'_core_addr'), core_addr)
        self.setBind(vast.Identifier(targ.name+'_word_size'), size)

        # assert DMA read request (from BlockRAM to DRAM)
        self.setBind(vast.Identifier(targ.name+'_read_enable'), vast.IntConst('1'),
                     vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1')))

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        # de-assert DMA read request
        self.setBind(vast.Identifier(targ.name+'_read_enable'), vast.IntConst('0'))

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('0'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()
        
        return vast.IntConst('0')

    def _coram_memory_write(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_memory_write', tuple(args))
        self.setBind(left, right)

        # arguments
        ext_addr = args[2]
        core_addr = args[1]
        size = args[3]
        self.setBind(vast.Identifier(targ.name+'_ext_addr'), ext_addr)
        self.setBind(vast.Identifier(targ.name+'_core_addr'), core_addr)
        self.setBind(vast.Identifier(targ.name+'_word_size'), size)

        # assert DMA write request (from DRAM to BlockRAM)
        self.setBind(vast.Identifier(targ.name+'_write_enable'), vast.IntConst('1'),
                     vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1')))

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        # de-assert DMA write request
        self.setBind(vast.Identifier(targ.name+'_write_enable'), vast.IntConst('0'))

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('0'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        return vast.IntConst('0')

    def _coram_memory_read_nonblocking(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_memory_read_nonblocking', tuple(args))
        self.setBind(left, right)

        # arguments
        ext_addr = args[2]
        core_addr = args[1]
        size = args[3]
        self.setBind(vast.Identifier(targ.name+'_ext_addr'), ext_addr)
        self.setBind(vast.Identifier(targ.name+'_core_addr'), core_addr)
        self.setBind(vast.Identifier(targ.name+'_word_size'), size)

        # assert DMA read request (from BlockRAM to DRAM)
        self.setBind(vast.Identifier(targ.name+'_read_enable'), vast.IntConst('1'),
                     vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1')))

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        # de-assert DMA read request
        self.setBind(vast.Identifier(targ.name+'_read_enable'), vast.IntConst('0'))

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        return vast.IntConst('0')

    def _coram_memory_write_nonblocking(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_memory_write_nonblocking', tuple(args))
        self.setBind(left, right)

        # arguments
        ext_addr = args[2]
        core_addr = args[1]
        size = args[3]
        self.setBind(vast.Identifier(targ.name+'_ext_addr'), ext_addr)
        self.setBind(vast.Identifier(targ.name+'_core_addr'), core_addr)
        self.setBind(vast.Identifier(targ.name+'_word_size'), size)

        # assert DMA write request (from DRAM to BlockRAM)
        self.setBind(vast.Identifier(targ.name+'_write_enable'), vast.IntConst('1'),
                     vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1')))

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()
        
        # de-assert DMA write request
        self.setBind(vast.Identifier(targ.name+'_write_enable'), vast.IntConst('0'))

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        return vast.IntConst('0')

    def _coram_memory_wait(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_memory_wait', tuple(args))
        self.setBind(left, right)

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('0'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()
        
        return vast.IntConst('0')

    def _coram_memory_test(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_memory_test', tuple(args))
        self.setBind(left, right)

        # read test value
        tmp = self.getTmpVariable() 
        cond_ret = vast.Identifier(tmp)
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('0'))
        self.setBind(cond_ret, cond)

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count)
        self.incFsmCount()
        
        return cond_ret

    #--------------------------------------------------------------------------
    def _coram_instream_write(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_instream_write', tuple(args))
        self.setBind(left, right)

        # arguments
        ext_addr = args[1]
        size = args[2]
        self.setBind(vast.Identifier(targ.name+'_ext_addr'), ext_addr)
        self.setBind(vast.Identifier(targ.name+'_word_size'), size)

        # assert DMA write request (from DRAM to BlockRAM)
        self.setBind(vast.Identifier(targ.name+'_write_enable'), vast.IntConst('1'),
                     vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1')))
        
        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        # de-assert DMA write request
        self.setBind(vast.Identifier(targ.name+'_write_enable'), vast.IntConst('0'))

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('0'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        return vast.IntConst('0')

    def _coram_instream_write_nonblocking(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_instream_write_nonblocking', tuple(args))
        self.setBind(left, right)

        # arguments
        ext_addr = args[1]
        size = args[2]
        self.setBind(vast.Identifier(targ.name+'_ext_addr'), ext_addr)
        self.setBind(vast.Identifier(targ.name+'_word_size'), size)

        # assert DMA write request (from DRAM to BlockRAM)
        self.setBind(vast.Identifier(targ.name+'_write_enable'), vast.IntConst('1'),
                     vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1')))

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()
        
        # de-assert DMA write request
        self.setBind(vast.Identifier(targ.name+'_write_enable'), vast.IntConst('0'))

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        return vast.IntConst('0')

    def _coram_instream_wait(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_instream_wait', tuple(args))
        self.setBind(left, right)

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('0'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()
        
        return vast.IntConst('0')

    def _coram_instream_test(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_instream_test', tuple(args))
        self.setBind(left, right)

        # read test value
        tmp = self.getTmpVariable() 
        cond_ret = vast.Identifier(tmp)
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('0'))
        self.setBind(cond_ret, cond)

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count)
        self.incFsmCount()
        
        return cond_ret

    #--------------------------------------------------------------------------
    def _coram_outstream_read(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_outstream_read', tuple(args))
        self.setBind(left, right)

        # arguments
        ext_addr = args[1]
        size = args[2]
        self.setBind(vast.Identifier(targ.name+'_ext_addr'), ext_addr)
        self.setBind(vast.Identifier(targ.name+'_word_size'), size)

        # assert DMA read request (from BlockRAM to DRAM)
        self.setBind(vast.Identifier(targ.name+'_read_enable'), vast.IntConst('1'),
                     vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1')))

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        # de-assert DMA read request
        self.setBind(vast.Identifier(targ.name+'_read_enable'), vast.IntConst('0'))
        
        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('0'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()
        
        return vast.IntConst('0')

    def _coram_outstream_read_nonblocking(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_outstream_read_nonblocking', tuple(args))
        self.setBind(left, right)

        # arguments
        ext_addr = args[1]
        size = args[2]
        self.setBind(vast.Identifier(targ.name+'_ext_addr'), ext_addr)
        self.setBind(vast.Identifier(targ.name+'_word_size'), size)

        # assert DMA read request (from BlockRAM to DRAM)
        self.setBind(vast.Identifier(targ.name+'_read_enable'), vast.IntConst('1'),
                     vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1')))

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_ready'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        # de-assert DMA read request
        self.setBind(vast.Identifier(targ.name+'_read_enable'), vast.IntConst('0'))

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('1'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        return vast.IntConst('0')

    def _coram_outstream_wait(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_outstream_wait', tuple(args))
        self.setBind(left, right)

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('0'))
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()
        
        return vast.IntConst('0')

    def _coram_outstream_test(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_outstream_test', tuple(args))
        self.setBind(left, right)

        # read test value
        tmp = self.getTmpVariable() 
        cond_ret = vast.Identifier(tmp)
        cond = vast.Eq(vast.Identifier(targ.name+'_busy'), vast.IntConst('0'))
        self.setBind(cond_ret, cond)

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count)
        self.incFsmCount()
        
        return cond_ret

    #--------------------------------------------------------------------------
    def _coram_channel_read(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_channel_read', tuple(args))
        self.setBind(left, right)

        # assert dequeue line
        cond = vast.Eq(vast.Identifier(targ.name + '_empty'), vast.IntConst('0'))
        channel_deq = vast.Identifier(targ.name + '_deq')
        channel_deq_val = cond
        self.setBind(channel_deq, channel_deq_val)
        
        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        # read from channel
        tmp = self.getTmpVariable() 
        channel_q_ret = vast.Identifier(tmp)
        channel_q = vast.Identifier(targ.name + '_q')
        self.setBind(channel_q_ret, channel_q)

        # de-assert dequeue line
        channel_deq_val = vast.IntConst('0')
        self.setBind(channel_deq, channel_deq_val)

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        return channel_q_ret

    def _coram_channel_write(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_channel_write', tuple(args))
        self.setBind(left, right)

        # write data to channel
        channel_d = vast.Identifier(targ.name + '_d')
        channel_d_val = args[1]
        self.setBind(channel_d, channel_d_val)
        
        # assert enqueue line
        cond = vast.Eq(vast.Identifier(targ.name + '_almost_full'), vast.IntConst('0'))
        channel_enq = vast.Identifier(targ.name + '_enq')
        channel_enq_val = cond
        self.setBind(channel_enq, channel_enq_val)

        # go to next
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        # de-assert enqueue line
        channel_enq_val = vast.IntConst('0')
        self.setBind(channel_enq, channel_enq_val)

        return vast.IntConst('0')

    #--------------------------------------------------------------------------
    def _coram_register_read(self, node, objname, targ):
        # read from register
        tmp = self.getTmpVariable() 
        register_q_ret = vast.Identifier(tmp)
        register_q = vast.Identifier(targ.name + '_q')
        self.setBind(register_q_ret, register_q)

        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        args.append(register_q_ret)
        right = vast.SystemCall('coram_register_read', tuple(args))
        self.setBind(left, right)

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count)
        self.incFsmCount()

        return register_q_ret

    def _coram_register_write(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_register_write', tuple(args))
        self.setBind(left, right)

        # write data to register
        register_d = vast.Identifier(targ.name + '_d')
        register_d_val = args[1]
        self.setBind(register_d, register_d_val)
        
        # assert enable line
        register_we = vast.Identifier(targ.name + '_we')
        register_we_val = vast.IntConst('1')
        self.setBind(register_we, register_we_val)

        # go to next
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count)
        self.incFsmCount()

        # de-assert enable line
        register_we_val = vast.IntConst('0')
        self.setBind(register_we, register_we_val)

        # go to next (2)
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count)
        self.incFsmCount()

        return vast.IntConst('0')

    #--------------------------------------------------------------------------
    def _coram_iochannel_read(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_iochannel_read', tuple(args))
        self.setBind(left, right)

        # assert dequeue line
        cond = vast.Eq(vast.Identifier(targ.name + '_empty'), vast.IntConst('0'))
        iochannel_deq = vast.Identifier(targ.name + '_deq')
        iochannel_deq_val = cond
        self.setBind(iochannel_deq, iochannel_deq_val)
        
        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        # read from iochannel
        tmp = self.getTmpVariable() 
        iochannel_q_ret = vast.Identifier(tmp)
        iochannel_q = vast.Identifier(targ.name + '_q')
        self.setBind(iochannel_q_ret, iochannel_q)

        # de-assert dequeue line
        iochannel_deq_val = vast.IntConst('0')
        self.setBind(iochannel_deq, iochannel_deq_val)

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        return iochannel_q_ret

    def _coram_iochannel_write(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_iochannel_write', tuple(args))
        self.setBind(left, right)

        # write data to iochannel
        iochannel_d = vast.Identifier(targ.name + '_d')
        iochannel_d_val = args[1]
        self.setBind(iochannel_d, iochannel_d_val)
        
        # assert enqueue line
        cond = vast.Eq(vast.Identifier(targ.name + '_almost_full'), vast.IntConst('0'))
        iochannel_enq = vast.Identifier(targ.name + '_enq')
        iochannel_enq_val = cond
        self.setBind(iochannel_enq, iochannel_enq_val)

        # go to next
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count, cond, src_count)
        self.incFsmCount()

        # de-assert enqueue line
        iochannel_enq_val = vast.IntConst('0')
        self.setBind(iochannel_enq, iochannel_enq_val)

        return vast.IntConst('0')

    #--------------------------------------------------------------------------
    def _coram_ioregister_read(self, node, objname, targ):
        # read from ioregister
        tmp = self.getTmpVariable() 
        ioregister_q_ret = vast.Identifier(tmp)
        ioregister_q = vast.Identifier(targ.name + '_q')
        self.setBind(ioregister_q_ret, ioregister_q)

        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        args.append(ioregister_q_ret)
        right = vast.SystemCall('coram_ioregister_read', tuple(args))
        self.setBind(left, right)

        # go to next state
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count)
        self.incFsmCount()

        return ioregister_q_ret

    def _coram_ioregister_write(self, node, objname, targ):
        # dummy system call
        left = None
        args = [ vast.Identifier(targ.name) ]
        for a in node.args:
            args.append(self.visit(a))
        right = vast.SystemCall('coram_ioregister_write', tuple(args))
        self.setBind(left, right)

        # write data to ioregister
        ioregister_d = vast.Identifier(targ.name + '_d')
        ioregister_d_val = args[1]
        self.setBind(ioregister_d, ioregister_d_val)
        
        # assert enable line
        ioregister_we = vast.Identifier(targ.name + '_we')
        ioregister_we_val = vast.IntConst('1')
        self.setBind(ioregister_we, ioregister_we_val)

        # go to next
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count)
        self.incFsmCount()

        # de-assert enable line
        ioregister_we_val = vast.IntConst('0')
        self.setBind(ioregister_we, ioregister_we_val)

        # go to next (2)
        src_count = self.getFsmCount()
        dst_count = src_count + 1
        self.setFsm(src_count, dst_count)
        self.incFsmCount()

        return vast.IntConst('0')

    #--------------------------------------------------------------------------
    def visit_Nonlocal(self, node):
        for name in node.names:
            self.addNonlocal(name)

    def visit_Global(self, node):
        for name in node.names:
            self.addGlobal(name)

    def visit_Pass(self, node):
        pass

    def visit_Break(self, node):
        self.addBreak()
        self.incFsmCount()

    def visit_Continue(self, node):
        self.addContinue()
        self.incFsmCount()

    def visit_Return(self, node):
        if node.value is None:
            self.addReturn(None)
            self.incFsmCount()
            return None

        retvar = self.getReturnVariable()
        if retvar is not None:
            left = vast.Identifier(retvar)
            right = self.visit(node.value)
            self.setBind(left, right)
            self.addReturn(right)
            self.incFsmCount()
            return left

        tmp = self.getTmpVariable()
        self.setReturnVariable(tmp)
        left = vast.Identifier(tmp)
        right = self.visit(node.value)
        self.setBind(left, right)
        self.addReturn(right)
        self.incFsmCount()
        return left

    def visit_Num(self, node):
        if isinstance(node.n, int):
            return vast.IntConst(str(node.n))
        return vast.Constant(str(node.n))

    def visit_Str(self, node):
        return vast.StringConst(node.s)

    def visit_UnaryOp(self, node):
        op = voperator.getVerilogOperator(node.op)
        value = self.visit(node.operand)
        rslt = op( value )
        return self.optimize(rslt)

    def visit_BoolOp(self, node):
        op = voperator.getVerilogOperator(node.op)
        if op is None: raise TypeError("Unsupported BinOp: %s" % str(node.op))
        rslt = self.visit(node.values[0])
        for v in node.values[1:]:
            rslt = op( rslt, self.visit(v) )
        return self.optimize(rslt)

    def visit_BinOp(self, node):
        left = self.visit(node.left)
        right = self.visit(node.right)
        op = voperator.getVerilogOperator(node.op)
        if op is None: raise TypeError("Unsupported BinOp: %s" % str(node.op))
        if isinstance(left, vast.StringConst) or isinstance(right, vast.StringConst):
            if op == vast.Plus:
                return self._string_operation_plus(left, right)
            raise TypeError("Can not generate a corresponding node")
        rslt = op( left, right )
        return self.optimize(rslt)

    def _string_operation_plus(self, left, right):
        if not isinstance(left, vast.StringConst) or not isinstance(right, vast.StringConst):
            raise TypeError("'+' operation requires two string arguments")
        return vast.StrintConst(left.value + right.value)

    def visit_Compare(self, node):
        left = self.visit(node.left)
        ops = [ voperator.getVerilogOperator(op) for op in node.ops ]
        comparators = [ self.visit(comp) for comp in node.comparators ]
        rslts = []
        for i, op in enumerate(ops):
            if i == 0:
                rslts.append( op(left, comparators[i]) )
            else:
                rslts.append( op(comparators[i-1], comparators[i]) )
        if len(rslts) == 1:
            return rslts[0]
        ret = None
        for r in rslts:
            if ret:
                ret = vast.Land(ret, r)
            else:
                ret = r
        return ret

    def visit_NameConstant(self, node):
        # for Python 3.4
        if node.value == True:
            return vast.IntConst('1')
        if node.value == False:
            return vast.IntConst('0')
        if node.value == None:
            return vast.IntConst('0')
        raise TypeError("%s in NameConst.value is not supported." % str(node.value))

    def visit_Name(self, node):
        # for Python 3.3 or older
        if node.id == 'True':
            return vast.IntConst('1')
        if node.id == 'False':
            return vast.IntConst('0')
        if node.id == 'None':
            return vast.IntConst('0')
        store = isinstance(node.ctx, ast.Store)
        name = self.getVariable(node.id, store)
        targ = self.getCoramObject(name)
        if targ is not None:
            if store:
                raise TypeError(("CoRAM object variable should not be "
                                 "overwritten on the current implementation."))
            return targ
        targ = self.getObject(name)
        if targ is not None:
            if store:
                raise TypeError(("Class object variable should not be "
                                 "overwritten on the current implementation."))
            return targ
        return vast.Identifier(name)

    def visit_Print(self, node):
        # for Python 2.x
        # prepare the argument values
        argvalues = []
        formatstring_list = []
        for arg in node.values:
            if isinstance(arg, ast.BinOp) and isinstance(arg.op, ast.Mod) and isinstance(arg.left, ast.Str):
                # format string in print statement
                values, form = self._print_binop_mod(arg)
                argvalues.extend( values )
                formatstring_list.append( form )
                formatstring_list.append(" ")
            elif isinstance(arg, ast.Tuple):
                for e in arg.elts:
                    value = self.visit(e)
                    if isinstance(value, vast.StringConst):
                        formatstring_list.append(value.value)
                        formatstring_list.append(" ")
                    else:
                        argvalues.append( value )
                        formatstring_list.append("%d")
                        formatstring_list.append(" ")
            else:
                value = self.visit(arg)
                if isinstance(value, vast.StringConst):
                    formatstring_list.append(value.value)
                    formatstring_list.append(" ")
                else:
                    argvalues.append( value )
                    formatstring_list.append("%d")
                    formatstring_list.append(" ")

        formatstring_list = formatstring_list[:-1]

        args = []
        args.append( vast.StringConst(''.join(formatstring_list)) )
        args.extend( argvalues )

        left = None
        right = vast.SystemCall('display', tuple(args))
        self.setBind(left, right)
        return right

    #-------------------------------------------------------------------------
    # support function
    #-------------------------------------------------------------------------
    def skip(self):
        val = self.hasBreak() or self.hasContinue() or self.hasReturn()
        return val

    def getVariable(self, name, store=False):
        var = self.scope.searchVariable(name, store)
        if var is None:
            if not store: raise NameError("name '%s' is not defined" % name)
            self.scope.addVariable(name)
            var = self.scope.searchVariable(name)
        return var

    def getTmpVariable(self):
        var = self.scope.addTmpVariable()
        return var

    def addNonlocal(self, name):
        self.scope.addNonlocal(name)

    def addGlobal(self, name):
        self.scope.addGlobal(name)

    def getFunction(self, name):
        func = self.scope.searchFunction(name)
        if func is None:
            raise NameError("function '%s' is not defined" % name)
        return func

    def setBind(self, var, value, cond=None):
        if isinstance(value, vast.Node):
            opt_value = self.optimize(value) if var is not None else value
            opt_cond = self.optimize(cond) if cond is not None and var is not None else None
            self.fsm.setBind(var, opt_value, cond=opt_cond)
            state = self.getFsmCount()
            vname = var.name if var is not None else None
            self.scope.addBind(state, vname, value, cond)
        else:
            if isinstance(value, CoramMemory):
                self.addCoramMemory(var, value)
            elif isinstance(value, CoramInStream):
                self.addCoramInStream(var, value)
            elif isinstance(value, CoramOutStream):
                self.addCoramOutStream(var, value)
            elif isinstance(value, CoramChannel):
                self.addCoramChannel(var, value)
            elif isinstance(value, CoramRegister):
                self.addCoramRegister(var, value)
            elif isinstance(value, CoramIoChannel):
                self.addCoramIoChannel(var, value)
            elif isinstance(value, CoramIoRegister):
                self.addCoramIoRegister(var, value)
            else:
                self.addObject(var, value)
            self.fsm.setObjectBind(var, value, cond=cond)

    #-------------------------------------------------------------------------
    def optimize(self, node):
        opt_dfnode = self.vopt.optimize(maketree.getDFTree(node))
        opt_node = maketree.makeASTTree(opt_dfnode)
        return opt_node

    #-------------------------------------------------------------------------
    def setFsm(self, src=None, dst=None, cond=None, elsedst=None):
        self.fsm.set(src, dst, cond, elsedst)

    def incFsmCount(self):
        self.fsm.incCount()

    def getFsmCount(self):
        return self.fsm.getCount()

    #-------------------------------------------------------------------------
    def setFsmLoop(self, begin, end, iter_node=None, step_node=None):
        self.fsm.setLoop(begin, end, iter_node, step_node)

    def getFsmLoops(self):
        return self.fsm.getLoops()
    
    def getFsmCandidateLoops(self, pos):
        return self.fsm.getCandidateLoops(pos)

    #-------------------------------------------------------------------------
    def getCurrentScope(self):
        return self.scope.getCurrent()

    def pushScope(self, name=None, ftype=None):
        self.scope.pushScopeFrame(name, ftype)

    def popScope(self):
        self.scope.popScopeFrame()

    #-------------------------------------------------------------------------
    def addBreak(self):
        count = self.getFsmCount()
        self.scope.addBreak(count)

    def addContinue(self):
        count = self.getFsmCount()
        self.scope.addContinue(count)

    def addReturn(self, value):
        count = self.getFsmCount()
        self.scope.addReturn(count, value)

    def hasBreak(self):
        return self.scope.hasBreak()

    def hasContinue(self):
        return self.scope.hasContinue()

    def hasReturn(self):
        return self.scope.hasReturn()

    def getUnresolvedBreak(self):
        return self.scope.getUnresolvedBreak()

    def getUnresolvedContinue(self):
        return self.scope.getUnresolvedContinue()

    def getUnresolvedReturn(self):
        return self.scope.getUnresolvedReturn()

    def setReturnVariable(self, var):
        self.scope.setReturnVariable(var)

    def getReturnVariable(self):
        return self.scope.getReturnVariable()

    def clearBreak(self):
        self.scope.clearBreak()

    def clearContinue(self):
        self.scope.clearContinue()

    def clearReturn(self):
        self.scope.clearReturn()

    def clearReturnVariable(self):
        self.scope.clearReturnVariable()

    #-------------------------------------------------------------------------
    def addCoramMemory(self, id, node):
        self.coram_memories[id.name] = node

    def addCoramInStream(self, id, node):
        self.coram_instreams[id.name] = node

    def addCoramOutStream(self, id, node):
        self.coram_outstreams[id.name] = node

    def addCoramChannel(self, id, node):
        self.coram_channels[id.name] = node

    def addCoramRegister(self, id, node):
        self.coram_registers[id.name] = node

    def addCoramIoChannel(self, id, node):
        self.coram_iochannels[id.name] = node

    def addCoramIoRegister(self, id, node):
        self.coram_ioregisters[id.name] = node

    def getCoramMemory(self, name):
        if name not in self.coram_memories: return None
        return self.coram_memories[name]

    def getCoramInStream(self, name):
        if name not in self.coram_instreams: return None
        return self.coram_instreams[name]

    def getCoramOutStream(self, name):
        if name not in self.coram_outstreams: return None
        return self.coram_outstreams[name]

    def getCoramChannel(self, name):
        if name not in self.coram_channels: return None
        return self.coram_channels[name]

    def getCoramRegister(self, name):
        if name not in self.coram_registers: return None
        return self.coram_registers[name]

    def getCoramIoChannel(self, name):
        if name not in self.coram_iochannels: return None
        return self.coram_iochannels[name]

    def getCoramIoRegister(self, name):
        if name not in self.coram_ioregisters: return None
        return self.coram_ioregisters[name]

    def getCoramObject(self, name):
        targ = self.getCoramMemory(name)
        if targ is not None:
            return targ
        targ = self.getCoramInStream(name)
        if targ is not None:
            return targ
        targ = self.getCoramOutStream(name)
        if targ is not None:
            return targ
        targ = self.getCoramChannel(name)
        if targ is not None:
            return targ
        targ = self.getCoramRegister(name)
        if targ is not None:
            return targ
        targ = self.getCoramIoChannel(name)
        if targ is not None:
            return targ
        targ = self.getCoramIoRegister(name)
        if targ is not None:
            return targ
        return None

    #-------------------------------------------------------------------------
    def addObject(self, id, node):
        self.objects[id.name] = node

    def getObject(self, name):
        if name not in self.objects: return None
        return self.objects[name]

    #-------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Generator Class
#-------------------------------------------------------------------------------
class ControlThreadGenerator(object):
    def __init__(self):
        self.status = {}

    def compile(self, thread_name,
                filename=None, func=None, function_lib=None,
                signalwidth=64, 
                ext_addrwidth=64,
                ext_max_datawidth=512,
                dump=False):
        if filename is not None and func is not None:
            raise IOError('Only filename or func should be defined.')

        source_src = []

        if func is not None and function_lib is not None:
            for name, global_func in function_lib.items():
                source_src.append( inspect.getsource(global_func) )

        if filename is not None:
            source_src.append( open(filename, 'r').read() )

        if ((func is not None and function_lib is None) or 
            (func is not None and
             function_lib is not None and 
             func.__name__ not in function_lib)):
            source_src.append( inspect.getsource(func) )

        if func is not None:
            source_src.append( func.__name__ + '()' )

        source = ''.join(source_src)

        tree = ast.parse(source)
        functionvisitor = FunctionVisitor()
        functionvisitor.visit(tree)
        functions = functionvisitor.getFunctions()

        compilevisitor = CompileVisitor(thread_name, functions, signalwidth)
        compilevisitor.visit(tree)

        (coram_memories, coram_instreams, coram_outstreams, 
         coram_channels, coram_registers,
         coram_iochannels, coram_ioregisters,
         scope, fsm) = compilevisitor.getStatus()

        self.status[thread_name] = ( tuple(set(coram_memories.values())),
                                     tuple(set(coram_instreams.values())),
                                     tuple(set(coram_outstreams.values())),
                                     tuple(set(coram_channels.values())),
                                     tuple(set(coram_registers.values())),
                                     tuple(set(coram_iochannels.values())),
                                     tuple(set(coram_ioregisters.values())),)
        codegen = CodeGenerator(thread_name, coram_memories,
                                coram_instreams, coram_outstreams,
                                coram_channels, coram_registers, 
                                coram_iochannels, coram_ioregisters, 
                                scope, fsm,
                                signalwidth=signalwidth, 
                                ext_addrwidth=ext_addrwidth,
                                ext_max_datawidth=ext_max_datawidth,
                                )
        #fsm.analysis()
        code = codegen.generate()

        if dump:
            compilevisitor.dump()

        return code

    def getStatus(self):
        return self.status

#-------------------------------------------------------------------------------
def main():
    from optparse import OptionParser
    INFO = "Python-to-Verilog Compiler for Control Thread Generation of PyCoRAM"
    VERSION = utils.version.VERSION
    USAGE = "Usage: python controlthread.py filelist"

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
