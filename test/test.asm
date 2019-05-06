#!csx.exe -s

global main

extern puts

segment .text

main:
	mov rdi, q
	call puts
    
    mov rax, sys_read
    xor rbx, rbx
    mov rcx, name
    mov rdx, name_cap
    syscall
    mov byte ptr [name + rax - 1], 0
    
	mov rdi, a
	call puts
    mov rdi, name
	call puts
    mov rdi, b
    call puts
    
    ret

segment .rodata

q: db "what's your name? ", 0

a: db "so your name is ", 0
b: db '?', 10, "what a cool name!", 10, 0

segment .bss

name_cap: equ 32
name: resb name_cap + 1




