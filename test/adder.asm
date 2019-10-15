#!csx.exe -s

global main

extern stderr
extern printf, fprintf, scanf
extern getchar
segment .text

main:
	mov rdi, $str("Enter a number: ")
	mov al, 0
	call printf
	
	mov rdi, $str("%d")
	mov rsi, num1
	mov al, 0
	call scanf
	cmp eax, 1
	je .scan_1_ok
	mov rdi, stderr
	mov rsi, $str(`parse 1 failed: returned %d expected 1\n`)
	mov al, 0
	call fprintf
	.scan_1_ok:
	
	mov rdi, $str("Enter a number: ")
	mov al, 0
	call printf
	
	mov rdi, $str("%d")
	mov rsi, num2
	mov al, 0
	call scanf
	cmp eax, 1
	je .scan_2_ok
	mov rdi, stderr
	mov rsi, $str(`parse 2 failed: returned %d expected 1\n`)
	mov al, 0
	call fprintf
	.scan_2_ok:
	
	mov rdi, $str(`%d + %d = %d\n`)
	mov esi, dword ptr [num1]
	mov edx, dword ptr [num2]
	lea ecx, [esi + edx]
	mov al, 0
	call printf
	
	xor eax, eax
	ret

segment .bss

num1: resd 1
num2: resd 1
