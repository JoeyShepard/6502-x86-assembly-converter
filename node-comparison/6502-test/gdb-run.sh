#!/bin/bash

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
    mv $FILE node-comparison/6502-test/
    cp output.asm node-comparison/6502-test/
    cd node-comparison/6502-test
    gdb -ex 'break halt_breakpoint' -ex 'layout regs' -ex 'starti' -q $FILE
fi


