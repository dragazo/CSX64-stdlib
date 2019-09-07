#!csx.exe -s

global main

extern stdout, stderr, EOF, NULL
extern fprintf, printf, puts

segment .text

main:
	mov rdi, stdout
	mov rsi, $str("i'm gonna make this string really long so that it goes onto a new buffer page and has to do potentially more than a single trivial flush of the buffer stack thing", 10)
	mov al, 0
	call fprintf

	mov rdi, $str(`my name is %s %c. and i'm %d years old!\n`)
	mov rsi, $str('Timmy')
	mov dl, 'R'
	mov ecx, 21
	mov al, 0
	call printf
	
	mov rdi, $str(`unsigned %d: %u\n`)
	mov esi, -56
	mov edx, -56
	mov al, 0
	call printf
	
	xor eax, eax
	ret
