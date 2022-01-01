DEBUG       = $FFE7
DEBUG_HEX   = $FFE8
FILE_INPUT  = $FFF0
PROG_EXIT   = $FFF1
    ORG $FFFC 
        FDB $C000
    ORG $C000
    main:
        ;Test data used below
        ;(was part of x86 template but need here to for node.js version to match)
        LDA #$57
        STA $2345
        LDA #$63
        STA $2346
        LDA #$45
        STA 9
        LDA #$23
        STA 10
    tests:
        ;Optimization - MOV8      
        ;===================
        ;Optimize to mov [0x30], 5
        LDA #5
        STA $30
        TXA
        ;Optimize to mov [0x31], 6
        LDX #6
        STX $31
        TAX
        ;Do not optimize
        LDA #7
        STA $32
        ADC #5
        .lbl_test: INX
        SED 
        CLC
        LDA #$99
        ADC #$99
        CLC
        LDA #$87
        ADC #$9
        CLC
        LDA #$87
        ADC #$20
        CLC
        LDA #$87
        ADC #$29
        ;JMP .skip_bcd_add
        ;Decimal addition tests
        SED
        LDA #0
        STA 10
        STA 11
        STA 12
        STA 13
        .bcd_add_1:
            LDA 10
            ORA 11
            STA 9
            ;STA DEBUG_HEX
            LDA 12
            ORA 13
            ;STA DEBUG_HEX
            ;CLC ;passed!
            SEC ;passed!
            ADC 9
            ;LDA #' '
            ;STA DEBUG
            INC 10
            LDA 10
            CMP #$A
            BCC .bcd_add_1
            LDA #0
            STA 10
            ;LDA #92
            ;STA DEBUG
            ;LDA #'n'
            ;STA DEBUG
            CLC
            LDA 11
            ADC #$10
            STA 11
            BNE .bcd_add_1
            INC 12
            LDA 12
            CMP #$A
            BCC .bcd_add_1
            LDA #0
            STA 12
            CLC
            LDA 13
            ADC #$10
            STA 13
            BNE .bcd_add_1
        .skip_bcd_add:
        ;JMP .skip_bcd_sub
        ;Decimal subtraction tests
        SED
        LDA #0
        STA 10
        STA 11
        STA 12
        STA 13
        .bcd_sub_1:
            LDA 10
            ORA 11
            STA 9
            ;STA DEBUG_HEX
            LDA 12
            ORA 13
            ;STA DEBUG_HEX
            SEC
            SBC 9
            ;LDA #' '
            ;STA DEBUG
            INC 10
            LDA 10
            CMP #$A
            BCC .bcd_sub_1
            LDA #0
            STA 10
            ;LDA #92
            ;STA DEBUG
            ;LDA #'n'
            ;STA DEBUG
            CLC
            LDA 11
            ADC #$10
            STA 11
            BNE .bcd_sub_1
            INC 12
            LDA 12
            CMP #$A
            BCC .bcd_sub_1
            LDA #0
            STA 12
            CLC
            LDA 13
            ADC #$10
            STA 13
            BNE .bcd_sub_1
        .skip_bcd_sub:
        CLD
        JMP .skip
        .string1:
        FCB "Test1\\nTest2\\nTest3\\n",0
        .skip:
        LDY #0
        .l3:
        LDA .string1,Y
        BEQ .done
        STA DEBUG
        INY
        JMP .l3
        .done:
        ;BRK
        LDA #'A'
        STA DEBUG
        STA DEBUG_HEX
        STA $2345
        ;LDA FILE_INPUT
        LDA $C000
        .l2:
        LDA FILE_INPUT
        STA DEBUG
        BNE .l2
        ;STA PROG_EXIT
        ;LDA #'H'
        ;STA DEBUG
        ;LDA #'\\'
        ;STA DEBUG
        ;LDA #'n'
        ;STA DEBUG
        ;LDA #'i'
        ;STA DEBUG
        ;STA PROG_EXIT
        LDA #'\\'
        STA DEBUG
        LDA #'n'
        STA DEBUG
        LDX #15
        LDA #1
        .loop:
            STA DEBUG_HEX
            CLC
            ADC #$11
            TAY
            LDA #' '
            STA DEBUG
            TYA
            DEX
            BNE .loop
        ;STA PROG_EXIT
        LDA #'H'
        STA DEBUG
        LDA #'i'
        STA DEBUG
        ;STA PROG_EXIT
        SEC
        LDA #5
        SBC #3
        SED
        SEC
        LDA #$12
        SBC #3
        CLC
        LDA #$12
        SBC #3
        SEC
        LDA #$21
        SBC #$32
        SEC
        LDA #5
        SBC #5
        CLD
        CLC
        LDA #$7F
        ADC #$80
        SED
        CLC
        LDA #9
        ADC #1
        SEC
        LDA #$46
        ADC #$47
        SEC
        LDA #$44
        ADC #$55
        CLC
        LDA #$98
        ADC #$67
        CLD
        SEC
        LDA #$55
        ADC #$55
        SEC
        ;N flag
        LDA #$80
        STA 100
        BIT 100
        ;Z and N flag
        LDA #$AA
        STA 100
        LDA #$55
        BIT 100
        ;O flag
        LDA #$40
        STA 100
        BIT 100
        ;N and O flag
        LDA #$C0
        STA 100
        LDA #$40
        BIT 100
        CLC
        LDA #$FF
        PHP
        SEC
        LDA #0
        PLP
        LDX #$FF
        TXS
        JSR jsr_test
        LDX #0
        TXS
        JSR jsr_test
        LDA #0
        STA 20
        LDA #2
        STA 21
        JMP (20)
        ijmp_ret:
        SEC
        LDA #3
        STA 20
        STA $4000
        ROR $4000
        LDA $4000
        LDX #1
        ROR $3FFF,X
        LDA $4000
        SEC
        ROR 19,X
        LDA 20
        ROR 19,X
        LDA 20 
        CLC
        LDX #21
        LDA #3
        STA 20
        ROR 255,X
        ROR 255,X
        ROR 255,X
        SEC
        LDA #3
        ROR
        ROR
        ROR
        ROR
        SEC 
        LDA #$C0
        ROL
        ROL
        ROL
        SEC
        LDA #$80
        LSR
        CLC
        LDA #3
        LSR
        LSR
        LSR
        LDA #3
        STA 21
        LSR 21
        LSR 21
        LDA 21
        LDA #3
        STA 21
        LDX #5
        LSR 21
        LSR 16,X
        LDA 21
        CLC
        LDA #$C0
        ASL
        ASL
        ASL
        LDA #$C0
        STA 20
        ASL 20
        LDA 20
        LDX #5
        ASL 15,X
        LDA 20
        ;JMP c_test_1
        LDX #0
        JMP test_jmp
        INX
        test_jmp:
        LDX #0
        CLV
        BVC test7
        INX
        test7:
        CLC
        LDA #5
        SBC #$80
        BVS test8
        INX
        test8:
        LDX #0
        LDA #0
        BEQ test5
        INX
        test5:
        LDA #1
        BNE test6
        INX
        test6:
        LDX #0
        LDA #$80
        BMI test3
        INX
        test3:
        LDA #0
        BPL test4
        INX
        test4:
        LDX #0
        SEC
        BCS test1
        INX
        test1:
        CLC
        BCC test2
        INX
        test2:
        LDX #$FF
        TXS
        LDA #$80
        PHA
        LDA #0
        LDA $1FF
        SEC
        TSX
        PLA
        LDA #$80
        TAY
        LDA #0
        TYA
        LDX #9
        TXS
        LDX #0
        TSX
        LDA #5
        TAX
        LDA #7
        TAY
        TXA
        TYA
        LDA #5
        SBC #$80
        SEC
        CLV
        CLC
        LDA #$20
        STA $2000
        ADC #1
        LDX #2
        STA $1FFF,X
        ADC #1
        LDY #4
        STA $1FFE,Y
        LDA $2000
        LDA $2001
        LDA $2002
        LDA #7
        ;BRK
        c_test_1: 
        CLC 
        LDA $2345
        INC $2345
        LDA $2345
        LDX #4
        INC $2341,X
        LDA $2345
        LDX #3
        DEC $2342,X
        DEC $2342,X
        LDA $2345
        LDX #254
        INX
        INX
        INX
        DEX
        DEX
        LDA #5
        CMP #7
        CMP #3
        LDX #5
        CPX #7
        CPX #3
        LDY #5
        CPY #7
        CPY #3
        LDA #5
        CMP #$80
        ;JMP *
        SEC
        LDA #$A5
        ORA #$55
        LDA #$A5
        EOR #$55
        SEC
        LDA #$A5
        AND #$55
        LDA #$FF
        AND #$7F
        LDA #$FF
        AND #$80
        CLC
        LDA #$FF
        AND #$7F
        ;BRK
        LDA $2345
        LDA $2346
        LDA 9
        LDA 10
        LDA #$EE
        LDY #0
        AND (9),Y
        CLC
        LDA #7
        LDY #1
        ADC (9),Y
        ADC 9
        ADC $2345
        LDA #9
        LDX #6 
        ADC (3,X) 
        LDY #0
        LDA (9),Y
        LDY #1
        LDA (9),Y
        LDX #6
        LDA (3,X)
        LDX #255
        LDA (10,X)
        SEC
        CLC
        SEC
        LDA #5
        CLC
        ADC #7
        LDA #$FF
        ADC #1
        LDA #$FF
        ADC #$FF
        LDA #5
        LDA #$7F
        LDA #$80
        LDA #$0
        LDA $23
        LDA $3456
        LDA $23,X
        LDA $3456,X
        LDA $3456,Y
        LDX #0
        LDX #$7F
        LDX #$FF
        LDY #$56
        STA PROG_EXIT
        BRK
        BRK
        JMP main
    jsr_test:
        LDX #5
        RTS
    ORG $200
        LDX #$77
        JMP ijmp_ret
    code_end:
