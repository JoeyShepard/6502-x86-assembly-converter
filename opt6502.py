from info6502 import *

def GetOps(op_list):
    return [k for k,v in OP_INFO.items() if v[0] in op_list]

OPT_CLASSES = {}
OPT_CLASSES["LOAD A"]=GetOps(["LDA","PLA","TXA","TYA"])
OPT_CLASSES["LOAD X"]=GetOps(["LDX","TAX","TSX"])
OPT_CLASSES["LOAD Y"]=GetOps(["LDY","TAY"])



