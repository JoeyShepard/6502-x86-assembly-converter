PSEUDO_OP_LIST=[    "ADD8", "ADD16", 
                    "MOV8", "MOV16"]

PSEUDO_OP_MODES=[   "ABS,ABS", "ABS,IMMED"]

PSEUDO_OP_INFO={    300:("ADD16",   "ABS,ABS"),
                    301:("ADD16",   "ABS,IMMED"),
                    310:("MOV8",    "ABS,IMMED"),
                    320:("MOV16",   "ABS,ABS"),
                    321:("MOV16",   "ABS,IMMED")
                    }

#Instructions that should support all possible modes
for i in ["ADD8","SUB8"]:
    #TODO: add all addressing modes to PSEUDO_OP_INFO for these
    pass

PSEUDO_OP_LOOKUP={}
for k,v in PSEUDO_OP_INFO.items():
    PSEUDO_OP_LOOKUP[(v[0],v[1])]=k
