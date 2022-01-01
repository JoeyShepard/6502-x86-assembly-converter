#!/usr/bin/env python3

import sys

fp=open(sys.argv[1])
f_out=open(sys.argv[2],"wt")
f_out.write("ROM_data:\n")
for line in fp:
    byte_count=int(line[1:3],16)
    if byte_count!=0:
        f_out.write("\tdd 0x"+line[1:3]+", 0x"+line[3:7]+"\n")
        line_out=""
        for i in range(0,byte_count):
            if line_out!="": line_out+=", "
            line_out+="0x"+line[i*2+9:i*2+11]
        f_out.write("\tdb "+line_out+"\n")

f_out.write("\tdd 0\n")

f_out.close()
fp.close()
