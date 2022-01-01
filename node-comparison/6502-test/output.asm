
;default rel

;Macros
%define halt call halt_breakpoint
%define false 0
%define true -1

%macro push_regs 0
    push rdi    ;6502 SP
    ;push rsi    ;unused
    push rdx    ;6502 temp
    push rcx    ;6502 Y reg
    push rax    ;6502 A reg
    pushfq
%endmacro

%macro pull_regs 0
    popfq
    pop rax
    pop rcx
    pop rdx
    ;pop rsi
    pop rdi
%endmacro

;External calls to C library
extern puts

;Constants
;=========
MEM_SIZE_6502   equ 0x10000

;Flags for v1 - OLD
;MASK_SF_FLAG    equ 0x8000
;MASK_ZF_FLAG    equ 0x4000
;MASK_SF_SHIFT   equ 15
;MASK_ZF_SHIFT   equ 14

MASK_CF_FLAG    equ 0x0001
MASK_ZF_FLAG    equ 0x0040
MASK_SF_FLAG    equ 0x0080
MASK_OF_FLAG    equ 0x0800

B_FLAG          equ 0x10
C_FLAG          equ 0x01
D_FLAG          equ 0x08
I_FLAG          equ 0x04
N_FLAG          equ 0x80
V_FLAG          equ 0x40
Z_FLAG          equ 0x02

PERIPHERALS     equ 0xFFE7
DEBUG           equ 0xFFE7
DEBUG_HEX       equ 0xFFE8
DEBUG_DEC       equ 0xFFE9
DEBUG_DEC16     equ 0xFFEA
DEBUG_TIMING    equ 0xFFEB
FILE_INPUT      equ 0xFFF0
PROG_EXIT       equ 0xFFF1

FILE_BUFF_SIZE  equ 10000
DEBUG_BUFF_SIZE equ 40

SYS_read        equ 0
SYS_write       equ 1
SYS_open        equ 2
SYS_close       equ 3
SYS_exit        equ 60
SYS_creat       equ 85

O_CREAT         equ 0x40
O_TRUNC         equ 0x200
O_APPEND        equ 0x400

O_RDONLY        equ 0
O_WRONLY        equ 1

EXIT_SUCCESS    equ 0
STDOUT          equ 1

CHAR_SLASH      equ 0x5C

DEBUG_LIMIT     equ 1000000


section .rodata

;Text strings
bad_jump_msg        db "Bad jump target for 6502: ",10
.len                equ $-bad_jump_msg

input_file_name     db "input.txt",0

new_line            db 10

%include "ROM_data.asm"
%include "jump_table.asm"
%include "BCD_table.asm"

section .data


section .bss

;64k memory for 6502
mem6502 resb MEM_SIZE_6502

puts_buffer     resb 2
file_handle     resq 1
file_buffer     resb FILE_BUFF_SIZE
file_ptr        resd 1
file_bytes      resd 1
slashed         resb 1
cycles_handle   resq 1
temp_buffer     resb 10
debug_counter   resq 1
debug_address   resd 1


section .text

test_func:

    ;Don't delete this
    halt

    ret

;Entry point for pure assembly
;global _start
;_start:

;Entry point if C runtime used
global main
main:

    ;call test_func
    ;jmp done.exit

    ;Setup
    call setup

    halt

    ;Load reset vector and jump
    movzx edx, word [mem6502+0xFFFC]
    mov edx, [jump_table+rdx*4]
    jmp rdx

    ;Translated 6502 code goes here
	LC000:
		;LDA 0x57 IMMED
		mov eax , 0x57
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC002:
		;STA 0x2345 ABS
		mov byte[ mem6502 + 0x2345 ] , al
		mov edx , 0x2345
	LC005:
		;LDA 0x63 IMMED
		mov eax , 0x63
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC007:
		;STA 0x2346 ABS
		mov byte[ mem6502 + 0x2346 ] , al
		mov edx , 0x2346
	LC00A:
		;LDA 0x45 IMMED
		mov eax , 0x45
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC00C:
		;STA 0x9 ZP
		mov byte[ mem6502 + 0x9 ] , al
	LC00E:
		;LDA 0x23 ZP
		movzx eax , byte[ mem6502 + 0x23 ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC010:
		;STA 0xA ZP
		mov byte[ mem6502 + 0xA ] , al
	LC012:
		;SED  IMP
		mov r12d , D_FLAG
	LC013:
		;CLC  IMP
		CLC
	LC014:
		;LDA 0x99 IMMED
		mov eax , 0x99
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC016:
		;ADC 0x99 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x99
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x99
		.done:
	LC018:
		;CLC  IMP
		CLC
	LC019:
		;LDA 0x87 IMMED
		mov eax , 0x87
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC01B:
		;ADC 0x9 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x9
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x9
		.done:
	LC01D:
		;CLC  IMP
		CLC
	LC01E:
		;LDA 0x87 IMMED
		mov eax , 0x87
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC020:
		;ADC 0x20 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x20
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x20
		.done:
	LC022:
		;CLC  IMP
		CLC
	LC023:
		;LDA 0x87 IMMED
		mov eax , 0x87
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC025:
		;ADC 0x29 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x29
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x29
		.done:
	LC027:
		;SED  IMP
		mov r12d , D_FLAG
	LC028:
		;LDA 0x0 IMMED
		mov eax , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC02A:
		;STA 0xA ZP
		mov byte[ mem6502 + 0xA ] , al
	LC02C:
		;STA 0xB ZP
		mov byte[ mem6502 + 0xB ] , al
	LC02E:
		;STA 0xC ZP
		mov byte[ mem6502 + 0xC ] , al
	LC030:
		;STA 0xD ZP
		mov byte[ mem6502 + 0xD ] , al
	LC032:
		;LDA 0xA ZP
		movzx eax , byte[ mem6502 + 0xA ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC034:
		;ORA 0xB ZP
		pushfq
		and dword [rsp], MASK_CF_FLAG|MASK_OF_FLAG
		or al , byte[ mem6502 + 0xB ]
		pushfq
		pop rdx
		or [rsp], edx
		popfq
	LC036:
		;STA 0x9 ZP
		mov byte[ mem6502 + 0x9 ] , al
	LC038:
		;LDA 0xC ZP
		movzx eax , byte[ mem6502 + 0xC ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC03A:
		;ORA 0xD ZP
		pushfq
		and dword [rsp], MASK_CF_FLAG|MASK_OF_FLAG
		or al , byte[ mem6502 + 0xD ]
		pushfq
		pop rdx
		or [rsp], edx
		popfq
	LC03C:
		;SEC  IMP
		STC
	LC03D:
		;ADC 0x9 ZP
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , byte[ mem6502 + 0x9 ]
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , byte[ mem6502 + 0x9 ]
		.done:
	LC03F:
		;INC 0xA ZP
		pushfq
		inc byte[ mem6502 + 0xA ]
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC041:
		;LDA 0xA ZP
		movzx eax , byte[ mem6502 + 0xA ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC043:
		;CMP 0xA IMMED
		pushfq
		cmp al , 0xA
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
		cmc
	LC045:
		;BCC 0xEB REL
		jnc LC032
	LC047:
		;LDA 0x0 IMMED
		mov eax , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC049:
		;STA 0xA ZP
		mov byte[ mem6502 + 0xA ] , al
	LC04B:
		;BRK  IMP
		call halt_breakpoint
		;jmp done
	LC04C:
		;CLC  IMP
		CLC
	LC04D:
		;LDA 0xB ZP
		movzx eax , byte[ mem6502 + 0xB ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC04F:
		;ADC 0x10 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x10
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x10
		.done:
	LC051:
		;STA 0xB ZP
		mov byte[ mem6502 + 0xB ] , al
	LC053:
		;BNE 0xDD REL
		jne LC032
	LC055:
		;INC 0xC ZP
		pushfq
		inc byte[ mem6502 + 0xC ]
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC057:
		;LDA 0xC ZP
		movzx eax , byte[ mem6502 + 0xC ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC059:
		;CMP 0xA IMMED
		pushfq
		cmp al , 0xA
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
		cmc
	LC05B:
		;BCC 0xD5 REL
		jnc LC032
	LC05D:
		;LDA 0x0 IMMED
		mov eax , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC05F:
		;STA 0xC ZP
		mov byte[ mem6502 + 0xC ] , al
	LC061:
		;CLC  IMP
		CLC
	LC062:
		;LDA 0xD ZP
		movzx eax , byte[ mem6502 + 0xD ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC064:
		;ADC 0x10 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x10
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x10
		.done:
	LC066:
		;STA 0xD ZP
		mov byte[ mem6502 + 0xD ] , al
	LC068:
		;BNE 0xC8 REL
		jne LC032
	LC06A:
		;SED  IMP
		mov r12d , D_FLAG
	LC06B:
		;LDA 0x0 IMMED
		mov eax , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC06D:
		;STA 0xA ZP
		mov byte[ mem6502 + 0xA ] , al
	LC06F:
		;STA 0xB ZP
		mov byte[ mem6502 + 0xB ] , al
	LC071:
		;STA 0xC ZP
		mov byte[ mem6502 + 0xC ] , al
	LC073:
		;STA 0xD ZP
		mov byte[ mem6502 + 0xD ] , al
	LC075:
		;LDA 0xA ZP
		movzx eax , byte[ mem6502 + 0xA ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC077:
		;ORA 0xB ZP
		pushfq
		and dword [rsp], MASK_CF_FLAG|MASK_OF_FLAG
		or al , byte[ mem6502 + 0xB ]
		pushfq
		pop rdx
		or [rsp], edx
		popfq
	LC079:
		;STA 0x9 ZP
		mov byte[ mem6502 + 0x9 ] , al
	LC07B:
		;LDA 0xC ZP
		movzx eax , byte[ mem6502 + 0xC ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC07D:
		;ORA 0xD ZP
		pushfq
		and dword [rsp], MASK_CF_FLAG|MASK_OF_FLAG
		or al , byte[ mem6502 + 0xD ]
		pushfq
		pop rdx
		or [rsp], edx
		popfq
	LC07F:
		;SEC  IMP
		STC
	LC080:
		;SBC 0x9 ZP
		cmc
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , byte[ mem6502 + 0x9 ]
		movzx edx , dl
		mov al , [ BCD_to_dec + rax ]
		popfq
		sbb al , [ BCD_to_dec + rdx ]
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , (256-99-1)
		jb .no_correction
		sub al , (255-99)
		or dword [rsp] , MASK_CF_FLAG
		.no_correction:
		test al , al
		jnz .not_zero
		or dword [rsp] , MASK_ZF_FLAG
		.not_zero:
		mov al , [ dec_to_BCD + rax ]
		popfq
		cmc
		jmp .done
		.no_BCD:
		popfq
		sbb al , byte[ mem6502 + 0x9 ]
		cmc
		.done:
	LC082:
		;INC 0xA ZP
		pushfq
		inc byte[ mem6502 + 0xA ]
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC084:
		;LDA 0xA ZP
		movzx eax , byte[ mem6502 + 0xA ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC086:
		;CMP 0xA IMMED
		pushfq
		cmp al , 0xA
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
		cmc
	LC088:
		;BCC 0xEB REL
		jnc LC075
	LC08A:
		;LDA 0x0 IMMED
		mov eax , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC08C:
		;STA 0xA ZP
		mov byte[ mem6502 + 0xA ] , al
	LC08E:
		;CLC  IMP
		CLC
	LC08F:
		;LDA 0xB ZP
		movzx eax , byte[ mem6502 + 0xB ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC091:
		;ADC 0x10 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x10
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x10
		.done:
	LC093:
		;STA 0xB ZP
		mov byte[ mem6502 + 0xB ] , al
	LC095:
		;BNE 0xDE REL
		jne LC075
	LC097:
		;INC 0xC ZP
		pushfq
		inc byte[ mem6502 + 0xC ]
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC099:
		;LDA 0xC ZP
		movzx eax , byte[ mem6502 + 0xC ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC09B:
		;CMP 0xA IMMED
		pushfq
		cmp al , 0xA
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
		cmc
	LC09D:
		;BCC 0xD6 REL
		jnc LC075
	LC09F:
		;LDA 0x0 IMMED
		mov eax , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC0A1:
		;STA 0xC ZP
		mov byte[ mem6502 + 0xC ] , al
	LC0A3:
		;CLC  IMP
		CLC
	LC0A4:
		;LDA 0xD ZP
		movzx eax , byte[ mem6502 + 0xD ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC0A6:
		;ADC 0x10 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x10
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x10
		.done:
	LC0A8:
		;STA 0xD ZP
		mov byte[ mem6502 + 0xD ] , al
	LC0AA:
		;BNE 0xC9 REL
		jne LC075
	LC0AC:
		;CLD  IMP
		mov r12d , 0
	LC0AD:
		;JMP 0xC0C6 JMP
		jmp LC0C6
	LC0C6:
		;LDY 0x0 IMMED
		mov ecx , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test cl , cl
		pushfq
		or [rsp], edx
		popfq
	LC0C8:
		;LDA 0xC0B0 ABSY
		movzx eax , byte [ rcx + mem6502 + 0xC0B0 ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC0CB:
		;BEQ 0x7 REL
		je LC0D4
	LC0CD:
		;STA 0xFFE7 ABS
		mov byte[ mem6502 + 0xFFE7 ] , al
		mov edx , 0xFFE7
		call peripheral_write
	LC0D0:
		;INY  IMP
		pushfq
		inc cl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC0D1:
		;JMP 0xC0C8 JMP
		jmp LC0C8
	LC0D4:
		;LDA 0x41 IMMED
		mov eax , 0x41
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC0D6:
		;STA 0xFFE7 ABS
		mov byte[ mem6502 + 0xFFE7 ] , al
		mov edx , 0xFFE7
		call peripheral_write
	LC0D9:
		;STA 0xFFE8 ABS
		mov byte[ mem6502 + 0xFFE8 ] , al
		mov edx , 0xFFE8
		call peripheral_write
	LC0DC:
		;STA 0x2345 ABS
		mov byte[ mem6502 + 0x2345 ] , al
		mov edx , 0x2345
	LC0DF:
		;LDA 0xC000 ABS
		movzx eax , byte[ mem6502 + 0xC000 ]
		mov edx, 0xC000
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC0E2:
		;LDA 0xFFF0 ABS
		movzx eax , byte[ mem6502 + 0xFFF0 ]
		mov edx, 0xFFF0
		call peripheral_read
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC0E5:
		;STA 0xFFE7 ABS
		mov byte[ mem6502 + 0xFFE7 ] , al
		mov edx , 0xFFE7
		call peripheral_write
	LC0E8:
		;BNE 0xF8 REL
		jne LC0E2
	LC0EA:
		;LDA 0x5C IMMED
		mov eax , 0x5C
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC0EC:
		;STA 0xFFE7 ABS
		mov byte[ mem6502 + 0xFFE7 ] , al
		mov edx , 0xFFE7
		call peripheral_write
	LC0EF:
		;LDA 0x6E IMMED
		mov eax , 0x6E
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC0F1:
		;STA 0xFFE7 ABS
		mov byte[ mem6502 + 0xFFE7 ] , al
		mov edx , 0xFFE7
		call peripheral_write
	LC0F4:
		;LDX 0xF IMMED
		mov ebx , 0xF
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC0F6:
		;LDA 0x1 IMMED
		mov eax , 0x1
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC0F8:
		;STA 0xFFE8 ABS
		mov byte[ mem6502 + 0xFFE8 ] , al
		mov edx , 0xFFE8
		call peripheral_write
	LC0FB:
		;CLC  IMP
		CLC
	LC0FC:
		;ADC 0x11 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x11
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x11
		.done:
	LC0FE:
		;TAY  IMP
		mov cl , al
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC0FF:
		;LDA 0x20 IMMED
		mov eax , 0x20
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC101:
		;STA 0xFFE7 ABS
		mov byte[ mem6502 + 0xFFE7 ] , al
		mov edx , 0xFFE7
		call peripheral_write
	LC104:
		;TYA  IMP
		mov al , cl
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test cl , cl
		pushfq
		or [rsp], edx
		popfq
	LC105:
		;DEX  IMP
		pushfq
		dec bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC106:
		;BNE 0xF0 REL
		jne LC0F8
	LC108:
		;LDA 0x48 IMMED
		mov eax , 0x48
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC10A:
		;STA 0xFFE7 ABS
		mov byte[ mem6502 + 0xFFE7 ] , al
		mov edx , 0xFFE7
		call peripheral_write
	LC10D:
		;LDA 0x69 IMMED
		mov eax , 0x69
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC10F:
		;STA 0xFFE7 ABS
		mov byte[ mem6502 + 0xFFE7 ] , al
		mov edx , 0xFFE7
		call peripheral_write
	LC112:
		;SEC  IMP
		STC
	LC113:
		;LDA 0x5 IMMED
		mov eax , 0x5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC115:
		;SBC 0x3 IMMED
		cmc
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x3
		movzx edx , dl
		mov al , [ BCD_to_dec + rax ]
		popfq
		sbb al , [ BCD_to_dec + rdx ]
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , (256-99-1)
		jb .no_correction
		sub al , (255-99)
		or dword [rsp] , MASK_CF_FLAG
		.no_correction:
		test al , al
		jnz .not_zero
		or dword [rsp] , MASK_ZF_FLAG
		.not_zero:
		mov al , [ dec_to_BCD + rax ]
		popfq
		cmc
		jmp .done
		.no_BCD:
		popfq
		sbb al , 0x3
		cmc
		.done:
	LC117:
		;SED  IMP
		mov r12d , D_FLAG
	LC118:
		;SEC  IMP
		STC
	LC119:
		;LDA 0x12 IMMED
		mov eax , 0x12
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC11B:
		;SBC 0x3 IMMED
		cmc
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x3
		movzx edx , dl
		mov al , [ BCD_to_dec + rax ]
		popfq
		sbb al , [ BCD_to_dec + rdx ]
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , (256-99-1)
		jb .no_correction
		sub al , (255-99)
		or dword [rsp] , MASK_CF_FLAG
		.no_correction:
		test al , al
		jnz .not_zero
		or dword [rsp] , MASK_ZF_FLAG
		.not_zero:
		mov al , [ dec_to_BCD + rax ]
		popfq
		cmc
		jmp .done
		.no_BCD:
		popfq
		sbb al , 0x3
		cmc
		.done:
	LC11D:
		;CLC  IMP
		CLC
	LC11E:
		;LDA 0x12 IMMED
		mov eax , 0x12
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC120:
		;SBC 0x3 IMMED
		cmc
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x3
		movzx edx , dl
		mov al , [ BCD_to_dec + rax ]
		popfq
		sbb al , [ BCD_to_dec + rdx ]
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , (256-99-1)
		jb .no_correction
		sub al , (255-99)
		or dword [rsp] , MASK_CF_FLAG
		.no_correction:
		test al , al
		jnz .not_zero
		or dword [rsp] , MASK_ZF_FLAG
		.not_zero:
		mov al , [ dec_to_BCD + rax ]
		popfq
		cmc
		jmp .done
		.no_BCD:
		popfq
		sbb al , 0x3
		cmc
		.done:
	LC122:
		;SEC  IMP
		STC
	LC123:
		;LDA 0x21 IMMED
		mov eax , 0x21
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC125:
		;SBC 0x32 IMMED
		cmc
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x32
		movzx edx , dl
		mov al , [ BCD_to_dec + rax ]
		popfq
		sbb al , [ BCD_to_dec + rdx ]
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , (256-99-1)
		jb .no_correction
		sub al , (255-99)
		or dword [rsp] , MASK_CF_FLAG
		.no_correction:
		test al , al
		jnz .not_zero
		or dword [rsp] , MASK_ZF_FLAG
		.not_zero:
		mov al , [ dec_to_BCD + rax ]
		popfq
		cmc
		jmp .done
		.no_BCD:
		popfq
		sbb al , 0x32
		cmc
		.done:
	LC127:
		;SEC  IMP
		STC
	LC128:
		;LDA 0x5 IMMED
		mov eax , 0x5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC12A:
		;SBC 0x5 IMMED
		cmc
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x5
		movzx edx , dl
		mov al , [ BCD_to_dec + rax ]
		popfq
		sbb al , [ BCD_to_dec + rdx ]
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , (256-99-1)
		jb .no_correction
		sub al , (255-99)
		or dword [rsp] , MASK_CF_FLAG
		.no_correction:
		test al , al
		jnz .not_zero
		or dword [rsp] , MASK_ZF_FLAG
		.not_zero:
		mov al , [ dec_to_BCD + rax ]
		popfq
		cmc
		jmp .done
		.no_BCD:
		popfq
		sbb al , 0x5
		cmc
		.done:
	LC12C:
		;CLD  IMP
		mov r12d , 0
	LC12D:
		;CLC  IMP
		CLC
	LC12E:
		;LDA 0x7F IMMED
		mov eax , 0x7F
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC130:
		;ADC 0x80 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x80
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x80
		.done:
	LC132:
		;SED  IMP
		mov r12d , D_FLAG
	LC133:
		;CLC  IMP
		CLC
	LC134:
		;LDA 0x9 IMMED
		mov eax , 0x9
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC136:
		;ADC 0x1 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x1
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x1
		.done:
	LC138:
		;SEC  IMP
		STC
	LC139:
		;LDA 0x46 IMMED
		mov eax , 0x46
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC13B:
		;ADC 0x47 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x47
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x47
		.done:
	LC13D:
		;SEC  IMP
		STC
	LC13E:
		;LDA 0x44 IMMED
		mov eax , 0x44
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC140:
		;ADC 0x55 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x55
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x55
		.done:
	LC142:
		;CLC  IMP
		CLC
	LC143:
		;LDA 0x98 IMMED
		mov eax , 0x98
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC145:
		;ADC 0x67 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x67
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x67
		.done:
	LC147:
		;CLD  IMP
		mov r12d , 0
	LC148:
		;SEC  IMP
		STC
	LC149:
		;LDA 0x55 IMMED
		mov eax , 0x55
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC14B:
		;ADC 0x55 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x55
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x55
		.done:
	LC14D:
		;SEC  IMP
		STC
	LC14E:
		;LDA 0x80 IMMED
		mov eax , 0x80
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC150:
		;STA 0x64 ZP
		mov byte[ mem6502 + 0x64 ] , al
	LC152:
		;BIT 0x64 ZP
		pushfq
		and dword [rsp] , ~(MASK_SF_FLAG|MASK_ZF_FLAG|MASK_OF_FLAG)
		movzx edx , byte[ mem6502 + 0x64 ]
		test al , dl
		jnz .no_zero
		or dword [rsp] , MASK_ZF_FLAG
		.no_zero:
		test dl , 0x80
		jns .no_negative
		or dword [rsp] , MASK_SF_FLAG
		.no_negative:
		test dl , 0x40
		je .no_bit6
		or dword [rsp] , MASK_OF_FLAG
		.no_bit6:
		popfq
	LC154:
		;LDA 0xAA IMMED
		mov eax , 0xAA
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC156:
		;STA 0x64 ZP
		mov byte[ mem6502 + 0x64 ] , al
	LC158:
		;LDA 0x55 IMMED
		mov eax , 0x55
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC15A:
		;BIT 0x64 ZP
		pushfq
		and dword [rsp] , ~(MASK_SF_FLAG|MASK_ZF_FLAG|MASK_OF_FLAG)
		movzx edx , byte[ mem6502 + 0x64 ]
		test al , dl
		jnz .no_zero
		or dword [rsp] , MASK_ZF_FLAG
		.no_zero:
		test dl , 0x80
		jns .no_negative
		or dword [rsp] , MASK_SF_FLAG
		.no_negative:
		test dl , 0x40
		je .no_bit6
		or dword [rsp] , MASK_OF_FLAG
		.no_bit6:
		popfq
	LC15C:
		;LDA 0x40 IMMED
		mov eax , 0x40
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC15E:
		;STA 0x64 ZP
		mov byte[ mem6502 + 0x64 ] , al
	LC160:
		;BIT 0x64 ZP
		pushfq
		and dword [rsp] , ~(MASK_SF_FLAG|MASK_ZF_FLAG|MASK_OF_FLAG)
		movzx edx , byte[ mem6502 + 0x64 ]
		test al , dl
		jnz .no_zero
		or dword [rsp] , MASK_ZF_FLAG
		.no_zero:
		test dl , 0x80
		jns .no_negative
		or dword [rsp] , MASK_SF_FLAG
		.no_negative:
		test dl , 0x40
		je .no_bit6
		or dword [rsp] , MASK_OF_FLAG
		.no_bit6:
		popfq
	LC162:
		;LDA 0xC0 IMMED
		mov eax , 0xC0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC164:
		;STA 0x64 ZP
		mov byte[ mem6502 + 0x64 ] , al
	LC166:
		;LDA 0x40 IMMED
		mov eax , 0x40
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC168:
		;BIT 0x64 ZP
		pushfq
		and dword [rsp] , ~(MASK_SF_FLAG|MASK_ZF_FLAG|MASK_OF_FLAG)
		movzx edx , byte[ mem6502 + 0x64 ]
		test al , dl
		jnz .no_zero
		or dword [rsp] , MASK_ZF_FLAG
		.no_zero:
		test dl , 0x80
		jns .no_negative
		or dword [rsp] , MASK_SF_FLAG
		.no_negative:
		test dl , 0x40
		je .no_bit6
		or dword [rsp] , MASK_OF_FLAG
		.no_bit6:
		popfq
	LC16A:
		;CLC  IMP
		CLC
	LC16B:
		;LDA 0xFF IMMED
		mov eax , 0xFF
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC16D:
		;PHP  IMP
		mov edx , r12d
		lea edx , [ rdx + I_FLAG ]
		jnc .no_carry
		lea edx , [ rdx + C_FLAG ]
		.no_carry:
		jnz .no_zero
		lea edx , [ rdx + Z_FLAG ]
		.no_zero:
		jno .no_overflow
		lea edx , [ rdx + V_FLAG ]
		.no_overflow:
		jns .no_negative
		lea edx , [ rdx + N_FLAG ]
		.no_negative:
		mov [ mem6502 + 0x100 + rdi ], dl
		lea edi , [ rdi - 1 ]
		movzx edi , dil
	LC16E:
		;SEC  IMP
		STC
	LC16F:
		;LDA 0x0 IMMED
		mov eax , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC171:
		;PLP  IMP
		pushfq
		pop rdx
		and edx , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		inc dil
		test byte [ mem6502 + 0x100 + rdi ] , C_FLAG
		je .no_carry
		lea edx , [ rdx + MASK_CF_FLAG ]
		.no_carry:
		test byte [ mem6502 + 0x100 + rdi ] , Z_FLAG
		je .no_zero
		lea edx , [ rdx + MASK_ZF_FLAG ]
		.no_zero:
		test byte [ mem6502 + 0x100 + rdi ] , V_FLAG
		je .no_overflow
		lea edx , [ rdx + MASK_OF_FLAG ]
		.no_overflow:
		test byte [ mem6502 + 0x100 + rdi ] , N_FLAG
		je .no_negative
		lea edx , [ rdx + MASK_SF_FLAG ]
		.no_negative:
		push rdx
		popfq
	LC172:
		;LDX 0xFF IMMED
		mov ebx , 0xFF
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC174:
		;TXS  IMP
		mov dil , bl
	LC175:
		;JSR 0xC32F ABS
		mov byte [ mem6502 + 0x100 + rdi ], 0xC1
		lea edi , [ rdi - 1 ]
		movzx edi , dil
		mov byte [ mem6502 + 0x100 + rdi ], 0x77
		lea edi , [ rdi - 1 ]
		movzx edi , dil
		jmp LC32F
	LC178:
		;LDX 0x0 IMMED
		mov ebx , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC17A:
		;TXS  IMP
		mov dil , bl
	LC17B:
		;JSR 0xC32F ABS
		mov byte [ mem6502 + 0x100 + rdi ], 0xC1
		lea edi , [ rdi - 1 ]
		movzx edi , dil
		mov byte [ mem6502 + 0x100 + rdi ], 0x7D
		lea edi , [ rdi - 1 ]
		movzx edi , dil
		jmp LC32F
	LC17E:
		;LDA 0x0 IMMED
		mov eax , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC180:
		;STA 0x14 ZP
		mov byte[ mem6502 + 0x14 ] , al
	LC182:
		;LDA 0x2 IMMED
		mov eax , 0x2
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC184:
		;STA 0x15 ZP
		mov byte[ mem6502 + 0x15 ] , al
	LC186:
		;JMP 0x14 I
		movzx edx , word [ mem6502 + 0x14 ]
		mov edx , [ jump_table + rdx * 4 ]
		jmp rdx
	LC189:
		;SEC  IMP
		STC
	LC18A:
		;LDA 0x3 IMMED
		mov eax , 0x3
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC18C:
		;STA 0x14 ZP
		mov byte[ mem6502 + 0x14 ] , al
	LC18E:
		;STA 0x4000 ABS
		mov byte[ mem6502 + 0x4000 ] , al
		mov edx , 0x4000
	LC191:
		;ROR 0x4000 ABS
		;Save V flag
		pushfq
		rcr byte[ mem6502 + 0x4000 ] , 1
		;Save C generated by shift
		pushfq
		cmp byte[ mem6502 + 0x4000 ] , 0
		;Save N and Z generated by shift
		pushfq
		pop rdx
		and edx , MASK_SF_FLAG|MASK_ZF_FLAG
		and dword [rsp], MASK_CF_FLAG
		or rdx , [rsp]
		add rsp, 8
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC194:
		;LDA 0x4000 ABS
		movzx eax , byte[ mem6502 + 0x4000 ]
		mov edx, 0x4000
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC197:
		;LDX 0x1 IMMED
		mov ebx , 0x1
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC199:
		;ROR 0x3FFF ABSX
		;Save V flag
		pushfq
		rcr byte [ rbx + mem6502 + 0x3FFF ] , 1
		;Save C generated by shift
		pushfq
		cmp byte [ rbx + mem6502 + 0x3FFF ] , 0
		;Save N and Z generated by shift
		pushfq
		pop rdx
		and edx , MASK_SF_FLAG|MASK_ZF_FLAG
		and dword [rsp], MASK_CF_FLAG
		or rdx , [rsp]
		add rsp, 8
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC19C:
		;LDA 0x4000 ABS
		movzx eax , byte[ mem6502 + 0x4000 ]
		mov edx, 0x4000
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC19F:
		;SEC  IMP
		STC
	LC1A0:
		;ROR 0x13 ZPX
		;Save V flag
		pushfq
		lea edx , [ rbx + 0x13 ]
		movzx edx , dl
		rcr byte [ mem6502 + rdx ] , 1
		;Save C generated by shift
		pushfq
		cmp byte [ mem6502 + rdx ] , 0
		;Save N and Z generated by shift
		pushfq
		pop rdx
		and edx , MASK_SF_FLAG|MASK_ZF_FLAG
		and dword [rsp], MASK_CF_FLAG
		or rdx , [rsp]
		add rsp, 8
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1A2:
		;LDA 0x14 ZP
		movzx eax , byte[ mem6502 + 0x14 ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1A4:
		;ROR 0x13 ZPX
		;Save V flag
		pushfq
		lea edx , [ rbx + 0x13 ]
		movzx edx , dl
		rcr byte [ mem6502 + rdx ] , 1
		;Save C generated by shift
		pushfq
		cmp byte [ mem6502 + rdx ] , 0
		;Save N and Z generated by shift
		pushfq
		pop rdx
		and edx , MASK_SF_FLAG|MASK_ZF_FLAG
		and dword [rsp], MASK_CF_FLAG
		or rdx , [rsp]
		add rsp, 8
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1A6:
		;LDA 0x14 ZP
		movzx eax , byte[ mem6502 + 0x14 ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1A8:
		;CLC  IMP
		CLC
	LC1A9:
		;LDX 0x15 IMMED
		mov ebx , 0x15
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC1AB:
		;LDA 0x3 IMMED
		mov eax , 0x3
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1AD:
		;STA 0x14 ZP
		mov byte[ mem6502 + 0x14 ] , al
	LC1AF:
		;ROR 0xFF ZPX
		;Save V flag
		pushfq
		lea edx , [ rbx + 0xFF ]
		movzx edx , dl
		rcr byte [ mem6502 + rdx ] , 1
		;Save C generated by shift
		pushfq
		cmp byte [ mem6502 + rdx ] , 0
		;Save N and Z generated by shift
		pushfq
		pop rdx
		and edx , MASK_SF_FLAG|MASK_ZF_FLAG
		and dword [rsp], MASK_CF_FLAG
		or rdx , [rsp]
		add rsp, 8
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1B1:
		;ROR 0xFF ZPX
		;Save V flag
		pushfq
		lea edx , [ rbx + 0xFF ]
		movzx edx , dl
		rcr byte [ mem6502 + rdx ] , 1
		;Save C generated by shift
		pushfq
		cmp byte [ mem6502 + rdx ] , 0
		;Save N and Z generated by shift
		pushfq
		pop rdx
		and edx , MASK_SF_FLAG|MASK_ZF_FLAG
		and dword [rsp], MASK_CF_FLAG
		or rdx , [rsp]
		add rsp, 8
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1B3:
		;ROR 0xFF ZPX
		;Save V flag
		pushfq
		lea edx , [ rbx + 0xFF ]
		movzx edx , dl
		rcr byte [ mem6502 + rdx ] , 1
		;Save C generated by shift
		pushfq
		cmp byte [ mem6502 + rdx ] , 0
		;Save N and Z generated by shift
		pushfq
		pop rdx
		and edx , MASK_SF_FLAG|MASK_ZF_FLAG
		and dword [rsp], MASK_CF_FLAG
		or rdx , [rsp]
		add rsp, 8
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1B5:
		;SEC  IMP
		STC
	LC1B6:
		;LDA 0x3 IMMED
		mov eax , 0x3
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1B8:
		;ROR  A
		;Save V flag
		pushfq
		rcr al , 1
		;Save C generated by shift
		pushfq
		test al , al
		;Save N and Z generated by shift
		pushfq
		pop rdx
		and edx , MASK_SF_FLAG|MASK_ZF_FLAG
		and dword [rsp], MASK_CF_FLAG
		or rdx , [rsp]
		add rsp, 8
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1B9:
		;ROR  A
		;Save V flag
		pushfq
		rcr al , 1
		;Save C generated by shift
		pushfq
		test al , al
		;Save N and Z generated by shift
		pushfq
		pop rdx
		and edx , MASK_SF_FLAG|MASK_ZF_FLAG
		and dword [rsp], MASK_CF_FLAG
		or rdx , [rsp]
		add rsp, 8
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1BA:
		;ROR  A
		;Save V flag
		pushfq
		rcr al , 1
		;Save C generated by shift
		pushfq
		test al , al
		;Save N and Z generated by shift
		pushfq
		pop rdx
		and edx , MASK_SF_FLAG|MASK_ZF_FLAG
		and dword [rsp], MASK_CF_FLAG
		or rdx , [rsp]
		add rsp, 8
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1BB:
		;ROR  A
		;Save V flag
		pushfq
		rcr al , 1
		;Save C generated by shift
		pushfq
		test al , al
		;Save N and Z generated by shift
		pushfq
		pop rdx
		and edx , MASK_SF_FLAG|MASK_ZF_FLAG
		and dword [rsp], MASK_CF_FLAG
		or rdx , [rsp]
		add rsp, 8
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1BC:
		;SEC  IMP
		STC
	LC1BD:
		;LDA 0xC0 IMMED
		mov eax , 0xC0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1BF:
		;ROL  A
		;Save V flag
		pushfq
		rcl al , 1
		;Save C generated by shift
		pushfq
		test al , al
		;Save N and Z generated by shift
		pushfq
		pop rdx
		and edx , MASK_SF_FLAG|MASK_ZF_FLAG
		and dword [rsp], MASK_CF_FLAG
		or rdx , [rsp]
		add rsp, 8
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1C0:
		;ROL  A
		;Save V flag
		pushfq
		rcl al , 1
		;Save C generated by shift
		pushfq
		test al , al
		;Save N and Z generated by shift
		pushfq
		pop rdx
		and edx , MASK_SF_FLAG|MASK_ZF_FLAG
		and dword [rsp], MASK_CF_FLAG
		or rdx , [rsp]
		add rsp, 8
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1C1:
		;ROL  A
		;Save V flag
		pushfq
		rcl al , 1
		;Save C generated by shift
		pushfq
		test al , al
		;Save N and Z generated by shift
		pushfq
		pop rdx
		and edx , MASK_SF_FLAG|MASK_ZF_FLAG
		and dword [rsp], MASK_CF_FLAG
		or rdx , [rsp]
		add rsp, 8
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1C2:
		;SEC  IMP
		STC
	LC1C3:
		;LDA 0x80 IMMED
		mov eax , 0x80
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1C5:
		;LSR  A
		pushfq
		shr al , 1
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1C6:
		;CLC  IMP
		CLC
	LC1C7:
		;LDA 0x3 IMMED
		mov eax , 0x3
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1C9:
		;LSR  A
		pushfq
		shr al , 1
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1CA:
		;LSR  A
		pushfq
		shr al , 1
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1CB:
		;LSR  A
		pushfq
		shr al , 1
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1CC:
		;LDA 0x3 IMMED
		mov eax , 0x3
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1CE:
		;STA 0x15 ZP
		mov byte[ mem6502 + 0x15 ] , al
	LC1D0:
		;LSR 0x15 ZP
		pushfq
		shr byte[ mem6502 + 0x15 ] , 1
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1D2:
		;LSR 0x15 ZP
		pushfq
		shr byte[ mem6502 + 0x15 ] , 1
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1D4:
		;LDA 0x15 ZP
		movzx eax , byte[ mem6502 + 0x15 ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1D6:
		;LDA 0x3 IMMED
		mov eax , 0x3
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1D8:
		;STA 0x15 ZP
		mov byte[ mem6502 + 0x15 ] , al
	LC1DA:
		;LDX 0x5 IMMED
		mov ebx , 0x5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC1DC:
		;LSR 0x15 ZP
		pushfq
		shr byte[ mem6502 + 0x15 ] , 1
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1DE:
		;LSR 0x10 ZPX
		pushfq
		lea edx , [ rbx + 0x10 ]
		movzx edx , dl
		shr byte [ mem6502 + rdx ] , 1
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1E0:
		;LDA 0x15 ZP
		movzx eax , byte[ mem6502 + 0x15 ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1E2:
		;CLC  IMP
		CLC
	LC1E3:
		;LDA 0xC0 IMMED
		mov eax , 0xC0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1E5:
		;ASL  A
		pushfq
		shl al , 1
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1E6:
		;ASL  A
		pushfq
		shl al , 1
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1E7:
		;ASL  A
		pushfq
		shl al , 1
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1E8:
		;LDA 0xC0 IMMED
		mov eax , 0xC0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1EA:
		;STA 0x14 ZP
		mov byte[ mem6502 + 0x14 ] , al
	LC1EC:
		;ASL 0x14 ZP
		pushfq
		shl byte[ mem6502 + 0x14 ] , 1
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1EE:
		;LDA 0x14 ZP
		movzx eax , byte[ mem6502 + 0x14 ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1F0:
		;LDX 0x5 IMMED
		mov ebx , 0x5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC1F2:
		;ASL 0xF ZPX
		pushfq
		lea edx , [ rbx + 0xF ]
		movzx edx , dl
		shl byte [ mem6502 + rdx ] , 1
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1F4:
		;LDA 0x14 ZP
		movzx eax , byte[ mem6502 + 0x14 ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC1F6:
		;LDX 0x0 IMMED
		mov ebx , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC1F8:
		;JMP 0xC1FC JMP
		jmp LC1FC
	LC1FB:
		;INX  IMP
		pushfq
		inc bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC1FC:
		;LDX 0x0 IMMED
		mov ebx , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC1FE:
		;CLV  IMP
		pushfq
		and qword [rsp], ~MASK_OF_FLAG
		popfq
	LC1FF:
		;BVC 0x1 REL
		jno LC202
	LC201:
		;INX  IMP
		pushfq
		inc bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC202:
		;CLC  IMP
		CLC
	LC203:
		;LDA 0x5 IMMED
		mov eax , 0x5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC205:
		;SBC 0x80 IMMED
		cmc
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x80
		movzx edx , dl
		mov al , [ BCD_to_dec + rax ]
		popfq
		sbb al , [ BCD_to_dec + rdx ]
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , (256-99-1)
		jb .no_correction
		sub al , (255-99)
		or dword [rsp] , MASK_CF_FLAG
		.no_correction:
		test al , al
		jnz .not_zero
		or dword [rsp] , MASK_ZF_FLAG
		.not_zero:
		mov al , [ dec_to_BCD + rax ]
		popfq
		cmc
		jmp .done
		.no_BCD:
		popfq
		sbb al , 0x80
		cmc
		.done:
	LC207:
		;BVS 0x1 REL
		jo LC20A
	LC209:
		;INX  IMP
		pushfq
		inc bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC20A:
		;LDX 0x0 IMMED
		mov ebx , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC20C:
		;LDA 0x0 IMMED
		mov eax , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC20E:
		;BEQ 0x1 REL
		je LC211
	LC210:
		;INX  IMP
		pushfq
		inc bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC211:
		;LDA 0x1 IMMED
		mov eax , 0x1
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC213:
		;BNE 0x1 REL
		jne LC216
	LC215:
		;INX  IMP
		pushfq
		inc bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC216:
		;LDX 0x0 IMMED
		mov ebx , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC218:
		;LDA 0x80 IMMED
		mov eax , 0x80
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC21A:
		;BMI 0x1 REL
		js LC21D
	LC21C:
		;INX  IMP
		pushfq
		inc bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC21D:
		;LDA 0x0 IMMED
		mov eax , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC21F:
		;BPL 0x1 REL
		jns LC222
	LC221:
		;INX  IMP
		pushfq
		inc bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC222:
		;LDX 0x0 IMMED
		mov ebx , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC224:
		;SEC  IMP
		STC
	LC225:
		;BCS 0x1 REL
		jc LC228
	LC227:
		;INX  IMP
		pushfq
		inc bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC228:
		;CLC  IMP
		CLC
	LC229:
		;BCC 0x1 REL
		jnc LC22C
	LC22B:
		;INX  IMP
		pushfq
		inc bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC22C:
		;LDX 0xFF IMMED
		mov ebx , 0xFF
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC22E:
		;TXS  IMP
		mov dil , bl
	LC22F:
		;LDA 0x80 IMMED
		mov eax , 0x80
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC231:
		;PHA  IMP
		mov [ mem6502 + 0x100 + rdi ], al
		pushfq
		dec dil
		popfq
	LC232:
		;LDA 0x0 IMMED
		mov eax , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC234:
		;LDA 0x1FF ABS
		movzx eax , byte[ mem6502 + 0x1FF ]
		mov edx, 0x1FF
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC237:
		;SEC  IMP
		STC
	LC238:
		;TSX  IMP
		mov bl , dil
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test dil , dil
		pushfq
		or [rsp], edx
		popfq
	LC239:
		;PLA  IMP
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		inc dil
		mov al , [ mem6502 + 0x100 + rdi ]
		test al , al
		pushfq
		or [rsp], rdx
		popfq
	LC23A:
		;LDA 0x80 IMMED
		mov eax , 0x80
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC23C:
		;TAY  IMP
		mov cl , al
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC23D:
		;LDA 0x0 IMMED
		mov eax , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC23F:
		;TYA  IMP
		mov al , cl
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test cl , cl
		pushfq
		or [rsp], edx
		popfq
	LC240:
		;LDX 0x9 IMMED
		mov ebx , 0x9
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC242:
		;TXS  IMP
		mov dil , bl
	LC243:
		;LDX 0x0 IMMED
		mov ebx , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC245:
		;TSX  IMP
		mov bl , dil
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test dil , dil
		pushfq
		or [rsp], edx
		popfq
	LC246:
		;LDA 0x5 IMMED
		mov eax , 0x5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC248:
		;TAX  IMP
		mov bl , al
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC249:
		;LDA 0x7 IMMED
		mov eax , 0x7
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC24B:
		;TAY  IMP
		mov cl , al
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC24C:
		;TXA  IMP
		mov al , bl
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC24D:
		;TYA  IMP
		mov al , cl
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test cl , cl
		pushfq
		or [rsp], edx
		popfq
	LC24E:
		;LDA 0x5 IMMED
		mov eax , 0x5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC250:
		;SBC 0x80 IMMED
		cmc
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x80
		movzx edx , dl
		mov al , [ BCD_to_dec + rax ]
		popfq
		sbb al , [ BCD_to_dec + rdx ]
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , (256-99-1)
		jb .no_correction
		sub al , (255-99)
		or dword [rsp] , MASK_CF_FLAG
		.no_correction:
		test al , al
		jnz .not_zero
		or dword [rsp] , MASK_ZF_FLAG
		.not_zero:
		mov al , [ dec_to_BCD + rax ]
		popfq
		cmc
		jmp .done
		.no_BCD:
		popfq
		sbb al , 0x80
		cmc
		.done:
	LC252:
		;SEC  IMP
		STC
	LC253:
		;CLV  IMP
		pushfq
		and qword [rsp], ~MASK_OF_FLAG
		popfq
	LC254:
		;CLC  IMP
		CLC
	LC255:
		;LDA 0x20 IMMED
		mov eax , 0x20
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC257:
		;STA 0x2000 ABS
		mov byte[ mem6502 + 0x2000 ] , al
		mov edx , 0x2000
	LC25A:
		;ADC 0x1 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x1
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x1
		.done:
	LC25C:
		;LDX 0x2 IMMED
		mov ebx , 0x2
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC25E:
		;STA 0x1FFF ABSX
		mov byte [ rbx + mem6502 + 0x1FFF ] , al
	LC261:
		;ADC 0x1 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x1
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x1
		.done:
	LC263:
		;LDY 0x4 IMMED
		mov ecx , 0x4
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test cl , cl
		pushfq
		or [rsp], edx
		popfq
	LC265:
		;STA 0x1FFE ABSY
		mov byte [ rcx + mem6502 + 0x1FFE ] , al
	LC268:
		;LDA 0x2000 ABS
		movzx eax , byte[ mem6502 + 0x2000 ]
		mov edx, 0x2000
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC26B:
		;LDA 0x2001 ABS
		movzx eax , byte[ mem6502 + 0x2001 ]
		mov edx, 0x2001
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC26E:
		;LDA 0x2002 ABS
		movzx eax , byte[ mem6502 + 0x2002 ]
		mov edx, 0x2002
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC271:
		;LDA 0x7 IMMED
		mov eax , 0x7
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC273:
		;CLC  IMP
		CLC
	LC274:
		;LDA 0x2345 ABS
		movzx eax , byte[ mem6502 + 0x2345 ]
		mov edx, 0x2345
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC277:
		;INC 0x2345 ABS
		pushfq
		inc byte[ mem6502 + 0x2345 ]
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC27A:
		;LDA 0x2345 ABS
		movzx eax , byte[ mem6502 + 0x2345 ]
		mov edx, 0x2345
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC27D:
		;LDX 0x4 IMMED
		mov ebx , 0x4
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC27F:
		;INC 0x2341 ABSX
		pushfq
		inc byte [ rbx + mem6502 + 0x2341 ]
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC282:
		;LDA 0x2345 ABS
		movzx eax , byte[ mem6502 + 0x2345 ]
		mov edx, 0x2345
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC285:
		;LDX 0x3 IMMED
		mov ebx , 0x3
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC287:
		;DEC 0x2342 ABSX
		pushfq
		dec byte [ rbx + mem6502 + 0x2342 ]
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC28A:
		;DEC 0x2342 ABSX
		pushfq
		dec byte [ rbx + mem6502 + 0x2342 ]
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC28D:
		;LDA 0x2345 ABS
		movzx eax , byte[ mem6502 + 0x2345 ]
		mov edx, 0x2345
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC290:
		;LDX 0xFE IMMED
		mov ebx , 0xFE
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC292:
		;INX  IMP
		pushfq
		inc bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC293:
		;INX  IMP
		pushfq
		inc bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC294:
		;INX  IMP
		pushfq
		inc bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC295:
		;DEX  IMP
		pushfq
		dec bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC296:
		;DEX  IMP
		pushfq
		dec bl
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
	LC297:
		;LDA 0x5 IMMED
		mov eax , 0x5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC299:
		;CMP 0x7 IMMED
		pushfq
		cmp al , 0x7
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
		cmc
	LC29B:
		;CMP 0x3 IMMED
		pushfq
		cmp al , 0x3
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
		cmc
	LC29D:
		;LDX 0x5 IMMED
		mov ebx , 0x5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC29F:
		;CPX 0x7 IMMED
		pushfq
		cmp bl , 0x7
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
		cmc
	LC2A1:
		;CPX 0x3 IMMED
		pushfq
		cmp bl , 0x3
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
		cmc
	LC2A3:
		;LDY 0x5 IMMED
		mov ecx , 0x5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test cl , cl
		pushfq
		or [rsp], edx
		popfq
	LC2A5:
		;CPY 0x7 IMMED
		pushfq
		cmp cl , 0x7
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
		cmc
	LC2A7:
		;CPY 0x3 IMMED
		pushfq
		cmp cl , 0x3
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
		cmc
	LC2A9:
		;LDA 0x5 IMMED
		mov eax , 0x5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2AB:
		;CMP 0x80 IMMED
		pushfq
		cmp al , 0x80
		pushfq
		pop rdx
		and edx , ~MASK_OF_FLAG
		and dword [rsp], MASK_OF_FLAG
		or [rsp], edx
		popfq
		cmc
	LC2AD:
		;SEC  IMP
		STC
	LC2AE:
		;LDA 0xA5 IMMED
		mov eax , 0xA5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2B0:
		;ORA 0x55 IMMED
		pushfq
		and dword [rsp], MASK_CF_FLAG|MASK_OF_FLAG
		or al , 0x55
		pushfq
		pop rdx
		or [rsp], edx
		popfq
	LC2B2:
		;LDA 0xA5 IMMED
		mov eax , 0xA5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2B4:
		;EOR 0x55 IMMED
		pushfq
		and dword [rsp], MASK_CF_FLAG|MASK_OF_FLAG
		xor al , 0x55
		pushfq
		pop rdx
		or [rsp], edx
		popfq
	LC2B6:
		;SEC  IMP
		STC
	LC2B7:
		;LDA 0xA5 IMMED
		mov eax , 0xA5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2B9:
		;AND 0x55 IMMED
		pushfq
		and dword [rsp], MASK_CF_FLAG|MASK_OF_FLAG
		and al , 0x55
		pushfq
		pop rdx
		or [rsp], edx
		popfq
	LC2BB:
		;LDA 0xFF IMMED
		mov eax , 0xFF
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2BD:
		;AND 0x7F IMMED
		pushfq
		and dword [rsp], MASK_CF_FLAG|MASK_OF_FLAG
		and al , 0x7F
		pushfq
		pop rdx
		or [rsp], edx
		popfq
	LC2BF:
		;LDA 0xFF IMMED
		mov eax , 0xFF
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2C1:
		;AND 0x80 IMMED
		pushfq
		and dword [rsp], MASK_CF_FLAG|MASK_OF_FLAG
		and al , 0x80
		pushfq
		pop rdx
		or [rsp], edx
		popfq
	LC2C3:
		;CLC  IMP
		CLC
	LC2C4:
		;LDA 0xFF IMMED
		mov eax , 0xFF
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2C6:
		;AND 0x7F IMMED
		pushfq
		and dword [rsp], MASK_CF_FLAG|MASK_OF_FLAG
		and al , 0x7F
		pushfq
		pop rdx
		or [rsp], edx
		popfq
	LC2C8:
		;LDA 0x2345 ABS
		movzx eax , byte[ mem6502 + 0x2345 ]
		mov edx, 0x2345
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2CB:
		;LDA 0x2346 ABS
		movzx eax , byte[ mem6502 + 0x2346 ]
		mov edx, 0x2346
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2CE:
		;LDA 0x9 ZP
		movzx eax , byte[ mem6502 + 0x9 ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2D0:
		;LDA 0xA ZP
		movzx eax , byte[ mem6502 + 0xA ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2D2:
		;LDA 0xEE IMMED
		mov eax , 0xEE
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2D4:
		;LDY 0x0 IMMED
		mov ecx , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test cl , cl
		pushfq
		or [rsp], edx
		popfq
	LC2D6:
		;AND 0x9 IY
		pushfq
		and dword [rsp], MASK_CF_FLAG|MASK_OF_FLAG
		movzx edx , word [ mem6502 + 0x9 ]
		and al , byte [ mem6502 + rcx + rdx ]
		pushfq
		pop rdx
		or [rsp], edx
		popfq
	LC2D8:
		;CLC  IMP
		CLC
	LC2D9:
		;LDA 0x7 IMMED
		mov eax , 0x7
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2DB:
		;LDY 0x1 IMMED
		mov ecx , 0x1
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test cl , cl
		pushfq
		or [rsp], edx
		popfq
	LC2DD:
		;ADC 0x9 IY
		pushfq
		test r12d , r12d
		je .no_BCD
		movzx edx , word [ mem6502 + 0x9 ]
		mov dl , byte [ mem6502 + rcx + rdx ]
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		movzx edx , word [ mem6502 + 0x9 ]
		adc al , byte [ mem6502 + rcx + rdx ]
		.done:
	LC2DF:
		;ADC 0x9 ZP
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , byte[ mem6502 + 0x9 ]
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , byte[ mem6502 + 0x9 ]
		.done:
	LC2E1:
		;ADC 0x2345 ABS
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , byte[ mem6502 + 0x2345 ]
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , byte[ mem6502 + 0x2345 ]
		.done:
	LC2E4:
		;LDA 0x9 IMMED
		mov eax , 0x9
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2E6:
		;LDX 0x6 IMMED
		mov ebx , 0x6
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC2E8:
		;ADC 0x3 IX
		pushfq
		test r12d , r12d
		je .no_BCD
		lea edx , [ rbx + 0x3 ]
		movzx edx , dl
		movzx edx , word [ mem6502 + rdx ]
		mov dl , byte [ mem6502 + rdx ]
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		lea edx , [ rbx + 0x3 ]
		movzx edx , dl
		movzx edx , word [ mem6502 + rdx ]
		adc al , byte [ mem6502 + rdx ]
		.done:
	LC2EA:
		;LDY 0x0 IMMED
		mov ecx , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test cl , cl
		pushfq
		or [rsp], edx
		popfq
	LC2EC:
		;LDA 0x9 IY
		movzx edx , word [ mem6502 + 0x9 ]
		movzx eax , byte [ mem6502 + rcx + rdx ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2EE:
		;LDY 0x1 IMMED
		mov ecx , 0x1
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test cl , cl
		pushfq
		or [rsp], edx
		popfq
	LC2F0:
		;LDA 0x9 IY
		movzx edx , word [ mem6502 + 0x9 ]
		movzx eax , byte [ mem6502 + rcx + rdx ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2F2:
		;LDX 0x6 IMMED
		mov ebx , 0x6
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC2F4:
		;LDA 0x3 IX
		lea edx , [ rbx + 0x3 ]
		movzx edx , dl
		movzx edx , word [ mem6502 + rdx ]
		movzx eax , byte [ mem6502 + rdx ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2F6:
		;LDX 0xFF IMMED
		mov ebx , 0xFF
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC2F8:
		;LDA 0xA IX
		lea edx , [ rbx + 0xA ]
		movzx edx , dl
		movzx edx , word [ mem6502 + rdx ]
		movzx eax , byte [ mem6502 + rdx ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2FA:
		;SEC  IMP
		STC
	LC2FB:
		;CLC  IMP
		CLC
	LC2FC:
		;SEC  IMP
		STC
	LC2FD:
		;LDA 0x5 IMMED
		mov eax , 0x5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC2FF:
		;CLC  IMP
		CLC
	LC300:
		;ADC 0x7 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x7
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x7
		.done:
	LC302:
		;LDA 0xFF IMMED
		mov eax , 0xFF
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC304:
		;ADC 0x1 IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0x1
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0x1
		.done:
	LC306:
		;LDA 0xFF IMMED
		mov eax , 0xFF
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC308:
		;ADC 0xFF IMMED
		pushfq
		test r12d , r12d
		je .no_BCD
		mov dl , 0xFF
		movzx edx , dl
		mov ah , al
		mov dh , dl
		and eax , 0xF00F
		and edx , 0xF00F
		popfq
		adc eax , edx
		pushfq
		and dword [rsp] , ~(MASK_CF_FLAG|MASK_OF_FLAG|MASK_SF_FLAG|MASK_ZF_FLAG)
		cmp al , 10
		jb .no_low_correction
		add eax , 6
		.no_low_correction:
		mov edx , eax
		movzx eax , al
		shr edx , 8
		add eax , edx
		cmp eax , 0xA0
		jb .no_high_correction
		add eax , 0x60
		.no_high_correction:
		cmp eax , 0x100
		jb .no_carry
		sub eax , 0x100
		or dword [rsp] , MASK_CF_FLAG
		.no_carry:
		popfq
		jmp .done
		.no_BCD:
		popfq
		adc al , 0xFF
		.done:
	LC30A:
		;LDA 0x5 IMMED
		mov eax , 0x5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC30C:
		;LDA 0x7F IMMED
		mov eax , 0x7F
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC30E:
		;LDA 0x80 IMMED
		mov eax , 0x80
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC310:
		;LDA 0x0 IMMED
		mov eax , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC312:
		;LDA 0x23 ZP
		movzx eax , byte[ mem6502 + 0x23 ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC314:
		;LDA 0x3456 ABS
		movzx eax , byte[ mem6502 + 0x3456 ]
		mov edx, 0x3456
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC317:
		;LDA 0x23 ZPX
		lea edx , [ rbx + 0x23 ]
		movzx edx , dl
		movzx eax , byte [ mem6502 + rdx ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC319:
		;LDA 0x3456 ABSX
		movzx eax , byte [ rbx + mem6502 + 0x3456 ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC31C:
		;LDA 0x3456 ABSY
		movzx eax , byte [ rcx + mem6502 + 0x3456 ]
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test al , al
		pushfq
		or [rsp], edx
		popfq
	LC31F:
		;LDX 0x0 IMMED
		mov ebx , 0x0
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC321:
		;LDX 0x7F IMMED
		mov ebx , 0x7F
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC323:
		;LDX 0xFF IMMED
		mov ebx , 0xFF
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC325:
		;LDY 0x56 IMMED
		mov ecx , 0x56
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test cl , cl
		pushfq
		or [rsp], edx
		popfq
	LC327:
		;STA 0xFFF1 ABS
		mov byte[ mem6502 + 0xFFF1 ] , al
		mov edx , 0xFFF1
		call peripheral_write
	LC32A:
		;BRK  IMP
		call halt_breakpoint
		;jmp done
	LC32B:
		;BRK  IMP
		call halt_breakpoint
		;jmp done
	LC32C:
		;JMP 0xC000 JMP
		jmp LC000
	LC32F:
		;LDX 0x5 IMMED
		mov ebx , 0x5
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	LC331:
		;RTS  IMP
		lea edi , [ rdi + 1 ]
		movzx edi , dil
		movzx edx , byte [ mem6502 + 0x100 + rdi ]
		lea edi , [ rdi + 1 ]
		movzx edi , dil
		mov dh , [ mem6502 + 0x100 + rdi ]
		lea edx , [ jump_table + rdx * 4 + 4 ]
		mov edx , [ rdx ]
		jmp rdx
	L0200:
		;LDX 0x77 IMMED
		mov ebx , 0x77
		pushfq
		pop rdx
		and edx , MASK_CF_FLAG|MASK_OF_FLAG
		test bl , bl
		pushfq
		or [rsp], edx
		popfq
	L0202:
		;JMP 0xC189 JMP
		jmp LC189

done:
    mov rax, SYS_close
    mov rdi, [file_handle]
    syscall

    .exit:
    mov rax, SYS_write
    mov rdi, STDOUT
    mov rsi, new_line 
    mov rdx, 1
    syscall

    mov rax, SYS_exit
    mov rdi, EXIT_SUCCESS
    syscall

setup:

    ;Copy ROM to memory
    mov ebx, ROM_data
    .loop:
        mov ecx, [rbx]
        cmp ecx, 0
        je .done
        mov edi, [rbx+4]
        lea ebx, [rbx+8]
        .loop_inner:
            movzx eax, byte [rbx]
            mov [mem6502 + rdi], al
            inc ebx
            inc rdi
            loop .loop_inner
        jmp .loop
    .done:

    ;Initialize variables for reading files
    mov dword [file_bytes], 0
    
    ;Open input file
    mov rax, SYS_open
    mov rdi, input_file_name
    mov rsi, O_RDONLY
    syscall
    mov qword [file_handle], rax

    ;Initialize other variables
    mov byte [slashed], false

    ;Initialize 6502 registers
    xor eax,eax     ;A
    xor ebx,ebx     ;X
    xor ecx,ecx     ;Y
    mov edi,0xFF    ;SP
    xor r12,r12     ;D flag

    ret

;Jump here if 6502 tries to jump to invalid address
bad_jump:
    mov rax, SYS_write
    mov rdi, STDOUT
    mov rsi, bad_jump_msg
    mov rdx, bad_jump_msg.len
    syscall

    ;TODO: add separate bad_jump vector for each address

    ;mov edx, [debug_address]
    ;movzx edx, dl
    ;call debug_hex_char
    ;mov [temp_buffer+3], dl
    ;mov [temp_buffer+2], dh

    ;movzx edx, byte [debug_address]
    ;call debug_hex_char
    ;mov [temp_buffer+1], dl
    ;mov [temp_buffer+0], dh
    
    ;mov rax, SYS_write
    ;mov rdi, STDOUT
    ;mov rsi, temp_buffer
    ;mov rdx, 4
    ;syscall

    jmp done

;edx - address
peripheral_read:
    pushfq
    cmp edx, FILE_INPUT
    jne .done
        cmp dword [file_bytes], 0
        jne .fetch_byte
            push_regs
            mov rax, SYS_read
            mov rdi, qword [file_handle]
            mov rsi, file_buffer
            mov rdx, FILE_BUFF_SIZE
            syscall
            mov [file_bytes], eax
            mov dword [file_ptr], file_buffer
            pull_regs
        
        xor eax, eax
        cmp dword [file_bytes], 0
        je .no_bytes
            .fetch_byte:
            ;Fetch one byte
            mov edx, [file_ptr]
            movzx eax, byte [rdx]
            ;halt
            inc dword [file_ptr]
            dec dword [file_bytes] 
        .no_bytes:
    .done:
    popfq
    ret

;eax - A register
;edx - address
peripheral_write:
    pushfq
    cmp edx, PERIPHERALS
    jb .done
        .debug:
        cmp edx, DEBUG
        jne .debug_hex
            ;DEBUG

            push_regs
            cmp byte [slashed], false
            je .not_slashed
                
                ;Skipping for now
                ;jmp .not_slashed

                ;Slashed input - ie \n
                cmp al, CHAR_SLASH
                jne .not_slash
                    mov byte [puts_buffer], CHAR_SLASH
                    jmp .slashed_done
                .not_slash:
                cmp al, 'n'
                jne .not_new_line
                    mov byte [puts_buffer], 10
                    jmp .slashed_done
                .not_new_line:
                
                ;Unrecognized slash
                mov byte [slashed], false
                jmp .debug_hex_done

                .slashed_done:
                mov byte [slashed], false
                jmp .print
            .not_slashed:
            
            cmp al, CHAR_SLASH
            jne .not_enable_slashed
                mov byte [slashed], true
                jmp .debug_hex_done
            .not_enable_slashed:
            mov [puts_buffer], al
            
            ;Does not work in gdb :/
            ;mov byte [puts_buffer+1], 0
            ;mov rdi, puts_buffer
            ;call puts
           
            .print:
            mov rax, SYS_write
            mov rdi, STDOUT
            mov rsi, puts_buffer
            mov rdx, 1
            syscall
            
            .debug_hex_done:
            pull_regs
            jmp .done
        .debug_hex:
        cmp edx, DEBUG_HEX
        jne .exit
            push_regs

            mov ecx, eax
            and ecx, 0xF
            cmp ecx, 0xA
            jae .letter_low
                add ecx, '0'
                jmp .low_done
            .letter_low:
                sub ecx, 0xA
                add ecx, 'A'
            .low_done:
            mov [puts_buffer+1], cl
            
            mov ecx, eax
            shr ecx, 4
            cmp ecx, 0xA
            jae .letter_hi
                add ecx, '0'
                jmp .hi_done
            .letter_hi:
                sub ecx, 0xA
                add ecx, 'A'
            .hi_done:
            mov [puts_buffer], cl
            
            mov rax, SYS_write
            mov rdi, STDOUT
            mov rsi, puts_buffer
            mov rdx, 2
            syscall
            
            pull_regs
            jmp .done
        .exit:
        cmp edx, PROG_EXIT
        jne .unhandled
            ;PROG_EXIT
            jmp done
        .unhandled:
            halt

    .done:
    popfq
    ret

halt_breakpoint:
    ret

