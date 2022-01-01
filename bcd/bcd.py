#!/usr/bin/env python3

from sys import path
from os.path import expanduser
path.append(expanduser("~/python/"))

#from color import *
#from sys import exit

f=open("BCD_table.asm","wt")

f.write("BCD_to_dec:\n")
for i in range(256):
    f.write("\tdb ") 
    if i%16>=10 or i>0x99:
        f.write("0 ")
    else:
        f.write(hex(i)[2:]+" ")
    f.write(";from bcd "+hex(i)[2:]+"\n")

f.write("\n")
f.write("dec_to_BCD:\n")
for i in range(256):
    f.write("\tdb ") 
    if i>99:
        f.write("0 ")
    else:
        f.write("0x"+str(i)+" ")
    f.write(";from decimal "+str(i)+"\n")

f.close()



