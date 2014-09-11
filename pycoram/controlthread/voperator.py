#-------------------------------------------------------------------------------
# voperator.py
# 
# Python-to-Verilog Operator conversion
#
# Copyright (C) 2013, Shinya Takamaeda-Yamazaki
# License: Apache 2.0
#-------------------------------------------------------------------------------
import sys
import os
import ast
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))) )
import pyverilog
import pyverilog.vparser
import pyverilog.vparser.ast as vast

operators = {
    ast.Add      : vast.Plus,
    ast.Sub      : vast.Minus,
    ast.Mult     : vast.Times,
    ast.Div      : vast.Divide,
    ast.Mod      : vast.Mod,
    ast.Pow      : vast.Power,
    ast.LShift   : vast.Sll,
    ast.RShift   : vast.Srl,
    ast.BitOr    : vast.Or,
    ast.BitXor   : vast.Xor,
    ast.BitAnd   : vast.And,
    ast.FloorDiv : vast.Divide,
    ast.And      : vast.Land,
    ast.Or       : vast.Lor,
    ast.Invert   : vast.Unot,
    ast.Not      : vast.Ulnot,
    ast.UAdd     : vast.Uplus,
    ast.USub     : vast.Uminus,
    ast.Eq       : vast.Eq,
    ast.NotEq    : vast.NotEq,
    ast.Lt       : vast.LessThan,
    ast.LtE      : vast.LessEq,
    ast.Gt       : vast.GreaterThan,
    ast.GtE      : vast.GreaterEq,
    ast.Is       : vast.Eq, # ?
    ast.IsNot    : vast.NotEq, # ?
    ast.In       : None,
    ast.NotIn    : None,
}

def getVerilogOperator(op):
    t = type(op)
    return operators[t]
