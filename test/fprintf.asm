#!csx.exe -s

global main

extern stdout, stderr, EOF, NULL
extern fprintf, puts

segment .text

main:
	mov rdi, stdout
	mov rsi, $str("i'm gonna make this string really long so that it goes onto a new buffer page and has to do potentially more than a single trivial flush of the buffer stack thing", 10)
	mov al, 0
	call fprintf
	
	mov rdi, stdout
	mov rsi, $str(`i'm %d years old!\n`)
	mov edx, 21
	mov al, 0
	call fprintf
	
	mov rdi, stdout
	mov rsi, $str(`unsigned %d: %u\n`)
	mov edx, -56
	mov ecx, -56
	mov al, 0
	call fprintf
	
	xor eax, eax
	ret
