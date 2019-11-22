#!csx.exe -s

global main

extern stdout, stderr, EOF, NULL
extern fprintf, printf, puts, fputs, vsprintf
extern arglist_start, arglist_end, arglist_i
extern strlen, exit, strcmp

segment .bss

assert_printf_buffer: resb 1024 ; buffer to use for string formatting

segment .text

static_assert 'abcd' == 0x64636261 ; make sure we're making multibyte chars little endian

show_assertion_tests: equ 0

; void assert_printf(const char *fmt, const char *expect, ...);
assert_printf:
	mov r10, rsp
	call arglist_start
	push rax
	push rsi
	push rdi
	
	mov rdi, rax
	times 2 call arglist_i
	
	mov rdx, rdi
	mov rdi, assert_printf_buffer
	pop rsi
	call vsprintf
	push rax
	
	mov rdi, qword ptr [rsp + 8]
	mov rsi, assert_printf_buffer
	call strcmp
	cmp eax, 0
	je .same

	mov rdi, $str(`SPRINTF ASERTION FAILURE:\nexpected:`)
	call puts
	mov rdi, qword ptr [rsp + 8]
	call puts
	mov rdi, $str(`actual: `)
	call puts
	mov rdi, assert_printf_buffer
	call puts
	
	mov edi, 64
	call exit
	
	.same:
	mov rdi, assert_printf_buffer
	call strlen
	pop rbx
	cmp rax, rbx
	je .right_return_val
	
	debug_cpu
	mov rdi, $str(`SPRINTF ASSERTION FAILURE: wrong return value`)
	call puts
	mov rdi, qword ptr [rsp]
	call puts
	
	mov edi, 65
	call exit
	
	.right_return_val:
	add rsp, 8
	
	if show_assertion_tests mov rdi, assert_printf_buffer
	if show_assertion_tests mov rsi, stdout
	if show_assertion_tests call fputs
	
	pop rdi
	call arglist_end
	ret

long_str: equ $str("i'm gonna make this string really long so that it goes onto a new buffer page and has to do potentially more than a single trivial flush of the buffer stack thing", 10)
	
main:
	mov rdi, long_str
	mov rsi, long_str
	mov al, 0
	call assert_printf

	mov rdi, $str(`my name is %s %c. and i'm %d years old!\n`)
	mov rsi, $str(`my name is Timmy R. and i'm 21 years old!\n`)
	mov rdx, $str('Timmy')
	mov rcx, 'R'
	mov r8, 21
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`unsigned %*.*d: %*u\n`)
	mov rsi, $str(`unsigned -000000000056:   4294967240\n`)
	mov rdx, 12
	mov rcx, 12
	mov r8, -56
	mov r9, 12
	push qword -56
	mov al, 0
	call assert_printf
	add rsp, 8
	
	mov rdi, $str(`%%4d: %4d %4d\n`)
	mov rsi, $str(`%4d:   24  -24\n`)
	mov rdx, 24
	mov rcx, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`%%04d:   %04d %04d\n`)
	mov rsi, $str(`%04d:   0024 -024\n`)
	mov rdx, 24
	mov rcx, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`%%+04d:  %+04d %+04d\n`)
	mov rsi, $str(`%+04d:  0024 -024\n`)
	mov rdx, 24
	mov rcx, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`%%.4d:   %.4d %.4d\n`)
	mov rsi, $str(`%.4d:   0024 -0024\n`)
	mov rdx, 24
	mov rcx, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`%%4.4d:  %4.4d %4.4d\n`)
	mov rsi, $str(`%4.4d:  0024 -0024\n`)
	mov rdx, 24
	mov rcx, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`%%4.8d:  %4.8d %4.8d\n`)
	mov rsi, $str(`%4.8d:  00000024 -00000024\n`)
	mov rdx, 24
	mov rcx, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`%%8.4d:  %8.4d %8.4d\n`)
	mov rsi, $str(`%8.4d:      0024    -0024\n`)
	mov rdx, 24
	mov rcx, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`%%-8.4d: %-8.4d %-8.4d\n`)
	mov rsi, $str(`%-8.4d: 0024     -0024   \n`)
	mov rdx, 24
	mov rcx, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`\n%%hhd:  %hhd =  %hho =   %hhx\n`)
	mov rsi, $str(`\n%hhd:  -24 =  350 =   e8\n`)
	mov rdx, -24
	mov rcx, -24
	mov r8, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`%%#hhd: %#hhd = %#hho = %#hhx\n`)
	mov rsi, $str(`%#hhd: -24 = 0350 = 0xe8\n`)
	mov rdx, -24
	mov rcx, -24
	mov r8, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`\n%%hd:  %hd =  %ho =   %hx\n`)
	mov rsi, $str(`\n%hd:  -24 =  177750 =   ffe8\n`)
	mov rdx, -24
	mov rcx, -24
	mov r8, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`%%#hd: %#hd = %#ho = %#hx\n`)
	mov rsi, $str(`%#hd: -24 = 0177750 = 0xffe8\n`)
	mov rdx, -24
	mov rcx, -24
	mov r8, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`\n%%d:  %d =  %o =   %x\n`)
	mov rsi, $str(`\n%d:  -24 =  37777777750 =   ffffffe8\n`)
	mov rdx, -24
	mov rcx, -24
	mov r8, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`%%#d: %#d = %#o = %#x\n`)
	mov rsi, $str(`%#d: -24 = 037777777750 = 0xffffffe8\n`)
	mov rdx, -24
	mov rcx, -24
	mov r8, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`\n%%ld:  %ld =  %lo =   %lx\n`)
	mov rsi, $str(`\n%ld:  -24 =  1777777777777777777750 =   ffffffffffffffe8\n`)
	mov rdx, -24
	mov rcx, -24
	mov r8, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`%%#ld: %#ld = %#lo = %#lx\n`)
	mov rsi, $str(`%#ld: -24 = 01777777777777777777750 = 0xffffffffffffffe8\n`)
	mov rdx, -24
	mov rcx, -24
	mov r8, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`\n%%lld:  %lld =  %llo =   %llx\n`)
	mov rsi, $str(`\n%lld:  -24 =  1777777777777777777750 =   ffffffffffffffe8\n`)
	mov rdx, -24
	mov rcx, -24
	mov r8, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`%%#lld: %#lld = %#llo = %#llx\n`)
	mov rsi, $str(`%#lld: -24 = 01777777777777777777750 = 0xffffffffffffffe8\n`)
	mov rdx, -24
	mov rcx, -24
	mov r8, -24
	mov al, 0
	call assert_printf
	
	mov rdi, $str(`\n%x %+x %#x %8x %#+-08x\n`)
	mov rsi, $str(`\nbead bead 0xbead     bead 0x00bead\n`)
	mov rdx, 0xbead
	mov rcx, 0xbead
	mov r8, 0xbead
	mov r9, 0xbead
	push qword 0xbead
	mov al, 0
	call assert_printf
	add rsp, 8
	
	mov rdi, $str(`%X %+X %#X %8X %#+-08X\n`)
	mov rsi, $str(`BEAD BEAD 0XBEAD     BEAD 0X00BEAD\n`)
	mov rdx, 0xbead
	mov rcx, 0xbead
	mov r8, 0xbead
	mov r9, 0xbead
	push qword 0xbead
	mov al, 0
	call assert_printf
	add rsp, 8
	
	mov rdi, $str(`%o %+o  %#o %8o %#+-08o\n`)
	mov rsi, $str(`1337 1337  01337     1337 00001337\n`)
	mov rdx, 0o1337
	mov rcx, 0o1337
	mov r8, 0o1337
	mov r9, 0o1337
	push qword 0o1337
	mov al, 0
	call assert_printf
	add rsp, 8
	
	mov rdi, $str(`\n%x %+x %#x %.8x %#+-0.8x\n`)
	mov rsi, $str(`\nbead bead 0xbead 0000bead 0x0000bead\n`)
	mov rdx, 0xbead
	mov rcx, 0xbead
	mov r8, 0xbead
	mov r9, 0xbead
	push qword 0xbead
	mov al, 0
	call assert_printf
	add rsp, 8
	
	mov rdi, $str(`%X %+X %#X %.8X %#+-0.8X\n`)
	mov rsi, $str(`BEAD BEAD 0XBEAD 0000BEAD 0X0000BEAD\n`)
	mov rdx, 0xbead
	mov rcx, 0xbead
	mov r8, 0xbead
	mov r9, 0xbead
	push qword 0xbead
	mov al, 0
	call assert_printf
	add rsp, 8
	
	mov rdi, $str(`%o %+o  %#o %.8o  %#+-0.8o\n`)
	mov rsi, $str(`1337 1337  01337 00001337  000001337\n`)
	mov rdx, 0o1337
	mov rcx, 0o1337
	mov r8, 0o1337
	mov r9, 0o1337
	push qword 0o1337
	mov al, 0
	call assert_printf
	add rsp, 8
	
	mov rdi, $str(`\nno overflow: %#d %#0d %#.0d %#0.0d %#+0.0d\n`)
	mov rsi, $str(`\nno overflow: -123 -123 -123 -123 -123\n`)
	mov rdx, -123
	mov rcx, -123
	mov r8, -123
	mov r9, -123
	push qword -123
	mov al, 0
	call assert_printf
	add rsp, 8
	
	mov rdi, $str(`no overflow: %#x %#0x %#.0x %#0.0x %#+0.0x\n`)
	mov rsi, $str(`no overflow: 0xffffff85 0xffffff85 0xffffff85 0xffffff85 0xffffff85\n`)
	mov rdx, -123
	mov rcx, -123
	mov r8, -123
	mov r9, -123
	push qword -123
	mov al, 0
	call assert_printf
	add rsp, 8
	
	mov rdi, $str(`no overflow: %#o %#0o %#.0o %#0.0o %#+0.0o\n`)
	mov rsi, $str(`no overflow: 037777777605 037777777605 037777777605 037777777605 037777777605\n`)
	mov rdx, -123
	mov rcx, -123
	mov r8, -123
	mov r9, -123
	push qword -123
	mov al, 0
	call assert_printf
	add rsp, 8
	
	mov rdi, $str(`\nfloating test: %f\n`)
	mov rsi, $str(`\nfloating test: 1.123000\n`)
	mov rax, 1.123
	movq xmm0, rax
	mov al, 1
	call assert_printf
	
	mov rdi, $str(`floating test: %f\n`)
	mov rsi, $str(`floating test: -1.123000\n`)
	mov rax, -1.123
	movq xmm0, rax
	mov al, 1
	call assert_printf
	
	; -----------------------------------
	
	mov rdi, $str(`\npassed all assertions`)
	call puts
	
	xor eax, eax
	ret
