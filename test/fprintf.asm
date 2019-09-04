#!csx.exe -s

global main

extern stdout, stderr, EOF, NULL
extern fprintf, puts

segment .text

main:
	mov rdi, $str("i'm gonna make this string really long so that it goes onto a new buffer page and has to do potentially more than a single trivial flush of the buffer stack thing", 10)
	call puts
	
	mov rdi, $str(`i'm %d years old!\n`)
	call puts
	
	mov rdi, $str(`this should be a different string\n`)
	call puts
	
	xor eax, eax
	ret
