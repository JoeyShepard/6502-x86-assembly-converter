#!/usr/bin/env python3

from sys import path
from os.path import expanduser
path.append(expanduser("~/python/"))

from color import *
from sys import exit

#Constants
ERROR_COLOR="bright red"
REG_LIST=[" "," A:"," X:"," Y:"," SP:"," "]

#Open files
f_x86=open("cycles-x86.txt")
f_node=open("cycles-node.txt")

#Strip off first line
f_x86.readline()
f_node.readline()

#Loop through all lines
lines_left=True
line_count=2
while(lines_left):
    x86_line=f_x86.readline()[:-1]
    if len(x86_line)==0:
        lines_left=False
    node_line=f_node.readline()[:-1]
    if len(node_line)==0:
        if lines_left==False:
            #Both files end at same time, so exit
            break
        else:
            #Lines left in x86 file but not node
            printc("Ran out of lines in node file!\n",ERROR_COLOR)
            printc("x86 line "+str(line_count)+": "+x86_line,ERROR_COLOR)
            print()
            exit()
    if lines_left==False:
        #Lines left in node file but not x86
        printc("Ran out of lines in x86 file!\n",ERROR_COLOR)
        printc("node line "+str(line_count)+": "+node_line,ERROR_COLOR)
        print()
        exit()

    x86_address=x86_line[0:4]
    x86_A=x86_line[7:9]
    x86_X=x86_line[12:14]
    x86_Y=x86_line[17:19]
    x86_SP=x86_line[23:25]
    x86_flags=x86_line[26:30]
    x86_info=[x86_address,x86_A,x86_X,x86_Y,x86_SP,x86_flags]

    node_address=node_line[0:4]
    node_A=node_line[30:32]
    node_X=node_line[39:41]
    node_Y=node_line[44:46]
    node_SP=node_line[50:52]
    node_flags=node_line[71:75]
    node_info=[node_address,node_A,node_X,node_Y,node_SP,node_flags]
  
    printc(" "*(8-len(str(line_count)))+str(line_count))
    printc(" - "+node_line[16:28])
    if x86_info==node_info:
        print(" "*6+x86_line)
    else:
        printc("x86: ","magenta")
        for i,reg in enumerate(REG_LIST):
            if x86_info[i]!=node_info[i]:
                printc(reg+x86_info[i],ERROR_COLOR)
            else:
                printc(reg+x86_info[i])
        print()
        printc(" "*23+"node:","bright blue")
        for i,reg in enumerate(REG_LIST):
            if x86_info[i]!=node_info[i]:
                printc(reg+node_info[i],ERROR_COLOR)
            else:
                printc(reg+node_info[i])
        print()
        exit()

    line_count+=1
    
printc("x86 and node files match!\n","bright green")

