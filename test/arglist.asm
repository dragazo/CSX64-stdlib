#!csx.exe -s

global main

extern arglist_start, arglist_end
extern arglist_i64, arglist_f64
extern puts, putchar

segment .text

; int printer(int n, ...(const char*))
printer:
	mov r10, rsp ; save init rsp in r10 for arglist_start
	
	push r13 ; then push whatever we need prior to start
	push r14
	push r15
	
	call arglist_start ; start the arg list
	mov r13, rdi ; r13 holds n
	mov r14, rax ; r14 holds arglist pointer
	xor r15, r15 ; r15 holds character total
	
	; extract and ignore the first arg (n)
	mov rdi, rax
	call arglist_i64
	
	; print each arg, maintain character total
	jmp .loop_tst
	.loop_bod:
		mov rdi, r14
		call arglist_i64
		mov rdi, rax
		call puts
		add r15, rax
	.loop_aft:
		dec r13
	.loop_tst:
		cmp r13, 0
		jg .loop_bod
	
	; end arg list
	mov rdi, r14
	call arglist_end
	
	; put return value in rax
	mov rax, r15
	
	; restore call-safe registers
	pop r15
	pop r14
	pop r13
	
	ret
	
main:
	mov rdi, 10
	mov rsi, $str(`line 1`)
	mov rdx, $str(`line 2`)
	mov rcx, $str(`line 3`)
	mov r8, msg4
	mov r9, msg5
	push qword msg10
	push qword msg9
	push qword $str(`line 8`)
	push qword $str(`line 7`)
	push qword msg6
	mov al, 0
    call printer
	add rsp, 5*8
	
	xor eax, eax
    ret

segment .rodata

static_assert `\0` == 0

msg4: db `line 4\0`
msg5: db `line 5\0`
msg6: db `line 6\0`

msg9: db `line 9\0`
msg10: db `line 10\0`
