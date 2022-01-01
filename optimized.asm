Stretch:
	00 main:
	01 LDA IMMED 0x57
	02 STA ABS 0x2345
	03 LDA IMMED 0x63
	04 STA ABS 0x2346
	05 LDA IMMED 0x45
	06 STA ZP 0x9
	07 LDA IMMED 0x23
	08 STA ZP 0xA

	Optimization pattern matched: LDx/STx for 16-bit constants
	01 LDA IMMED 0x57             A9 [A9]
	02 STA ABS 0x2345             8D [8D, 85]
	03 LDA IMMED 0x63             A9 [A9]
	04 STA ABS 0x2346             8D [8D, 85]
	05 LDA IMMED 0x45             A9 [68, 8A, 98, A1, A5, A9, AD, B1, B5, B9, BD]
	Optimization requirements MET
	Replacement:
	MOV16 ABS,IMMED 2345, 6357

Stretch:
	00 main:
	01 MOV16 ABS,IMMED 0x2345, 0x6357
	02 LDA IMMED 0x45
	03 STA ZP 0x9
	04 LDA IMMED 0x23
	05 STA ZP 0xA

	Optimization pattern matched: LDx/STx for 8-bit constants
	02 LDA IMMED 0x45             A9 [A9]
	03 STA ZP 0x9                 85 [8D, 85]
	04 LDA IMMED 0x23             A9 [68, 8A, 98, A1, A5, A9, AD, B1, B5, B9, BD]
	Optimization requirements MET
	Replacement:
	MOV8 ABS,IMMED 9, 45

Stretch:
	00 main:
	01 MOV16 ABS,IMMED 0x2345, 0x6357
	02 MOV8 ABS,IMMED 0x9, 0x45
	03 LDA IMMED 0x23
	04 STA ZP 0xA

Stretch:
	00 tests:
	01 LDA IMMED 0x5
	02 STA ZP 0x30
	03 TXA IMP 
	04 LDX IMMED 0x6
	05 STX ZP 0x31
	06 TAX IMP 
	07 LDA IMMED 0x7
	08 STA ZP 0x32
	09 ADC IMMED 0x5

	Optimization pattern matched: LDx/STx for 8-bit constants
	01 LDA IMMED 0x5              A9 [A9]
	02 STA ZP 0x30                85 [8D, 85]
	03 TXA IMP                    8A [68, 8A, 98, A1, A5, A9, AD, B1, B5, B9, BD]
	Optimization requirements MET
	Replacement:
	MOV8 ABS,IMMED 30, 5

Stretch:
	00 tests:
	01 MOV8 ABS,IMMED 0x30, 0x5
	02 TXA IMP 
	03 LDX IMMED 0x6
	04 STX ZP 0x31
	05 TAX IMP 
	06 LDA IMMED 0x7
	07 STA ZP 0x32
	08 ADC IMMED 0x5

	Optimization pattern matched: LDx/STx for 8-bit constants
	03 LDX IMMED 0x6              A2 [A2]
	04 STX ZP 0x31                86 [8E, 86]
	05 TAX IMP                    AA [A2, A6, AA, AE, B6, BA, BE]
	Optimization requirements MET
	Replacement:
	MOV8 ABS,IMMED 31, 6

Stretch:
	00 tests:
	01 MOV8 ABS,IMMED 0x30, 0x5
	02 TXA IMP 
	03 MOV8 ABS,IMMED 0x31, 0x6
	04 TAX IMP 
	05 LDA IMMED 0x7
	06 STA ZP 0x32
	07 ADC IMMED 0x5

Stretch:
	00 .lbl_test:
	00 INX IMP 
	01 SED IMP 
	02 CLC IMP 
	03 LDA IMMED 0x99
	04 ADC IMMED 0x99
	05 CLC IMP 
	06 LDA IMMED 0x87
	07 ADC IMMED 0x9
	08 CLC IMP 
	09 LDA IMMED 0x87
	10 ADC IMMED 0x20
	11 CLC IMP 
	12 LDA IMMED 0x87
	13 ADC IMMED 0x29
	14 SED IMP 
	15 LDA IMMED 0x0
	16 STA ZP 0xA
	17 STA ZP 0xB
	18 STA ZP 0xC
	19 STA ZP 0xD

	Optimization pattern matched: CLC/ADC pair to ADD
	02 CLC IMP                    18 [18]
	03 LDA IMMED 0x99             A9 [68, 8A, 98, A1, A5, A9, AD, B1, B5, B9, BD]
	04 ADC IMMED 0x99             69 [61, 65, 69, 6D, 71, 75, 79, 7D]
	Optimization requirements MET
