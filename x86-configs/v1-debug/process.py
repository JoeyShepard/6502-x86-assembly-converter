#!/usr/bin/env python3

from sys import exit,argv
from info6502 import *
from os import remove

#Classes
#=======
LT_OP=0
LT_BIN=1

class line_type:
    def __init__(self,type,data,address):
        self.type=type
        self.data=data
        self.address=address 
        if type==LT_OP:
            self.op=data[0] 
            if len(data)==2:
                self.arg="0x"+str(hex(data[1])).upper()[2:]
            elif len(data)==3:
                self.arg="0x"+str(hex((data[2]<<8)+data[1])).upper()[2:]
            else:
                self.arg=""
            self.op_name=OP_INFO[self.op][OP_NAME]
            self.op_mode=OP_INFO[self.op][OP_MODE]

        else:
            print(f"Unknown line type: {type}")
            raise 


#Functions
#=========
def LineColon(line):
    if len(line)<=18:
        return False
    elif line[18]==":":
        return True
    else:
        return False

def LineAddress(line):
    return ("0000"+line[13:17].strip())[-4:]

def LineBytes(line):
    if line[20]=="=": return []
    return list(map(lambda x:int(x,16),line[20:37].split()))

def LineSource(line):
    return line[40:-1]

def LineLabel(line): 
    if len(line)<=40:
        return ""
    
    source=line[40:-1].strip()
    if source=="":
        return ""    

    index=0
    for c in source:
        if c==":":
            return source[:index]
        if not c.isalnum() and c not in "._":
            return ""
        index+=1   

    return ""

def x86_Convert(line):
    if_enabled=True

    ret_val="\t\t;"+line.op_name+" "+line.arg+" "+line.op_mode+"\n"
    for tokens in x86_ops[line.op_name][line.op_mode]:
        new_tokens=[]
        for token in tokens:
            jsr_address=("0000"+hex(int(line.address,16)+2).upper()[2:])[-4:]
            if token=="%address":
                new_tokens+=["0x"+line.address]
            elif token=="%jsr1":
                new_tokens+=["0x"+jsr_address[0:2]]
            elif token=="%jsr2":
                new_tokens+=["0x"+jsr_address[2:4]]
            elif token=="%arg":
                new_tokens+=[line.arg]
            elif token=="%jmp":
                new_tokens+=["L"+("0000"+line.arg[2:])[-4:]]
            elif token=="%rel":
                rel=line.data[1]
                if rel>=0x80:
                    rel=-(0x100-rel)
                rel_address=int(line.address,16)+rel+2
                new_tokens+=["L"+("0000"+hex(rel_address)[2:].upper())[-4:]]
            else:
                new_tokens+=[token]
        if new_tokens[0]=="%if":
            if_enabled=False
            for condition in new_tokens[2:]:
                if new_tokens[1]==condition:
                    if_enabled=True
        elif new_tokens[0]=="%endif":
            if_enabled=True
        else:
            if if_enabled:
                ret_val+="\t\t"+" ".join(new_tokens)+"\n"
    return ret_val


#Setup
#=====
#Delete output file so assembler doesn't run on old file
try:
    remove("output.asm")
except:
    pass

#Read in 6502 assembly
#=====================
code6502=[]

#Open 6502 input
if len(argv)==1:
    #Default value
    input_f=open("test.lst")
else:
    input_f=open(argv[1])

#Skip first three lines
for _ in range(3):
    input_f.readline()

for line_num,line in enumerate(input_f):
    try:
        #Extract labels
        label=LineLabel(line)
        
        #Extract and convert bytes
        if LineColon(line):
            byte_list=LineBytes(line)
            #Only process if bytes on line and source (ie not second line of FCB etc)
            if len(byte_list)!=0 and LineSource(line).strip()!="":
                token=LineSource(line).split()[0]
                if token.upper() in OP_LIST:
                    if byte_list[0] in OP_INFO.keys():
                        if OP_INFO[byte_list[0]][OP_SIZE]==len(byte_list):
                            #Good - add instruction to list
                            code6502+=[line_type(LT_OP, byte_list, LineAddress(line))]
                        else:
                            print(f"Error: instruction size mismatch")
                            print(line[:-1])
                            exit()  
                    else:
                        print(f"Error: instruction byte mismatch")
                        print(line[:-1])
                        exit()
                elif token=="FCB":
                    pass
                elif token=="FDB":
                    pass
                else:
                    print(f"Error: token '{token}' not found!")
                    print(line[:-1])
                    exit()
            else:
                #No bytes on line or bytes without source (ie second line of FCB)

                #Check for last label
                if LineSource(line)=="code_end:":
                    break
        else:
            pass
    except:
        print("Error processing line",str(line_num+1)+":",line.strip())
        exit()

input_f.close()


#Optimize 6502 assembly
#======================


#Read in x86 instructions
#========================
STATE_NONE=0
STATE_BLOCK=1
STATE_OP=2
STATE_OP_PRE=3
STATE_OP_POST=4

state=STATE_NONE

modes={}

op_names=[]
op_modes={}
x86_names=[]
x86_ops={}
reg_names=[]
reg_names2=[]
pre_tokens=[]
post_tokens=[]
defines={}
block_name=""
blocks={}

def ReplaceTokens(token_input,op,mode):
    global defines,modes,reg_names,reg_names2
    
    if token_input==[]: return []
    
    ret_tokens=token_input[:]
    gen_tokens=[]
    all_resolved=False
    
    while not all_resolved:
        all_resolved=True
        for tokens in ret_tokens:
            if tokens[0] in blocks.keys():
                all_resolved=False
                gen_tokens+=blocks[tokens[0]]
            else:
                new_tokens=[]
                for token in tokens:
                    replaceable=True
                    if token=="%1":
                        new_tokens+=[token_input[0][1]]
                    elif token=="%2":
                        new_tokens+=[token_input[0][2]]
                    elif token=="%3":
                        new_tokens+=[token_input[0][3]]
                    elif token=="%op":
                        new_tokens+=[op]
                    elif token=="%mode":
                        new_tokens+=modes[mode]
                    elif token=="%reg":
                        new_tokens+=[reg_names[i]]
                    elif token=="%reg2":
                        new_tokens+=[reg_names2[i]]
                    elif token in defines.keys():
                        new_tokens+=defines[token] 
                    else:
                        new_tokens+=[token]
                        replaceable=False
                    if replaceable: all_resolved=False
                if new_tokens!=[]:
                    gen_tokens+=[new_tokens]
        ret_tokens=gen_tokens[:]
        gen_tokens=[]
    return ret_tokens

x86_f=open("x86.txt")
for lc,line in enumerate(x86_f):
    clean_line=line.strip()
    tokens=line.split()
    if state==STATE_NONE:
        if clean_line=="" or clean_line[0]=='#': 
            continue
        if tokens[0]=="DEF":
            defines["%"+tokens[1]]=tokens[2:]
        elif tokens[0]=="MODE":
            modes[tokens[1]]=tokens[2:]
        elif tokens[0]=="BLOCK":
            state=STATE_BLOCK
            block_name="%"+tokens[1]
            blocks[block_name]=[]
        elif tokens[0]=="OP":
            state=STATE_OP
            op_names=tokens[1:]
            #Set x86 names to same as 6502 in case X86 line omitted
            x86_names=op_names
            #Need to be explicitly cleared unlike other temporary variables
            op_modes=[]
            pre_tokens=[]
            post_tokens=[]
        else:
            print("Unknown input on line",lc,":")
            print(line)
    elif state==STATE_BLOCK:
        if clean_line!="":
            if tokens[0]=="END":
                state=STATE_NONE
            else:
                blocks[block_name]+=[tokens]
    elif state in [STATE_OP, STATE_OP_PRE, STATE_OP_POST]:
        if clean_line!="":
            if state==STATE_OP_PRE:
                if tokens[0]=="POST":
                    state=STATE_OP_POST
                elif tokens[0]=="MODE":
                    state=STATE_OP
                else:
                    pre_tokens+=[tokens]
            elif state==STATE_OP_POST:
                if tokens[0]=="MODE":
                    state=STATE_OP
                else:
                    post_tokens+=[tokens]

            if state==STATE_OP: 
                if tokens[0]=="X86":
                    x86_names=tokens[1:]
                    if len(op_names)!=len(x86_names):
                        print("6502 op list does not match size of x86 op list:")
                        print("6502: ",op_names)
                        print("x86: ",x86_names)
                        exit()
                elif tokens[0]=="REGS":
                    reg_names=tokens[1:]
                elif tokens[0]=="REGS2":
                    reg_names2=tokens[1:]
                elif tokens[0]=="PRE":
                    state=STATE_OP_PRE
                elif tokens[0]=="POST":
                    state=STATE_OP_POST
                elif tokens[0]=="MODE":
                    if op_modes!=[]:
                        for i,op in enumerate(x86_names):
                            for mode in op_modes:
                                x86_ops[op_names[i]][mode]+=ReplaceTokens(post_tokens,op,mode)
                    op_modes=tokens[1:]
                    for op in op_names:
                        if op not in x86_ops.keys():
                            x86_ops[op]={}
                        for mode in op_modes:
                            x86_ops[op][mode]=ReplaceTokens(pre_tokens,op,mode)
                elif tokens[0]=="END":
                    for i,op in enumerate(x86_names):
                        for mode in op_modes:
                            x86_ops[op_names[i]][mode]+=ReplaceTokens(post_tokens,op,mode)
                    state=STATE_NONE
                else:
                    for i,op in enumerate(x86_names):
                        for mode in op_modes:
                            x86_ops[op_names[i]][mode]+=ReplaceTokens([tokens],op,mode)

x86_f.close()

debug_f=open("debug.txt","wt")

for op in x86_ops.keys():
    for mode in x86_ops[op]:
        debug_f.write("\n"+op+" "+mode+":\n")
        for tokens in x86_ops[op][mode]:
            debug_f.write(" ".join(tokens)+"\n")

debug_f.close()


#Read in x86 template and output conversion
#==========================================
template_f=open("template.asm")
output_f=open("output.asm","wt")

for line in template_f:
    if line.strip()=="%code":
        for line2 in code6502:
            output_f.write("\tL"+line2.address+":\n")
            if line2.type==LT_OP:
                output_f.write("\t\tmov [debug_address], dword 0x"+line2.address+"\n");
                if line2.op_name in ["BCC","BCS","BMI","BPL","BVC","BVS","BEQ","BNE","JMP"]:
                    output_f.write("\t\tdebug_prefix 0x"+line2.address+"\n")
                    output_f.write(x86_Convert(line2))
                elif line2.op_name in ["BRK","JSR","RTS"]:
                    output_f.write(x86_Convert(line2))
                else:
                    output_f.write(x86_Convert(line2))
                    output_f.write("\t\tdebug_postfix 0x"+line2.address+"\n")
    else:
        output_f.write(line)

output_f.close()
template_f.close()


#Output 6502 to x86 jump table
#=============================
jump_table_f=open("jump_table.asm","wt")
jump_table_f.write(";Jump table for translating 6502 addresses to x86 addresses\n")
jump_table_f.write("jump_table:\n")

address_list=[i.address for i in code6502]
for address in range(0x10000):
    test_address=("0000" + hex(address)[2:].upper())[-4:]
    if test_address in address_list:
        jump_table_f.write("\tdd L"+test_address+"\n")
    else:
        jump_table_f.write("\tdd bad_jump\n")

jump_table_f.close()

