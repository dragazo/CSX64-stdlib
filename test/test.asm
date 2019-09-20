#!csx.exe -s

global main

extern fputs, stdout

segment .text

main:
	mov rdi, $str("what's your name? ")
	mov rsi, stdout
	call fputs
    
    mov rax, sys_read
    xor rbx, rbx
    mov rcx, name
    mov rdx, name_cap
    syscall
    mov byte ptr [name + rax - 1], 0
    
	mov rdi, $str("so your name is ")
	mov rsi, stdout
	call fputs
    mov rdi, name
	mov rsi, stdout
	call fputs
    mov rdi, $str('?', 10, "what a cool name!", 10)
	mov rsi, stdout
    call fputs
    
    ret

segment .bss

name_cap: equ 32
name: resb name_cap + 1
