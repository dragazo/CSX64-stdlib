global main

extern bsearch, qsort
extern memcpy, memmove
extern memset, memchr

extern malloc, calloc, free, realloc

segment .text

main:
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
    
	xor eax, eax
    ret

.bad_malloc:

    mov eax, sys_write
    mov ebx, 2
    mov ecx, bad_malloc_msg
    mov edx, bad_malloc_msg_len
    syscall

	mov eax, 1
    ret

.unaligned:

	debug_cpu
	
	mov eax, sys_write
	mov ebx, 2
	mov ecx, unaligned_msg
	mov edx, unaligned_msg_len
	syscall
	
	mov eax, 2
	ret
	
.bad_calloc:

    mov eax, sys_write
    mov ebx, 2
    mov ecx, bad_calloc_msg
    mov edx, bad_calloc_msg_len
    syscall

	mov eax, 3
    ret

.diff_block:

    mov eax, sys_write
    mov ebx, 2
    mov ecx, diff_block_msg
    mov edx, diff_block_msg_len
    syscall

	mov eax, 4
    ret

.nonzero:

	mov eax, sys_write
	mov ebx, 2
	mov ecx, nonzero_msg
	mov edx, nonzero_msg_len
	syscall
	
	mov eax, 5
	ret
	
segment .rodata

bad_malloc_msg: db `\n\nMALLOC RETURNED NULL!!\n\n`
bad_malloc_msg_len: equ $-bad_malloc_msg

unaligned_msg: db `\n\nMALLOC RETURNED AN UNALIGNED ADDRESS!!\n\n`
unaligned_msg_len: equ $-unaligned_msg

bad_calloc_msg: db `\n\nCALLOC RETURNED NULL!!\n\n`
bad_calloc_msg_len: equ $-bad_calloc_msg

diff_block_msg: db `\n\nMALLOC/CALLOC GAVE DIFFERENT DATA BLOCKS!!\n\n`
diff_block_msg_len: equ $-diff_block_msg

nonzero_msg: db `\n\nCALLOC DID NOT ZERO RETURNED MEMORY!!\n\n`
nonzero_msg_len: equ $-nonzero_msg
