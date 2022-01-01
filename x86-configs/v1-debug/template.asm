
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

%macro debug_prefix 1
    mov r10, %1
    call debug_func
%endmacro

%macro debug_postfix 1
    mov r10, %1
    call debug_func
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

cycles_file_name    db "cycles.txt",0
cycles_msg_1        db "Cycle counts for 6502 (x86 conversion):",10
.len                equ $-cycles_msg_1

new_line            db 10

%include "ROM_data.asm"
%include "jump_table.asm"
%include "BCD_table.asm"

section .data

debug_buffer        db "XXXX A:00 X:00 Y:00 SP:00 CNVZ",10
.len                equ $-debug_buffer


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

    xor edx, edx
    stc
    mov eax, 0xAB
    mov ebx, 0xCD
    mov ecx, 0xEF
    debug_postfix 0xC001
    
    xor edx, edx
    dec edx
    mov eax, 0xAB
    mov ebx, 0xCD
    mov ecx, 0xEF
    debug_postfix 0xC002

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
    call debug_setup
    call setup

    halt

    ;Load reset vector and jump
    movzx edx, word [mem6502+0xFFFC]
    mov edx, [jump_table+rdx*4]
    jmp rdx

    ;Translated 6502 code goes here
    %code

done:
    mov rax, SYS_close
    mov rdi, [file_handle]
    syscall

    mov rax, SYS_close
    mov rdi, [cycles_handle]
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
    
    halt

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

    mov edx, [debug_address]
    movzx edx, dl
    call debug_hex_char
    mov [temp_buffer+3], dl
    mov [temp_buffer+2], dh

    movzx edx, byte [debug_address]
    call debug_hex_char
    mov [temp_buffer+1], dl
    mov [temp_buffer+0], dh
    
    mov rax, SYS_write
    mov rdi, STDOUT
    mov rsi, temp_buffer
    mov rdx, 4
    syscall

    jmp done

;edx - address
peripheral_read:
    halt
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


;Debug functions
;===============
debug_setup:

    ;Debugging files
    mov rax, SYS_open
    mov rdi, cycles_file_name
    mov rsi, O_CREAT|O_WRONLY|O_TRUNC
    mov rdx, 644o
    syscall
    mov [cycles_handle], rax

    mov rax, SYS_write
    mov rdi, [cycles_handle]
    mov rsi, cycles_msg_1
    mov rdx, cycles_msg_1.len
    syscall
    ret

debug_func:
    push_regs
    
    mov edx, r10d
    shr edx,8
    call debug_hex_char
    mov [debug_buffer+0],dh
    mov [debug_buffer+1],dl

    mov edx, r10d
    movzx edx, dl
    call debug_hex_char
    mov [debug_buffer+2],dh
    mov [debug_buffer+3],dl

    mov edx, eax
    call debug_hex_char
    mov [debug_buffer+7],dh
    mov [debug_buffer+8],dl

    mov edx, ebx
    call debug_hex_char
    mov [debug_buffer+12],dh
    mov [debug_buffer+13],dl

    mov edx, ecx
    call debug_hex_char
    mov [debug_buffer+17],dh
    mov [debug_buffer+18],dl

    mov edx, edi
    call debug_hex_char
    mov [debug_buffer+23],dh
    mov [debug_buffer+24],dl

    mov [debug_buffer+26], byte 'C'
    mov [debug_buffer+27], byte 'N'
    mov [debug_buffer+28], byte 'V'
    mov [debug_buffer+29], byte 'Z'

    popfq
    pushfq
    jc .C
    mov [debug_buffer+26], byte 'c'
    .C:

    js .N
    mov [debug_buffer+27], byte 'n'
    .N:

    jo .V
    mov [debug_buffer+28], byte 'v'
    .V:
    
    jz .Z
    mov [debug_buffer+29], byte 'z'
    .Z:

    mov rax, SYS_write
    mov rdi, [cycles_handle]
    mov rsi, debug_buffer
    mov rdx, debug_buffer.len
    syscall
    
    inc qword[debug_counter]
    cmp qword [debug_counter], DEBUG_LIMIT
    jb .no_exit
    pull_regs
    jmp done
    .no_exit:
    pull_regs
    ret

;dl - number to convert to hex
;r8,r9 - trashed
;returns in dx
debug_hex_char:
    
    mov r8d, edx
    and r8d, 0xF
    cmp r8d, 0xA
    jae .letter
    .number:
    add r8d, '0'
    jmp .char2
    .letter:
    sub r8d, 0xA
    add r8d, 'A'
    
    .char2:
    mov r9d, r8d
    mov r8d, edx
    shr r8d, 4
    cmp r8d, 0xA
    jae .letter2
    .number2:
    add r8d, '0'
    jmp .done
    .letter2:
    sub r8d, 0xA
    add r8d, 'A'

    .done:
    mov dl, r8b
    mov dh, dl
    mov dl, r9b
    ret

