#!/usr/bin/env python3

from sys import exit,argv
from info6502 import *
from opt6502 import *
from pseudo6502_x86 import *
from os import remove
from copy import deepcopy

#Classes
#=======
LT_OP=0
LT_PSEUDO_OP=1
LT_LABEL=2

class line_type:
    def __init__(self,type,data,address,label=""):
        self.type=type
        self.data=data
        self.address=address 
        self.label=label
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
        elif type==LT_PSEUDO_OP:
            self.op=data[0]
            self.arg2=None
            if len(data)>=2:
                self.arg="0x"+str(hex(data[1])).upper()[2:]
            if len(data)==3:
                self.arg2="0x"+str(hex(data[2])).upper()[2:]
            self.op_name=PSEUDO_OP_INFO[self.op][OP_NAME]
            self.op_mode=PSEUDO_OP_INFO[self.op][OP_MODE]
        elif type==LT_LABEL:
            self.op=[]
            self.arg=""
            self.op_name=""
            self.op_mode=""
        else:
            print(f"Error: Unknown line type: {type}")
            exit()

class optimizer_line:
    def __init__(self,init,step):
        self.original=init[:]
        self.match=[]
        self.ID=None
        self.step=step

        if init[0] in ["LOAD", "KEEP"]:
            self.match=OPT_CLASSES[init[0]+" "+init[1]]
        else:
            if init[0].isnumeric():
                self.ID=int(init[0])
                init=init[1:]
            if init[0] in OP_LIST:
                op_name=init[0]
                if len(init)==1:
                    if (op_name,"IMP") in OP_LOOKUP:
                        self.match+=[OP_LOOKUP[(op_name,"IMP")]]
                    else:
                        print("Error: unknown symbol in optimization pattern")
                        print(init)
                        exit()
                else:
                    for i in init[1:]:
                        if i=="ANY":
                            self.match=[k for k,v in OP_INFO.items() if v[0]==op_name]
                            break
                        elif (op_name,i) in OP_LOOKUP:
                            self.match+=[OP_LOOKUP[(op_name,i)]]
                        else:
                            print("Error: unknown symbol in optimization pattern")
                            print(init)
                            exit()
            else:
                print("Error: unknown symbol in optimization pattern")
                print(init)
                exit()

    def debug(self):
        print(self.step,"" if self.ID==None else self.ID,self.match,self.original)

    def debug_str(self):
        return str(self.step)+" "+(str(self.ID)+" " if self.ID!=None else "")+str(self.match)+" "+str(self.original)


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
        if label=="code_end":
            break

        #Extract and convert bytes
        if LineColon(line):
            byte_list=LineBytes(line)
            
            if label!="":
                line_no_label=LineSource(line).strip()[len(label)+1:]
            else:
                line_no_label=LineSource(line).strip()

            #Only process if bytes on line and source (ie not second line of FCB etc)
            if len(byte_list)!=0 and line_no_label!="":
                token=line_no_label.split()[0]
                if token.upper() in OP_LIST:
                    if byte_list[0] in OP_INFO.keys():
                        if OP_INFO[byte_list[0]][OP_SIZE]==len(byte_list):
                            #Good - add instruction to list
                            code6502+=[line_type(LT_OP, byte_list, LineAddress(line), label)]
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
                
                #Label alone on line
                if label!="":
                    code6502+=[line_type(LT_LABEL, [], LineAddress(line), label)]
        else:
            pass
    except:
        print("Error processing line",str(line_num+1)+":",line.strip())
        exit()

input_f.close()


#Read in peephole optimizations 
#==============================
peephole_state="NONE"
optimizations=[]
peephole_sets=[]
new_name=""
new_symbols={}
new_requires=[]
new_patterns=[]
new_pattern_list=[]
new_replacements=[]
new_set={}
sets_applied=False
exclude_begin=None
exclude_end=None

def ApplySets():
    global peephole_sets
    global new_patterns
    new_sets=[]
    for i in peephole_sets:
        new_set=[]
        for j in range(len(i[list(i)[0]])):
            new_set+=[{}]
        for j in i:
            for l,k in enumerate(i[j]):
                new_set[l]["%"+j]=k
        new_sets+=[new_set]
   
    ret_sets=[]
    for i in new_sets:
        if ret_sets==[]:
            ret_sets=i[:]
        else:
            new_new_sets=[]
            for j in i:
                for k in ret_sets:
                    new_new_sets+=[{**j,**k}]
            ret_sets=new_new_sets[:]

    peephole_sets=ret_sets[:]
    if peephole_sets==[]:
        peephole_sets=[{}]

    new_patterns=[]
    for i in range(len(peephole_sets)):
        new_patterns+=[[]]
    if new_patterns==[]:
        new_patterns=[[]]

def AddPattern(tokens,step):
    global new_patterns
    global peephole_sets
    for i in range(len(new_patterns)):
        new_pattern=[]
        for j in tokens:
            if j in peephole_sets[i]:
                new_pattern+=[peephole_sets[i][j]]
            else:
                new_pattern+=[j]
        new_patterns[i]+=[optimizer_line(new_pattern,step)]

f_peephole=open("optimizations.txt")
for line in f_peephole:
    temp_line=line.strip()
    if temp_line=="":
        continue
    elif temp_line[0]=="#":
        continue
    tokens=temp_line.split()
   
    repeat=True
    while(repeat):
        repeat=False
        if peephole_state=="NONE":
            if tokens[0] in ["NAME","SET","SYMBOL","REQUIRE","PRE","PATTERN","POST"]:
                peephole_state=tokens[0]
            elif tokens[0]=="EXCLUDE":
                if tokens[2]!="TO":
                    print("Problem with EXCLUDE:")
                    print(temp_line)
                    exit()
                exclude_begin=int(tokens[1],16)
                exclude_end=int(tokens[3],16)
        elif peephole_state=="NAME":
            if tokens[0] in ["SET","SYMBOL","REQUIRE","PRE","PATTERN","POST"]:
                peephole_state=tokens[0]
            else:
                new_name=temp_line
        elif peephole_state=="SET":
            if tokens[0]=="DEF":
                new_set[tokens[1]]=tokens[2:]
            elif tokens[0]=="SET":
                peephole_sets+=[new_set]
                new_set={}
            elif tokens[0] in ["SYMBOL","REQUIRE","PRE","PATTERN"]:
                if new_set!={}:
                    peephole_sets+=[new_set]
                    new_set={}
                peephole_state=tokens[0]
        elif peephole_state=="SYMBOL":
            if tokens[0] in ["REQUIRE","PRE","PATTERN","POST"]:
                peephole_state=tokens[0]
            else:
                new_symbols[tokens[0]]=tokens[1:]   
        elif peephole_state=="REQUIRE":
            if tokens[0] in ["PRE","PATTERN","POST"]:
                peephole_state=tokens[0]
            else:
                new_requires+=[tokens[:]]
        elif peephole_state=="PRE":
            if tokens[0] in ["PATTERN","POST"]:
                peephole_state=tokens[0]
            else:
                if sets_applied==False:
                    ApplySets()
                    sets_applied=True
                AddPattern(tokens,"PRE")
        elif peephole_state=="PATTERN":
            if tokens[0] in ["PATTERN","POST","REPLACE"]:
                new_pattern_list+=[new_patterns[:]]
                if tokens[0]=="PATTERN":
                    pattern_size=len(new_patterns)
                    new_patterns=[]
                    for i in range(pattern_size):
                        new_patterns+=[[]]
                    if new_patterns==[]:
                        new_patterns=[[]]
                peephole_state=tokens[0]
            else:
                if sets_applied==False:
                    ApplySets()
                    sets_applied=True
                AddPattern(tokens,"PATTERN")
        elif peephole_state=="POST":
            if tokens[0] in ["REPLACE"]:
                peephole_state="REPLACE"
            else:
                AddPattern(tokens,"POST")
        elif peephole_state=="REPLACE":
            if tokens[0]=="END":
                new_optimization={}
                new_optimization["name"]=new_name
                new_optimization["symbols"]=deepcopy(new_symbols)
                new_optimization["requires"]=new_requires[:]
                new_optimization["replacement"]=new_replacements[:]
                for pattern_set in new_pattern_list:
                    for pattern in pattern_set:
                        new_optimization["pattern"]=deepcopy(pattern)
                        new_optimization["pattern_len"]=len(pattern)
                        optimizations+=[deepcopy(new_optimization)]    
                #Reset for next pattern
                peephole_state="NONE"
                peephole_sets=[]
                new_name=""
                new_symbols={}
                new_requires=[]
                new_patterns=[]
                new_pattern_list=[]
                new_replacements=[]
                new_set={}
                sets_applied=False
            else:
                new_replacements+=[tokens[:]]
f_peephole.close()

with open("opt-debug.txt","wt") as f:
    for i in optimizations:
        f.write("Optimization\n")
        f.write("============\n")
        for j in ["symbols","requires","replacement"]:
            f.write(j+": "+str(i[j])+"\n")
        for j in i["pattern"]:
            f.write(j.debug_str()+"\n")
        f.write("\n")


#Optimize 6502 assembly - peephole and flags
#===========================================
def StackOps(stack, ops, symbols):
    try:
        for item in ops:
            if item in symbols:
                stack.append(symbols[item])
            elif item in ["+","-","*","/","<<",">>","="]:
                tos=stack.pop()
                nos=stack.pop()
                if item=="+":
                    stack.append(nos+tos)
                elif item=="-":
                    stack.append(nos-tos)
                elif item=="*":
                    stack.append(nos*tos)
                elif item=="/":
                    stack.append(nos/tos)
                elif item=="<<":
                    stack.append(nos<<tos)
                elif item==">>":
                    stack.append(nos>>tos)
                elif item=="=":
                    if nos==tos:
                        stack.append(1)
                    else:
                        stack.append(0)
            elif item.isnumeric():
                stack.append(int(item))
            else:
                print("Error: symbol in optimization list not recognized:",item)
                print("Input:",ops)
                print("All symbols: ",end="")
                for k,v in symbols.items():
                    print(k+": ",end="")
                    if type(v) is int:
                        print(hex(v),end="")
                    else:
                        print('"'+v+'"',end="")
                    print(", ",end="")
                print()
                exit()
    except SystemExit:
        #exit above raises error instead of actually exiting :/
        exit()
    except:
        print("Error parsing symbol list - symbol:",item)
        print("Input:",ops)
        exit()

def DebugStack(stack):
    ret_val=""
    for i in stack:
        if type(i) is int:
            ret_val+=hex(i)
        else:
            ret_val+='"'+i+'"'
        ret_val+=" "
    return ret_val

def Optimize(stretch, f_opt):
    if stretch==[]:
        return []

    #Peephole optimize
    peepholing=True
    while peepholing:
        #Debug
        f_opt.write("Stretch:\n")
        for i,j in enumerate(stretch):
            line_num=("0"+str(i))[-2:]+" "
            if j.label!="":
                f_opt.write("\t"+line_num+j.label+":\n")
            if j.type==LT_OP:
                f_opt.write("\t"+line_num+j.op_name+" "+j.op_mode+" "+j.arg+"\n")
            elif j.type==LT_PSEUDO_OP:
                f_opt.write("\t"+line_num+j.op_name+" "+j.op_mode+" "+j.arg)
                if j.arg2!=None:
                    f_opt.write(", "+j.arg2)
                f_opt.write("\n")
        f_opt.write("\n")

        peepholing=False
        stretch_len=len(stretch)
        for optimization in optimizations:
            if peepholing:
                break
            for index in range(stretch_len):
                if peepholing:
                    break
                if index+optimization["pattern_len"]>stretch_len:
                    break
                pattern_found=True
                for i,pattern in enumerate(optimization["pattern"]):
                    if stretch[i+index].op not in pattern.match:
                        pattern_found=False
                        break
                if pattern_found:
                    #Debug
                    f_opt.write("\t"+"Optimization pattern matched: "+optimization["name"]+"\n")
                    for i,pattern in enumerate(optimization["pattern"]):
                        output_str=""
                        line_num=("0"+str(i+index))[-2:]+" "
                        output_str=line_num+stretch[i+index].op_name+" "+stretch[i+index].op_mode+" "+stretch[i+index].arg
                        output_str+=(30-len(output_str))*" "
                        f_opt.write("\t"+output_str+hex(stretch[i+index].op)[2:].upper()+" ")
                        pattern_bytes="["
                        for j in pattern.match:
                            pattern_bytes+=hex(j)[2:].upper()+", "
                        pattern_bytes=pattern_bytes[:-2]+"]"
                        f_opt.write(pattern_bytes+"\n")

                    #Symbols
                    symbol_list={}
                    for i,pattern in enumerate(optimization["pattern"]):
                        if pattern.ID!=None:
                            symbol_list["%A"+str(pattern.ID)]=int(stretch[i+index].arg,16)
                            symbol_list["%M"+str(pattern.ID)]=stretch[i+index].op_mode
                    for k,v in optimization["symbols"].items():
                        stack=[]
                        StackOps(stack,v,symbol_list)
                        if len(stack)!=1:
                            print("Error: invalid symbol definition - wrong output size.")
                            print("Symbol:",k)
                            print("Input:",v)
                            print("Output:",DebugStack(stack))
                            exit()
                        symbol_list["%"+k]=stack[0]

                    #Requirements
                    require_list=[]
                    for i in optimization["requires"]:
                        require_results=[]
                        StackOps(require_results,i,symbol_list)
                        require_list+=require_results[:]
                    require_success=True
                    for i in require_list:
                        if i:
                            continue
                        else:
                            require_success=False
                            break
                    
                    #Debug
                    if require_success:
                        f_opt.write("\tOptimization requirements MET\n")
                    else:
                        f_opt.write("\tOptimization requirements NOT MET\n\n")

                    #Requirement met - optimize
                    if require_success:
                        replacement_stretch=[]
                        for line in optimization["replacement"]:
                            new_line=[]
                            for symbol in line:
                                if symbol in symbol_list:
                                    new_line+=[symbol_list[symbol]]
                                else:
                                    new_line+=[symbol]
                            if new_line[0] in OP_LIST:
                                #TODO: implement support for 6502 instructions in replacement if ever needed
                                print("Error: 6502 code in optimization replacement - not implemented!")
                                exit()
                            elif new_line[0] in PSEUDO_OP_LIST:
                                symbol_iter=iter(new_line[1:])
                                mode1=next(symbol_iter,None)
                                arg1=next(symbol_iter,None)
                                comma=next(symbol_iter,None)
                                if comma==None:
                                    #Only one argument
                                    if mode1==None or arg1==None or (new_line[0],mode1) not in PSEUDO_OP_LOOKUP:
                                        print("Error: invalid pseudo instruction in optimization replacement")
                                        print("Input:",line)
                                        print("Expanded input:",new_line)
                                        exit()
                                    op_code=PSEUDO_OP_LOOKUP[(new_line[0],mode1)]
                                    replacement_stretch+=[line_type(LT_PSEUDO_OP,[op_code,arg1],0)]
                                else:
                                    #Two arguments
                                    mode2=next(symbol_iter,None)
                                    arg2=next(symbol_iter,None)
                                    combined_mode=mode1+","+mode2
                                    if  mode1==None or arg1==None or comma!="," or \
                                        mode2==None or arg2==None or \
                                        (new_line[0],combined_mode) not in PSEUDO_OP_LOOKUP:
                                        print("Error: invalid pseudo instruction format in optimization replacement")
                                        print("Input:",line)
                                        print("Expanded input:",new_line)
                                        exit()
                                    op_code=PSEUDO_OP_LOOKUP[(new_line[0],combined_mode)]
                                    #Set address to 0 then reset below
                                    replacement_stretch+=[line_type(LT_PSEUDO_OP,[op_code,arg1,arg2],0)]
                                f_opt.write("\tReplacement:\n")
                                f_opt.write("\t"+new_line[0]+" "+combined_mode+" "+hex(arg1)[2:].upper())
                                if arg2!=None:
                                    f_opt.write(", "+hex(arg2)[2:].upper())
                                f_opt.write("\n\n")
                            else:
                                print("Error: unknown instruction in optimization replacement")
                                print("Input:",line)
                                print("Expanded input:",new_line)
                                exit()

                        #Insert replacement
                        new_stretch=[]
                        replacement_inserted=False
                        for i,line in enumerate(stretch):
                            if i<index:
                                new_stretch+=[stretch[i]]
                            elif i-index<len(optimization["pattern"]):
                                if optimization["pattern"][i-index].step in ["PRE","POST"]:
                                    new_stretch+=[stretch[i]]
                                elif optimization["pattern"][i-index].step=="PATTERN":
                                    if replacement_inserted==False:
                                        replacement_address=int(line.address,16)
                                        for replacement_line in replacement_stretch:
                                            replacement_line.address=("0000"+hex(replacement_address)[2:]).upper()
                                            replacement_address+=1
                                            new_stretch+=[replacement_line]
                                        replacement_inserted=True
                            else:
                                new_stretch+=[stretch[i]]
                        stretch=new_stretch[:]
                        peepholing=True
                        break 

    #Optimize flags

    return stretch
            
f_optimized=open("optimized.asm","wt")

optimized_code6502=[]
stretch=[]
for i in code6502:
    if i.label!="":
        optimized_code6502+=Optimize(stretch,f_optimized)
        stretch=[i]
    elif i.op_name in ["BCC","BCS","BMI","BPL","BVC","BVS","BEQ","BNE","JMP","JSR","RTS"]:
        stretch+=[i]
        optimized_code6502+=Optimize(stretch,f_optimized)
        stretch=[]
    else:
        stretch+=[i]

if stretch!=[]:
    optimized_code6502+=Optimize(stretch,f_optimized)

code6502=optimized_code6502[:]

f_optimized.close()


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
            if line2.type!=LT_LABEL:
                output_f.write("\tL"+line2.address+":\n")
            if line2.type==LT_OP:
                #Debug version
                #=============
                #output_f.write("\t\tmov [debug_address], dword 0x"+line2.address+"\n");
                #if line2.op_name in ["BCC","BCS","BMI","BPL","BVC","BVS","BEQ","BNE","JMP"]:
                #    output_f.write("\t\tdebug_prefix 0x"+line2.address+"\n")
                #    output_f.write(x86_Convert(line2))
                #elif line2.op_name in ["BRK","JSR","RTS"]:
                #    output_f.write(x86_Convert(line2))
                #else:
                #    output_f.write(x86_Convert(line2))
                #    output_f.write("\t\tdebug_postfix 0x"+line2.address+"\n")
                
                output_f.write(x86_Convert(line2))
                
    else:
        output_f.write(line)

output_f.close()
template_f.close()


#Output 6502 to x86 jump table
#=============================
jump_table_f=open("jump_table.asm","wt")
jump_table_f.write(";Jump table for translating 6502 addresses to x86 addresses\n")
jump_table_f.write("jump_table:\n")

address_list=[i.address for i in code6502 if i.type==LT_OP]
for address in range(0x10000):
    test_address=("0000" + hex(address)[2:].upper())[-4:]
    if test_address in address_list:
        jump_table_f.write("\tdd L"+test_address+"\n")
    else:
        jump_table_f.write("\tdd bad_jump\n")

jump_table_f.close()

