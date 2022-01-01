#!/bin/bash

TEST_NAME=input-medium.txt


#x86 conversion
#==============
echo Processing x86 conversion...

cd ~/projects/6502/6502-x86/
./process.py input-test/processed.lst

if [ ! -f "output.asm" ]; then
    exit
fi

./rom/rom.py input-test/prog.hex ROM_data.asm

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
    mv $FILE input-test/
    cd input-test
    cp input-files/$TEST_NAME input.txt

    time ./$FILE
fi

