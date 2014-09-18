#-------------------------------------------------------------------------------
# maketree.py
#
# AST tree <-> Dataflow Tree converter
#
# Copyright (C) 2013, Shinya Takamaeda-Yamazaki
# License: Apache 2.0
#-------------------------------------------------------------------------------
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))) )
from pyverilog.vparser.ast import *
from pyverilog.dataflow.dataflow import *
from pyverilog.utils.scope import *
import pyverilog.dataflow.reorder as reorder
import pyverilog.utils.op2mark

def getDFTree(node):
    expr = node.var if isinstance(node, Rvalue) else node
    return makeDFTree(expr)

def makeDFTree(node):
    if isinstance(node, str):
        name = ScopeChain((ScopeLabel(node),))
        return DFTerminal(name)
    
    if isinstance(node, Identifier):
        name = ScopeChain((ScopeLabel(node.name),))
        return DFTerminal(name)

    if isinstance(node, IntConst):
        return DFIntConst(node.value)

    if isinstance(node, FloatConst):
        return DFFloatConst(node.value)

    if isinstance(node, StringConst):
        return DFStringConst(node.value)

    if isinstance(node, Cond):
        true_df = makeDFTree(node.true_value)
        false_df = makeDFTree(node.false_value)
        cond_df = makeDFTree(node.cond)
        if isinstance(cond_df, DFBranch):
            return reorder.insertCond(cond_df, true_df, false_df)
        return DFBranch(cond_df, true_df, false_df)

    if isinstance(node, UnaryOperator):
        right_df = makeDFTree(node.right)
        if isinstance(right_df, DFBranch):
            return reorder.insertUnaryOp(right_df, node.__class__.__name__)
        return DFOperator((right_df,), node.__class__.__name__)

    if isinstance(node, Operator):
        left_df = makeDFTree(node.left)
        right_df = makeDFTree(node.right)
        if isinstance(left_df, DFBranch) or isinstance(right_df, DFBranch):
            return reorder.insertOp(left_df, right_df, node.__class__.__name__)
        return DFOperator((left_df, right_df,), node.__class__.__name__)

    if isinstance(node, SystemCall):
        #if node.syscall == 'unsigned':
        #    return makeDFTree(node.args[0])
        #if node.syscall == 'signed':
        #    return makeDFTree(node.args[0])
        #return DFIntConst('0')
        return DFSyscall(node.syscall, tuple([ makeDFTree(n) for n in node.args ]))

    raise TypeError("unsupported AST node type: %s %s" % (str(type(node)), str(node)))

operators = {
    'Plus'         : Plus,
    'Minus'        : Minus,
    'Times'        : Times,
    'Divide'       : Divide,
    'Mod'          : Mod,
    'Power'        : Power,
    'Sll'          : Sll,
    'Srl'          : Srl,
    'Sra'          : Sra,
    'Or'           : Or,
    'Xor'          : Xor,
    'And'          : And,
    'Divide'       : Divide,
    'Land'         : Land,
    'Lor'          : Lor,
    'Unot'         : Unot,
    'Ulnot'        : Ulnot,
    'Uplus'        : Uplus,
    'Uminus'       : Uminus,
    'Eq'           : Eq,
    'NotEq'        : NotEq,
    'LessThan'     : LessThan,
    'LessEq'       : LessEq,
    'GreaterThan'  : GreaterThan,
    'GreaterEq'    : GreaterEq,
    'Eq'           : Eq,
    'NotEq'        : NotEq,        
    }

def getOp(op):
    return operators[op]

def makeASTTree(node):
    if isinstance(node, DFBranch):
        return Cond(makeASTTree(node.condnode), 
                    makeASTTree(node.truenode), 
                    makeASTTree(node.falsenode))

    if isinstance(node, DFIntConst):
        return IntConst(str(node.value))

    if isinstance(node, DFFloatConst):
        return FloatConst(str(node.value))
    
    if isinstance(node, DFStringConst):
        return StringConst(str(node.value))

    if isinstance(node, DFEvalValue):
        if isinstance(node.value, int):
            return IntConst(str(node.value))
        if isinstance(node.value, float):
            return FloatConst(str(node.value))
        if isinstance(node.value, DFStringConst):
            return StringConst(str(node.value))
        return Constant(str(node.value))

    if isinstance(node, DFTerminal):
        name = node.name[0].scopename
        return Identifier(name)
    
    if isinstance(node, DFUndefined):
        return IntConst('x')

    if isinstance(node, DFHighImpedance):
        return IntConst('z')

    if isinstance(node, DFOperator):
        if len(node.nextnodes) == 1:
            return getOp(node.operator)(makeASTTree(node.nextnodes[0]))
        return getOp(node.operator)(makeASTTree(node.nextnodes[0]), makeASTTree(node.nextnodes[1]))

    if isinstance(node, DFSyscall):
        return SystemCall(node.syscall, tuple([makeASTTree(n) for n in node.nextnodes]) )

    raise TypeError("Unsupported DFNode %s" % type(node))
