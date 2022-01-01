#!/bin/bash

TEST_NAME=input-test-small

#x86 conversion
#==============
echo Processing x86 conversion...

cd ~/projects/6502/6502-x86/
./process.py node-comparison/$TEST_NAME/processed.lst

if [ ! -f "output.asm" ]; then
    exit
fi

./rom/rom.py node-comparison/$TEST_NAME/prog.hex ROM_data.asm

echo -e "\e[1;32mAssembling x86 conversion...\e[1;31m"

FILE=./x86-6502

#Delete executable in case assembling fails
rm -f $FILE

nasm -gdwarf -f elf64 output.asm -l output.lst
#ld -g -o x86-6502 output.o
#Link with gcc instead to get C library functions like puts
gcc -g -no-pie -o $FILE output.o

echo -e "\e[1;32mDone assembling\e[0m"

if test -f "$FILE"; then
    #gdb -ex 'break halt_breakpoint' -ex 'layout regs' -ex 'starti' -q x86-6502
    #gdb -ex 'break halt_breakpoint' -ex 'layout regs' -ex 'run' -q $FILE
    mv $FILE node-comparison/$TEST_NAME/
    cd node-comparison/$TEST_NAME/
    ./$FILE
fi

mv cycles.txt cycles-x86.txt


#node.js emulation
#=================
echo Running node.js emulation...
cd  ~/projects/6502/6502-emu-node.js/tests/$TEST_NAME/
cp ../emu.js ./
cp ~/projects/6502/6502-x86/node-comparison/$TEST_NAME/prog.hex ./
./run.sh
cp cycles.txt ~/projects/6502/6502-x86/node-comparison/$TEST_NAME/cycles-node.txt
cd ~/projects/6502/6502-x86/node-comparison/$TEST_NAME/


#compare cycles
#==============
if [ "$1" != "silent" ]; then
    ../compare.py $1
fi


