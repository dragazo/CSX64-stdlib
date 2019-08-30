; this file adds utilities for handling vararg parameter lists
; this is nonstandard and just serves as convenience for CSX64 programs

global arglist_start, arglist_end
global arglist_i64, arglist_f64

segment .text

arglist: equ 0
	.ALIGN: equ 16
	.SIZE:  equ 208
	
	.reg_index: equ 0 ; u32
	.xmm_index: equ 4 ; u32
	.stack_pos: equ 8 ; void*
	
	.root_rsp:  equ 16 ; void*
	; 8 bytes of padding
	
	.reg_arr: equ 32 ; r64[6]
	.xmm_arr: equ 80 ; m128[8]

static_assert (arglist.xmm_arr & 15) == 0
	
; arglist *arglist_start(void *rsp_init : r10, u8 vec_reg_count : al)
;
; returns an arglist that iterates over all csxdecl function arguments.
; can be called from any csxdecl function (must be before any arg registers are modified).
; any arguments that were passed in registers are preserved.
; any arguments that were passed on the stack must be accessed relative to rsp_init (see below).
; the returned pointer must be passed to arglist_end() in reverse order to stack manipulations.
; i.e. arglist_end() must be called when the stack pointer is in the same position as it was when arglist_start() returned.
;
; rsp_init      - the initial value of rsp upon entering the csxdecl function (must be passed in r10).
; vec_reg_count - the number of vector registers that could be used (can be higher than actual) (passed in al).
;                 for a varargs function, this is set by the caller (of your function).
;                 range [0..8] (outside this range is undefined behavior).
arglist_start:
	pop rbx      ; pop the return address off the stack
	mov r11, rsp ; put current stack pos in r11 (this is the root rsp value for arglist_end)
	
	add r10, 8 ; put caller's stack arg location in r10 (rsp_init+8 to skip their ret address)
	sub rsp, arglist.SIZE ; allocate stack space for the arglist struct
	and rsp, ~(arglist.ALIGN - 1) ; align the stack for the arglist stuct
	
	; initialze the arglist object
	mov dword ptr [rsp + arglist.reg_index], 0
	mov dword ptr [rsp + arglist.xmm_index], 0
	mov qword ptr [rsp + arglist.stack_pos], r10
	mov qword ptr [rsp + arglist.root_rsp], r11
	
	; copy as many xmm regs as we need
	movzx eax, al
	imul eax, -.xmm_code_len
	add rax, .xmm_none
	jmp rax
	.xmm_7: movapd xmmword ptr [rsp + arglist.xmm_arr + 7*16], xmm7
	.xmm_6: movapd xmmword ptr [rsp + arglist.xmm_arr + 6*16], xmm6
	.xmm_5: movapd xmmword ptr [rsp + arglist.xmm_arr + 5*16], xmm5
	.xmm_4: movapd xmmword ptr [rsp + arglist.xmm_arr + 4*16], xmm4
	.xmm_3: movapd xmmword ptr [rsp + arglist.xmm_arr + 3*16], xmm3
	.xmm_2: movapd xmmword ptr [rsp + arglist.xmm_arr + 2*16], xmm2
	.xmm_1: movapd xmmword ptr [rsp + arglist.xmm_arr + 1*16], xmm1
	.xmm_0: movapd xmmword ptr [rsp + arglist.xmm_arr + 0*16], xmm0
	.xmm_none:
	.xmm_code_len: equ .xmm_none-.xmm_0
	static_assert .xmm_0 - .xmm_1 == .xmm_code_len
	static_assert .xmm_1 - .xmm_2 == .xmm_code_len
	static_assert .xmm_2 - .xmm_3 == .xmm_code_len
	static_assert .xmm_3 - .xmm_4 == .xmm_code_len
	static_assert .xmm_4 - .xmm_5 == .xmm_code_len
	static_assert .xmm_5 - .xmm_6 == .xmm_code_len
	static_assert .xmm_6 - .xmm_7 == .xmm_code_len
	
	; copy all the itegral registers
	mov qword ptr [rsp + arglist.reg_arr + 5*8], r9
	mov qword ptr [rsp + arglist.reg_arr + 4*8], r8
	mov qword ptr [rsp + arglist.reg_arr + 3*8], rcx
	mov qword ptr [rsp + arglist.reg_arr + 2*8], rdx
	mov qword ptr [rsp + arglist.reg_arr + 1*8], rsi
	mov qword ptr [rsp + arglist.reg_arr + 0*8], rdi
	
	mov rax, rsp ; place arglist pointer in return location
	jmp rbx      ; jump back to the return address we popped off the stack

; void arglist_end(arglist *list)
; this MUST be called with the return value from arglist_start() (see arglist_start()).
; failure to do so may result in memory leaks or random undefined errors.
; this releases any resources used by list and invalidates it.
arglist_end:
	pop rbx ; pop the return address off the stack
	
	mov rsp, qword ptr [rdi + arglist.root_rsp] ; all we need to do is undo our stack allocations by restoring root rsp
	
	jmp rbx ; jump back to the return address we popped of the stack

; ---------------------------------------------

; for all following functions of form arglist_T:
; signature: T arglist_T(arglist *list)
; gets the next argument (assumed to be of type T) and advances the arglist iterator to the next position.
; it is undefined behavior if the next arg does not exist or is not the correct type.
; these functions must be called on a valid arglist (after arglist_start() but before arglist_end()).
; additionally, these functions guarantee not to modify rdi.

arglist_i64:
	mov ecx, dword ptr [rdi + arglist.reg_index]
	cmp ecx, 6
	jae .get_from_stack
	
	mov rax, qword ptr [rdi + arglist.reg_arr + rcx*8]
	inc dword ptr [rdi + arglist.reg_index]
	ret

	.get_from_stack:
	mov rax, qword ptr [rdi + arglist.stack_pos]
	mov rax, qword ptr [rax]
	add qword ptr [rdi + arglist.stack_pos], 8
	ret
arglist_f64:
	mov ecx, dword ptr [rdi + arglist.xmm_index]
	cmp ecx, 8
	jae .get_from_stack
	
	shl rcx, 4 ; mult 16 (xmm_arr holds xmmwords)
	movsd xmm0, qword ptr [rdi + arglist.xmm_arr + rcx]
	inc dword ptr [rdi + arglist.xmm_index]
	ret

	.get_from_stack:
	mov rax, qword ptr [rdi + arglist.stack_pos]
	movsd xmm0, qword ptr [rax]
	add qword ptr [rdi + arglist.stack_pos], 8
	ret
