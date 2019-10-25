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
	
	mov rdi, $str(`\n%%hhd:  %hhd =  %hho =   %hhx\n`)
	mov rsi, -24
	mov rdx, -24
	mov rcx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`%%#hhd: %#hhd = %#hho = %#hhx\n`)
	mov rsi, -24
	mov rdx, -24
	mov rcx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`\n%%hd:  %hd =  %ho =   %hx\n`)
	mov rsi, -24
	mov rdx, -24
	mov rcx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`%%#hd: %#hd = %#ho = %#hx\n`)
	mov rsi, -24
	mov rdx, -24
	mov rcx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`\n%%d:  %d =  %o =   %x\n`)
	mov rsi, -24
	mov rdx, -24
	mov rcx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`%%#d: %#d = %#o = %#x\n`)
	mov rsi, -24
	mov rdx, -24
	mov rcx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`\n%%ld:  %ld =  %lo =   %lx\n`)
	mov rsi, -24
	mov rdx, -24
	mov rcx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`%%#ld: %#ld = %#lo = %#lx\n`)
	mov rsi, -24
	mov rdx, -24
	mov rcx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`\n%%lld:  %lld =  %llo =   %llx\n`)
	mov rsi, -24
	mov rdx, -24
	mov rcx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`%%#lld: %#lld = %#llo = %#llx\n`)
	mov rsi, -24
	mov rdx, -24
	mov rcx, -24
	mov al, 0
	call printf
	
	mov rdi, $str(`\n%x %+x %#x %8x %#+-08x\n`)
	mov rsi, 0xbead
	mov rdx, 0xbead
	mov rcx, 0xbead
	mov r8, 0xbead
	mov r9, 0xbead
	mov al, 0
	call printf
	
	mov rdi, $str(`%X %+X %#X %8X %#+-08X\n`)
	mov rsi, 0xbead
	mov rdx, 0xbead
	mov rcx, 0xbead
	mov r8, 0xbead
	mov r9, 0xbead
	mov al, 0
	call printf
	
	mov rdi, $str(`%o %+o  %#o %8o  %#+-08o\n`)
	mov rsi, 0o1337
	mov rdx, 0o1337
	mov rcx, 0o1337
	mov r8, 0o1337
	mov r9, 0o1337
	mov al, 0
	call printf
	
	xor eax, eax
	ret
