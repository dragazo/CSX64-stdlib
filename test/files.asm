#!echo run as ./csx.exe -s --fs files.asm

global main

extern puts
extern fopen, fflush, fclose

extern stdin, stdout, stderr

segment .text

main:
	; make sure we can open the file
	mov rdi, path
	mov rsi, mode
	call fopen
	; make sure it succeeds
	cmp rax, 0
	jnz .success_1
	mov rdi, open_err_msg_1
	call puts
	mov eax, 1
	ret
	.success_1:
	
	push rax ; store pointer for later test
	
	; make sure we can close it
	mov rdi, rax
	call fclose
	; make sure it succeeds
	cmp rax, 0
	jz .success_2
	mov rdi, close_err_msg_1
	call puts
	mov eax, 2
	ret
	.success_2:
	
	; make sure we can open the file again
	mov rdi, path
	mov rsi, mode
	call fopen
	; make sure it succeeds
	cmp rax, 0
	jnz .success_3
	mov rdi, open_err_msg_2
	call puts
	mov eax, 1
	ret
	.success_3:
	
	pop rbx ; restore pointer from previous test
	cmp rax, rbx
	je .no_leak
	mov rdi, memory_leak_msg
	call puts
	mov eax, -1
	ret
	.no_leak:
	
	; make sure we can close it
	mov rdi, rax
	call fclose
	; make sure it succeeds
	cmp rax, 0
	jz .success_4
	mov rdi, close_err_msg_2
	call puts
	mov eax, 2
	ret
	.success_4:
	
	; make sure we can close all the standard streams
	mov rdi, stdin
	call fclose
	mov rdi, stdout
	call fclose
	mov rdi, stderr
	call fclose
	
	xor eax, eax
    ret

segment .rodata

path: db "msg.txt", 0
mode: db "r", 0

open_err_msg_1: db "failed to open file (1)", 0
close_err_msg_1: db "failed to close file (1)", 0
open_err_msg_2: db "failed to open file (2)", 0
close_err_msg_2: db "failed to close file (2)", 0

memory_leak_msg: db "memory leak: file was not in expected location", 0

segment .bss

name_cap: equ 32
name: resb name_cap + 1




