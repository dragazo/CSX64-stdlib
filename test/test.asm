#!csx.exe -s

global main

extern puts

segment .text

main:
	mov rdi, $str("what's your name? ")
	call puts
    
    mov rax, sys_read
    xor rbx, rbx
    mov rcx, name
    mov rdx, name_cap
    syscall
    mov byte ptr [name + rax - 1], 0
    
	mov rdi, $str("so your name is ")
	call puts
    mov rdi, name
	call puts
    mov rdi, $str('?', 10, "what a cool name!", 10)
    call puts
    
    ret

segment .bss

name_cap: equ 32
name: resb name_cap + 1
