#!/bin/bash

#Remove cycles files if exit
#===========================
rm -f cycles-x86.txt
rm -f cycles-node.txt


#Assemble 6502 test
#==================
cd ~/projects/6502/6502-x86/test/
./run.sh


#x86 conversion
#==============
echo Processing...

cd ~/projects/6502/6502-x86/
./process.py test.lst

if [ ! -f "output.asm" ]; then
    exit
fi

echo -e "\e[1;32mAssembling...\e[1;31m"

FILE=./x86-6502

#Delete executable in case assembling fails
rm -f $FILE

nasm -gdwarf -f elf64 output.asm -l output.lst
#ld -g -o x86-6502 output.o
#Link with gcc instead to get C library functions like puts
gcc -g -no-pie -o $FILE output.o

echo -e "\e[1;32mDone\e[0m"

if test -f "$FILE"; then
    #gdb -ex 'break halt_breakpoint' -ex 'layout regs' -ex 'starti' -q x86-6502
    #gdb -ex 'break halt_breakpoint' -ex 'layout regs' -ex 'run' -q $FILE
    mv $FILE node-comparison/6502-test/$FILE
    cd node-comparison/6502-test
    ./$FILE
    mv cycles.txt cycles-x86.txt
fi



#node.js emulation
#=================
cd  ~/projects/6502/6502-emu-node.js/tests/x86-test/
cp ../emu.js ./
cp ~/projects/6502/6502-x86/test/test.hex prog.hex
cp ~/projects/6502/6502-x86/node-comparison/6502-test/input.txt ./
./run.sh
cp cycles.txt ~/projects/6502/6502-x86/node-comparison/6502-test/cycles-node.txt
cd ~/projects/6502/6502-x86/node-comparison/6502-test/


#compare cycles
#==============
if [ "$1" != "silent" ]; then
    ../compare.py
fi

