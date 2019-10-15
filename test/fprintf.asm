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
	
	mov rdi, $str(`unsigned %*.*d: %*u\n`)
	mov esi, 12
	mov edx, 12
	mov ecx, -56
	mov r8d, 12
	mov r9d, -56
	mov al, 0
	call printf
	
	mov rdi, $str(`%%4d: %4d %4d\n`)
	mov esi, 24
	mov edx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`%%04d:   %04d %04d\n`)
	mov esi, 24
	mov edx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`%%+04d:  %+04d %+04d\n`)
	mov esi, 24
	mov edx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`%%.4d:   %.4d %.4d\n`)
	mov esi, 24
	mov edx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`%%4.4d:  %4.4d %4.4d\n`)
	mov esi, 24
	mov edx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`%%4.8d:  %4.8d %4.8d\n`)
	mov esi, 24
	mov edx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`%%8.4d:  %8.4d %8.4d\n`)
	mov esi, 24
	mov edx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`%%-8.4d: %-8.4d %-8.4d\n`)
	mov esi, 24
	mov edx, -24
	mov al, 0
	call printf
	
	xor eax, eax
	ret
