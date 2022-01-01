#!/bin/bash

#P generate .i file after processing
#G produce code
#U symbols not case sensitive
#L generate listing
#g generate debug info
#q quiet mode - only show errors
wine ~/emu/wine/as/bin/asw test.asm -P -G -U -L -g -q -cpu 6502
wine ~/emu/wine/as/bin/p2hex test.p -F Intel -l 32 -r \$0000-\$FFFF  > hex.txt

../rom/rom.py test.hex ../ROM_data.asm

cp test.lst ../

#For testing on Windows
cp test.hex prog.hex
./listing-filter.py test.lst listing.lst
