#!csx.exe -s

global main

extern bsearch, qsort
extern memcpy, memmove
extern memset, memchr

extern malloc, calloc, free, realloc

extern puts, fputs, stderr, stdout

segment .text

main:
	; make sure the cmd line args array is null terminated
	cmp qword ptr [rsi + 8*rdi], 0
	jnz .bad_args

    mov edi, 32
    call malloc

    cmp rax, 0
    je .bad_malloc ; make sure that worked

	test rax, 7
	jnz .unaligned ; make sure we got an aligned address
	
	; put something in the array so we can make sure calloc will zero it later on
    mov qword ptr [rax +  0], 0xdeadbeef
    mov qword ptr [rax +  8], 0xbadc0de
    mov qword ptr [rax + 16], 0xabacaba
    mov qword ptr [rax + 24], 0x1337

    mov rdi, rax
    mov r15, rax ; store a copy of that pointer in r15

    call free
    
    mov edi, 32
    call calloc

    cmp rax, 0
    je .bad_calloc ; make sure that worked

    cmp rax, r15
    jne .diff_block ; make sure it gave us the same block as before
                    ; this is a test case for the malloc impl
                    ; users should not assume this behavior

    test qword ptr [rax +  0], 0
	jnz .nonzero
    test qword ptr [rax +  8], 0
	jnz .nonzero
    test qword ptr [rax + 16], 0
	jnz .nonzero
    test qword ptr [rax + 24], 0
	jnz .nonzero
    
	; print the alphabet
	mov edi, alphabet
	call puts
	
	; print the incbin message
	mov edi, incbinmsg
	call puts
	
	; print no errors message
	mov edi, no_err
	call puts
	
	xor eax, eax
    ret

.bad_args:

    mov edi, no_cmd_term_msg
	mov esi, stderr
    call fputs

	mov eax, 24
    ret
	
.bad_malloc:

    mov edi, bad_malloc_msg
    mov esi, stderr
    call fputs

	mov eax, 1
    ret

.unaligned:

	debug_cpu
	
	mov edi, unaligned_msg
	mov esi, stderr
	call fputs
	
	mov eax, 2
	ret
	
.bad_calloc:

    mov edi, bad_calloc_msg
    mov esi, stderr
    call fputs

	mov eax, 3
    ret

.diff_block:

    mov edi, diff_block_msg
    mov esi, stderr
    call fputs

	mov eax, 4
    ret

.nonzero:

	mov edi, nonzero_msg
	mov esi, stderr
	call fputs
	
	mov eax, 5
	ret
	
segment .rodata

t_count: equ 24 ; number of times to repeat times

t_prefix: db 77
t_body: times t_count db 21
t_suffix: db 88

; make sure the times prefix behaved properly (also tests that static_assert works)
static_assert t_suffix-t_body == t_count, "TIMES count error"
static_assert (   ((t_suffix-t_body)   )) == t_count, "TIMES count error"
static_assert t_suffix-t_body == t_count

static_assert t_body - t_prefix == 1
static_assert 3.14

if_test1: if -16 equ 7
if_test1: if  0  equ 3
static_assert if_test1 == 7
static_assert if_test1 != 3

if_test2: if   0   equ 74
if_test2: if -54.4 equ 79
static_assert if_test2 != 74
static_assert if_test2 == 79

; create a C string of AaBb...Zz012...9 using TIMES index unrolling
alphabet:
	times 26 db 'A'+$i, 'a'+$i
	times 10 db '0'+$i
	db 10, 0
static_assert $-alphabet == 26 * 2 + 10 + 2

incbinmsg:
	db "incbin msg: "
	incbin "msg.txt"
	db 0

bad_malloc_msg: db `\n\nMALLOC RETURNED NULL!!\n\n`, 0

unaligned_msg: db `\n\nMALLOC RETURNED AN UNALIGNED ADDRESS!!\n\n`, 0

bad_calloc_msg: db `\n\nCALLOC RETURNED NULL!!\n\n`, 0

diff_block_msg: db `\n\nMALLOC/CALLOC GAVE DIFFERENT DATA BLOCKS!!\n\n`, 0

nonzero_msg: db `\n\nCALLOC DID NOT ZERO RETURNED MEMORY!!\n\n`, 0

no_cmd_term_msg: db `\n\nNO COMMAND LINE ARG TERMINATOR!!\n\n`, 0

no_err: db `no errors\n`, 0
