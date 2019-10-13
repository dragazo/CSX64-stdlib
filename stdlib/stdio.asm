; source http://www.cplusplus.com/reference/cstdio/
; needs a TON of file handling code

; --------------------------------------

global EOF
global stdin, stdout, stderr

; --------------------------------------

global remove, rename

; --------------------------------------

global fputc, putc, putchar
global fputs, puts
global fwrite

global fscanf, vfscanf
global scanf, vscanf

global fprintf, vfprintf
global printf, vprintf

; --------------------------------------

global ungetc, fgetc, getchar, fpeek

; --------------------------------------

global fopen, fflush, fclose

; --------------------------------------

extern arglist_start, arglist_end
extern arglist_i64, arglist_i32, arglist_i16, arglist_i8
extern arglist_f64, arglist_f32

extern malloc, free
extern strlen
extern isspace

; --------------------------------------

segment .text

EOF: equ -1

FILE:
	.ALIGN:     equ 4
	.SIZE:      equ 12
	
	.fd:        equ 0 ; int (connected (open) file descriptor from native platform)
	.ungetc_ch: equ 4 ; int (character put back into stream by ungetc - only 1 allowed- EOF (-1) for none)
	.static:    equ 8 ; int (bool flag marking as static object (no free()) - e.g. stdout)

; --------------------------------------

; int remove(const char *path);
remove:
    mov eax, sys_unlink
    mov rbx, rdi
    syscall
    ret

; int rename(const char *from, const char *to);
rename:
    mov eax, sys_rename
    mov rbx, rdi
    mov rcx, rsi
    syscall
    ret
	
; --------------------------------------

; int putchar(int ch)
putchar:
	mov rsi, stdout
; int fputc(int ch, FILE *stream)
; int putc(int ch, FILE *stream)
fputc:
putc:
	; put ch in memory so it has an address
	mov byte ptr [rsp - 1], dil
	
	; write the character (string of length 1)
	mov eax, sys_write
	mov ebx, dword ptr [rsi + FILE.fd]
	lea rcx, [rsp - 1]
	mov edx, 1
	syscall
	
	; if that failed (-1), return EOF (-1), otherwise the written char
	cmp rax, -1
	movne eax, edi
	static_assert EOF == -1 ; we're using this fact to avoid a mov
	ret

; int fputs(const char *str, FILE *stream)
fputs:
	; save the arguments
	push rdi
	push rsi
	
	; get the string length
	call strlen
	
	; write the string
	mov rdx, rax
	mov eax, sys_write
	pop rbx
	mov ebx, dword ptr [rbx + FILE.fd]
	pop rcx
	
	syscall
	
	ret ; return the number of characters written (returned from native call)
; int puts(const char *str)
puts:
	mov rsi, stdout
	call fputs
	mov edi, `\n`
	jmp putchar ; puts() also adds a new line char after string - c stdlib is weird
	
; size_t fwrite(const void *ptr, size_t size, size_t count, FILE *stream)
fwrite:
	; if size or count is zero, no-op
	cmp rsi, 0
	je .nop
	cmp rdx, 0
	je .nop
	
	; otherwise write the block
	mov eax, sys_write
	mov ebx, dword ptr [rcx + FILE.fd]
	mov rcx, rdi
	imul rdx, rsi
	syscall
	
	; return number of successes (rax holds number of bytes written from native call)
	xor rdx, rdx
	div rsi ; quotient stored in rax
	ret
	
	.nop: ; nop case returns zero and does nothing else
	xor rax, rax
	ret

; --------------------------------------

; the following formatting functions implicitly take a creader function in r15.
; the creader function takes the form int(*)(int), examining and returning the next character in the stream.
; if no more chars are available, EOF should be returned and all subsequent calls should do likewise.
; if the argument is nonzero, the character is extracted, otherwise it should remain in the stream for future calls.
; the creader function itself is allowed to store an argument in r14.
; as a contract, you should not modify the values of r14,r15 if you intend to use the creader function.

; int __scanf_u64_decimal(u64 *dest)
; reads a u64 value from the stream and stores it in dest.
; returns nonzero on success.
__scanf_u64_decimal:
	push r12 ; save this call-safe register (holds working value)
	push r13 ; save this call-safe register as well (holds the iteration index)
	push rdi ; save dest on the stack
	
	xor r12, r12 ; zero the working value
	xor r13, r13 ; zero iteration index

	.top:
		xor edi, edi
		call r15 ; peek the next character from the stream
		
		; if it's not a digit, break from the loop
		sub eax, '0' ; convert to binary
		cmp eax, 9
		ja .brk ; unsigned compare avoids having to test negative bounds as well
		
		; otherwise extract the character from the stream
		mov edi, 1
		call r15
		sub eax, '0'
		
		; fold in the digit
		xchg rax, r12
		mul qword 10
		jc .fail ; check for overflow from the multiply
		add r12, rax
		jc .fail ; check for overflow from the add
		
		inc r13
		jmp .top
	.brk:
	
	; if we failed on the first iteration, fail
	cmp r13, 0
	jz .fail
	
	pop rax
	mov qword ptr [rax], r12 ; store the result to dest
	pop r13
	pop r12
	mov eax, 1 ; return true
	ret
	
	.fail:
	pop rax
	pop r13
	pop r12
	xor eax, eax ; return false
	ret
; int __scanf_i64_decimal(i64 *dest)
; reads an i64 value from the strem and stores it in dest.
; returns nonzero on success.
__scanf_i64_decimal:
	push rdi ; save dest
	
	xor edi, edi
	call r15 ; peek the next char in the stream
	
	cmp eax, '+'
	je .sign
	cmp eax, '-'
	je .sign
	push dword '+' ; if no explicit sign char, put a + on the stack (see .sign)
	jmp .aft_sign
	
	.sign:
	mov edi, 1
	call r15 ; extract the sign character
	push eax ; store it on the stack
	.aft_sign:
	
	sub rsp, 8 ; create space for storing intermediate parse result
	mov rdi, rsp
	call __scanf_u64_decimal ; read the numeric value (store on stack)
	pop rdx ; pop the result off the stack immediately
	cmp eax, 0
	jnz .u64_success ; if that failed (zero) we fail as well (zero)
	add rsp, 4+8 ; remove stack space for dest and sign character
	ret
	.u64_success:
	
	pop eax ; pop the sign character off the stack
	cmp eax, '-'
	jne .aft_sign_fix
	neg rdx
	js .aft_sign_fix ; if result is negative, we didn't overflow
	pop rax
	xor eax, eax ; otherwise fail - return false
	ret
	.aft_sign_fix:
	
	pop rax ; pop dest off the stack
	mov qword ptr [rax], rdx ; store the final result to dest
	mov eax, 1 ; return true
	ret

; int __scanf_u32_decimal(u32 *dest)
__scanf_u32_decimal:
	push rdi ; store dest
	sub rsp, 8
	mov rdi, rsp
	call __scanf_u64_decimal ; parse a u64 value and put on stack
	pop rbx ; pop the result off the stack immediately
	cmp eax, 0
	jz .fail ; if that failed, we fail as well
	
	mov eax, ebx
	cmp rax, rbx
	jne .fail ; if the value cannot be represented as a u32, fail
	
	pop rdi
	mov dword ptr [rdi], eax
	mov eax, 1 ; return true
	ret
	
	.fail:
	pop rax
	xor eax, eax ; return false
	ret
; int __scanf_u16_decimal(u16 *dest)
__scanf_u16_decimal:
	push rdi ; store dest
	sub rsp, 8
	mov rdi, rsp
	call __scanf_u64_decimal ; parse a u64 value and put on stack
	pop rbx ; pop the result off the stack immediately
	cmp eax, 0
	jz .fail ; if that failed, we fail as well
	
	movzx eax, bx
	cmp rax, rbx
	jne .fail ; if the value cannot be represented as a u32, fail
	
	pop rdi
	mov word ptr [rdi], ax
	mov eax, 1 ; return true
	ret
	
	.fail:
	pop rax
	xor eax, eax ; return false
	ret
; int __scanf_u8_decimal(u8 *dest)
__scanf_u8_decimal:
	push rdi ; store dest
	sub rsp, 8
	mov rdi, rsp
	call __scanf_u64_decimal ; parse a u64 value and put on stack
	pop rbx ; pop the result off the stack immediately
	cmp eax, 0
	jz .fail ; if that failed, we fail as well
	
	movzx eax, bl
	cmp rax, rbx
	jne .fail ; if the value cannot be represented as a u32, fail
	
	pop rdi
	mov byte ptr [rdi], al
	mov eax, 1 ; return true
	ret
	
	.fail:
	pop rax
	xor eax, eax ; return false
	ret

; int __scanf_i32_decimal(i32 *dest)
__scanf_i32_decimal:
	push rdi ; store dest
	sub rsp, 8
	mov rdi, rsp
	call __scanf_i64_decimal ; parse an i64 value and put on stack
	pop rbx ; pop the result off the stack immediately
	cmp eax, 0
	jz .fail ; if that failed, we fail as well
	
	movsx rax, ebx
	cmp rax, rbx
	jne .fail ; if the value cannot be represented as a u32, fail
	
	pop rdi
	mov dword ptr [rdi], eax
	mov eax, 1 ; return true
	ret
	
	.fail:
	pop rax
	xor eax, eax ; return false
	ret
; int __scanf_i16_decimal(i16 *dest)
__scanf_i16_decimal:
	push rdi ; store dest
	sub rsp, 8
	mov rdi, rsp
	call __scanf_i64_decimal ; parse an i64 value and put on stack
	pop rbx ; pop the result off the stack immediately
	cmp eax, 0
	jz .fail ; if that failed, we fail as well
	
	movsx rax, bx
	cmp rax, rbx
	jne .fail ; if the value cannot be represented as a u32, fail
	
	pop rdi
	mov word ptr [rdi], ax
	mov eax, 1 ; return true
	ret
	
	.fail:
	pop rax
	xor eax, eax ; return false
	ret
; int __scanf_i8_decimal(i8 *dest)
__scanf_i8_decimal:
	push rdi ; store dest
	sub rsp, 8
	mov rdi, rsp
	call __scanf_i64_decimal ; parse an i64 value and put on stack
	pop rbx ; pop the result off the stack immediately
	cmp eax, 0
	jz .fail ; if that failed, we fail as well
	
	movsx rax, bl
	cmp rax, rbx
	jne .fail ; if the value cannot be represented as a u32, fail
	
	pop rdi
	mov byte ptr [rdi], al
	mov eax, 1 ; return true
	ret
	
	.fail:
	pop rax
	xor eax, eax ; return false
	ret
	
; void __scanf_skipws(void)
; skips white space characters as if by calling isspace().
__scanf_skipws:
	xor edi, edi
	call r15 ; peek the next char in the stream
	
	mov edi, eax
	call isspace
	cmp eax, 0
	jz .nonspace ; if it's not space, we're done
	
	; otherwise extract the char from the stream and repeat
	mov edi, 1
	call r15
	jmp __scanf_skipws
	
	.nonspace:
	ret
	
; int __vscanf(const char *fmt, arglist *args, creader : r15, creader_arg : r14)
; this serves as the implementation for all the various scanf functions.
; the format string and arglist should be passed as normal args.
; the arglist should already be advanced to the location of the first arg to store scan results to.
; the creader function and creader arg should be set up in registers r14 and r15
__vscanf:
	sub rsp, 32
	mov qword ptr [rsp + 0], rdi
	mov qword ptr [rsp + 8], rsi
	mov qword ptr [rsp + 16], r12 ; r12 will point to the character being processed in format string
	mov qword ptr [rsp + 24], r13 ; r13 will hold the total number of successful parse actions
	
	mov r12, rdi ; point r12 at the first character to process in the format string
	xor r13, r13 ; clear the number of successful actions
	
	jmp .loop_test
	.loop_body:
		cmp al, '%'
		jne .literal_char
		inc r12 ; skip to next char (format flag)
		mov al, byte ptr [r12] ; get the following character
		cmp al, 0
		jz .loop_break ; if it's a terminator, just break from the loop
		
		cmp al, 'd'
		je .i32_decimal
		cmp al, 'u'
		je .u32_decimal
		cmp al, '%'
		je .literal_nonwhite ; %% escape sequence
		
		; otherwise unknown format flag
		mov rdi, $str(`\n[[ERROR]] unrecognized scanf format flag\n`)
		mov rsi, stderr
		call fputs
		jmp .loop_break
		
		.i32_decimal:
		call __scanf_skipws ; this format flag implicitly skips white space before parsing
		mov rdi, qword ptr [rsp + 8] ; load the arglist
		call arglist_i64 ; get the next parse destination (pointer)
		mov rdi, rax
		call __scanf_i32_decimal ; parse the next i32 value into that location
		cmp eax, 0
		jz .loop_break ; if that failed, abort parsing
		inc r13 ; bump up the number of successful parse actions
		jmp .loop_aft
		
		.u32_decimal:
		call __scanf_skipws ; this format flag implicitly skips white space before parsing
		mov rdi, qword ptr [rsp + 8] ; load the arglist
		call arglist_i64 ; get the next parse destination (pointer)
		mov rdi, rax
		call __scanf_u32_decimal ; parse the next i32 value into that location
		cmp eax, 0
		jz .loop_break ; if that failed, abort parsing
		inc r13 ; bump up the number of successful parse actions
		jmp .loop_aft
		
		.literal_char: ; this is anything other than '%'
		movzx edi, al
		call isspace
		cmp eax, 0
		jz .literal_nonwhite
		call __scanf_skipws ; if it's a white space char, skip white space in the stream
		jmp .loop_aft
		.literal_nonwhite:
		
		; otherwise we need to match a character
		xor edi, edi
		call r15 ; peek the next character in the stream
		movzx ebx, byte ptr [r12] ; reload the char since we clobbered it
		cmp eax, ebx
		jne .loop_break ; if they differ, abort parsing
		mov edi, 1
		call r15 ; otherwise extract the character from the stream
	.loop_aft:
		inc r12
	.loop_test:
		mov al, byte ptr [r12] ; read the next char in format string
		cmp al, 0
		jnz .loop_body
	.loop_break:
	
	mov rax, r13 ; return number of successful parse actions
	mov r12, qword ptr [rsp + 16]
	mov r13, qword ptr [rsp + 24]
	add rsp, 32
	ret

; --------------------------------------

; int vfscanf(FILE *stream, const char *fmt, arglist *args)
vfscanf:
	push r14
	push r15
	
	mov r14, rdi
	mov rdi, rsi
	mov rsi, rdx
	mov r15, .__CREADER
	call __vscanf
	
	pop r15
	pop r14
	ret
	
	.__CREADER:
		cmp edi, 0
		mov rdi, r14
		jz fpeek
		jmp fgetc
; int fscanf(FILE *stream, const char *fmt, ...)
fscanf:
	mov r10, rsp
	push r15
	call arglist_start
	push rax
	push rsi
	push rdi
	mov rdi, rax
	call arglist_i64
	call arglist_i64
	
	mov rdx, rdi
	pop rdi
	pop rsi
	call vfscanf
	mov r15, rax
	
	pop rdi
	call arglist_end
	mov rax, r15
	pop r15
	ret

; int vscanf(const char *fmt, arglist *args)
vscanf:
	mov rdx, rsi
	mov rsi, rdi
	mov rdi, stdin
	jmp vfscanf
; int scanf(const char *fmt, ...)
scanf:
	mov r10, rsp
	push r15
	call arglist_start
	push rax
	push rdi
	mov rdi, rax
	call arglist_i64
	
	mov rsi, rdi
	pop rdi
	call vscanf
	mov r15, rax
	
	pop rdi
	call arglist_end
	mov rax, r15
	pop r15
	ret

; --------------------------------------

; the following formatting functions implicitly take a sprinter function in r15.
; the sprinter function takes the form u64(*)(const char*), printing the string and returning # chars written.
; the sprinter function itself is allowed to store an argument in r14.
; as a contract, you should not modify the values of r14,r15 if you intend to use the sprinter function.

; u64 __printf_u64_decimal(u64 val)
; prints the (unsigned) value and returns the number of characters written to the stream
__printf_u64_decimal:
	sub rsp, 21 ; we need 21 characters to hold the full (decimal) range of u64 (20 digits + terminator)
	lea r8, [rsp + 20] ; r8 points to the start of the string
	mov byte ptr [r8], 0 ; place a terminator at end of string
	mov rax, rdi ; put the value in rax for division
	mov r9d, 10 ; r9 holds the base (10) to divide by (DIV doesn't accept imm)
	
	.loop_top:
		xor rdx, rdx ; zero high bits for division
		div r9       ; divide by base - quot kept in rax, remainder (next char) stored in rdx
		add dl, '0'  ; convert next char (binary) to ascii
		
		dec r8                ; make room for another character
		mov byte ptr [r8], dl ; place the ascii into the string
		
		cmp rax, 0
		jnz .loop_top ; if quotient was nonzero repeat
	
	mov rdi, r8
	call r15 ; print the string using the sprinter function in r15
	
	add rsp, 21 ; clean up the stack space we allocated for the string
	ret ; return result from sprinter (number of characters written)
; u64 __printf_u32_decimal(u32 val)
__printf_u32_decimal:
	mov eax, eax             ; zero extend eax to 64-bit
	jmp __printf_u64_decimal ; then just refer to the 64-bit version
; u64 __printf_u16_decimal(u16 val)
__printf_u16_decimal:
	movzx eax, ax            ; zero extend ax to 64-bit
	jmp __printf_u64_decimal ; then just refer to the 64-bit version
; u64 __printf_u8_decimal(u8 val)
__printf_u8_decimal:
	movzx eax, al            ; zero extend al to 64-bit
	jmp __printf_u64_decimal ; then just refer to the 64-bit version
	
; u64 __printf_i64_decimal(i64 val)
; prints the (signed) value and returns the number of characters written to the stream
__printf_i64_decimal:
	cmp rdi, 0
	jl .negative
	jmp __printf_u64_decimal ; if not negative, just treat it as unsigned
	
	.negative:
	push rdi
	mov rdi, $str("-")
	call r15 ; print a '-' sign using the sprinter function in r15
	pop rdi
	
	push rax ; save #chars written by the sprinter for '-' (presumably 1, but no assumptions)
	neg rdi  ; negate the value (now non-negative)
	call __printf_u64_decimal ; print it as unsigned
	pop rbx
	add rax, rbx ; add to #chars written
	
	ret
; u64 __printf_i32_decimal(i32 val)
__printf_i32_decimal:
	movsx rax, eax           ; sign extend eax to 64-bit
	jmp __printf_i64_decimal ; then just refer to the 64-bit version
; u64 __printf_i16_decimal(i16 val)
__printf_i16_decimal:
	movsx rax, ax            ; sign extend ax to 64-bit
	jmp __printf_i64_decimal ; then just refer to the 64-bit version
; u64 __printf_i8_decimal(i8 val)
	movsx rax, al            ; sign extend al to 64-bit
	jmp __printf_i64_decimal ; then just refer to the 64-bit version
	
; printf format flag (prefix) enum
__vprintf_fmt: equ 0
	.minus: equ 1   ; - flag was used (left justify)
	.plus:  equ 2   ; + flag was used (showpos)
	.hash:  equ 4   ; # flag was used (showbase/showpoint depending on int/float)
	.zero:  equ 8   ; 0 flag was used (pad with zeros)
	.width: equ 16  ; width was specified (most things ignore this)
	.prec:  equ 32  ; precision was specified (most things ignore this)

__vprintf_scale: equ 0
	.default: equ 0
	.hh:      equ 1
	.h:       equ 2
	.l:       equ 3
	.ll:      equ 4
	.j:       equ 5
	.z:       equ 6
	.t:       equ 7
	.L:       equ 8
	
__vprintf_fmt_pack: equ 0
	.SIZE: equ 16
	
	.fmt:   equ 0  ; u32 collection of format flags
	.width: equ 4  ; u32 width to use (positive)
	.prec:  equ 8  ; u32 precision to use (positive)
	.scale: equ 12 ; u32 denotes size of operand

; int __vprintf_read_prefix(fmt_pack *res : rsi, arglist * : r10, const char *&str : r12);
; WARNING: nonstandard calling convention.
; reads all the relevant formatting info for the current item (after reading the % char).
; returns zero on success.
__vprintf_read_prefix:
	xor ecx, ecx ; clear ecx (will hold flags)
	
	.unord_flag_loop:
		mov al, byte ptr [r12]
		
		cmp al, '+'
		je .plus
		cmp al, '-'
		je .minus
		cmp al, '0'
		je .zero
		cmp al, '#'
		je .hash
		
		jmp .unord_flag_loop_done ; if it was none of those, we're done
		
		.plus:
			test ecx, __vprintf_fmt.plus ; test if this flag was already set (if so, invalid fmt)
			jnz .invalid
			or ecx, __vprintf_fmt.plus
			jmp .unord_flag_aft
		.minus:
			test ecx, __vprintf_fmt.minus ; test if this flag was already set (if so, invalid fmt)
			jnz .invalid
			or ecx, __vprintf_fmt.minus
			jmp .unord_flag_aft
		.zero:
			test ecx, __vprintf_fmt.zero ; test if this flag was already set (if so, invalid fmt)
			jnz .invalid
			or ecx, __vprintf_fmt.zero
			jmp .unord_flag_aft
		.hash:
			test ecx, __vprintf_fmt.hash ; test if this flag was already set (if so, invalid fmt)
			jnz .invalid
			or ecx, __vprintf_fmt.hash
			
	.unord_flag_aft:
		inc r12 ; on to next char
		jmp .unord_flag_loop
	.unord_flag_loop_done:
	
	xor eax, eax ; clear eax (will hold width)
	mov bl, byte ptr [r12] ; read the next char
	cmp bl, '*'
	je .param_width ; if char is * then width is specified via param
	sub bl, '0'
	cmp bl, 10
	jae .no_width ; if it's not a digit then there's no width specified
	
	or ecx, __vprintf_fmt.width ; mark that a width was specified
	inc r12    ; increment up to the next char
	mov al, bl ; move the 0-9 first digit into the width register
	.width_parsing:
		movzx ebx, byte ptr [r12] ; read the next character from format string
		sub bl, '0'
		cmp bl, 10
		jae .width_parsing_done ; if it's not a digit, we're done parsing width
		
		imul eax, 10 ; incorporate the next digit into the width value
		add eax, ebx
		inc r12
		jmp .width_parsing
	.width_parsing_done:
	jmp .no_width ; resume logic after width parsing
	
	.param_width:
	inc r12 ; increment up to the next char
	or ecx, __vprintf_fmt.width ; mark that a width was specified
	mov r11, rdi     ; save rdi in r11 for the main __vprintf func
	mov rdi, r10     ; load the arglist pointer
	call arglist_i32 ; get a 32-bit integer arg from the pack and use it as width
	mov rdi, r11
	
	.no_width:
	mov dword ptr [rsi + __vprintf_fmt_pack.width], eax ; store the width in the format pack
	
	xor eax, eax ; clear eax (will hold precision)
	cmp byte ptr [r12], '.'
	jne .no_prec ; if next char is not a . then there's no precision
	
	or ecx, __vprintf_fmt.prec ; mark that a precision was specified
	inc r12 ; skip the .
	
	mov bl, byte ptr [r12] ; read the first character of precision field from format string
	cmp bl, '*'
	je .param_prec ; if it's a * then we use a param precision value
	sub bl, '0'
	cmp bl, 10
	jae .invalid ; if it's not a digit then this format string is invalid
	
	inc r12    ; increment up to the next char
	mov al, bl ; move the 0-9 first digit into the width register
	.prec_parsing:
		movzx ebx, byte ptr [r12] ; read the next character from format string
		sub bl, '0'
		cmp bl, 10
		jae .prec_parsing_done ; if it's not a digit, we're done parsing precision
		
		imul eax, 10 ; incorporate the next digit into the precision value
		add eax, ebx
		inc r12
		jmp .prec_parsing
	.prec_parsing_done:
	jmp .no_prec ; resume logic after prec parsing
	
	.param_prec:
	inc r12 ; bump up to the next character
	mov r11, rdi     ; save rdi in r11 for the main __vprintf func
	mov rdi, r10     ; load the arglist pointer
	call arglist_i32 ; get a 32-bit integer arg from the pack and use it as precision
	mov rdi, r11
	
	.no_prec:
	mov dword ptr [rsi + __vprintf_fmt_pack.prec], eax ; store the precision in the format pack
	
	mov bl, byte ptr [r12] ; read the next char of the format string
	cmp bl, 'h'
	je .half_seq ; if it's an h we're in h or hh case (short/char)
	cmp bl, 'l'
	je .long_seq ; if it's an l we're in l or ll case (long/long long)
	cmp bl, 'j'
	je .j_scale ; if it's a j we're in intmax case
	cmp bl, 'z'
	je .z_scale ; if it's a z we're in size_t case
	cmp bl, 't'
	je .t_scale ; if it's a t we're in ptrdiff_t case
	cmp bl, 'L'
	je .L_scale ; if it's an L we're in long double case
	
	mov eax, __vprintf_scale.default ; otherwise use the default option and continue (no chars to extract)
	jmp .scale_done
	
	.L_scale:
	mov eax, __vprintf_scale.L
	inc r12 ; move to next char in format string
	jmp .scale_done
	
	.t_scale:
	mov eax, __vprintf_scale.t
	inc r12 ; move to next char in format string
	jmp .scale_done
	
	.z_scale:
	mov eax, __vprintf_scale.z
	inc r12 ; move to next char in format string
	jmp .scale_done
	
	.j_scale:
	mov eax, __vprintf_scale.j
	inc r12 ; move to next char in format string
	jmp .scale_done
	
	.half_seq:
	mov eax, __vprintf_scale.h
	inc r12 ; move to next char in format string
	cmp byte ptr [r12], 'h'
	jne .scale_done ; if it's not another h we're done with scale
	mov eax, __vprintf_scale.hh
	inc r12 ; consume the second h as well
	jmp .scale_done
	
	.long_seq:
	mov eax, __vprintf_scale.l
	inc r12 ; move to next char in format string
	cmp byte ptr [r12], 'l'
	jne .scale_done ; if it's not another l we're done with scale
	mov eax, __vprintf_scale.ll
	inc r12 ; consume the second l as well
	
	.scale_done:
	mov dword ptr [rsi + __vprintf_fmt_pack.scale], eax ; store scale info to format pack
	
	mov dword ptr [rsi + __vprintf_fmt_pack.fmt], ecx ; and finally, store the format flags to the format pack as well
	
	xor eax, eax ; return 0
	ret ; finally done - pack fully parsed and r12 now points to the mode character
	
	.invalid: ; this happens if the format string was invalid (failed to parse)
	mov eax, 1
	ret ; return nonzero to indicate failure
	
; int __vprintf(const char *fmt, arglist *args, sprinter : r15, sprinter_arg : r14)
; this serves as the implementation for all the various printf functions.
; the format string and arglist should be passed as normal args.
; the arglist should already be advanced to the location of the first arg to print.
; the sprinter function and sprinter arg should be set up in registers r14 and r15
__vprintf:
	.BUF_CAP: equ 63 ; amount of buffer space to put on the stack for efficiency
	.FMT_START: equ 32 ; starting position of fmt pack (has space before it for storing registers)
	.BUF_START: equ .FMT_START + __vprintf_fmt_pack.SIZE ; starting position of stack buffer (has space before it for fmt pack)
	.TMP_SIZE: equ 8 ; size of temp space for storing intermediate values on the stack
	.TMP_START: equ .BUF_START + (.BUF_CAP+1) ; starting position of temp space
	sub rsp, .BUF_START + (.BUF_CAP+1) + .TMP_SIZE ; put args and call safe registers on the stack + buffer space
	mov qword ptr [rsp + 0], rdi
	mov qword ptr [rsp + 8], rsi
	mov qword ptr [rsp + 16], r12 ; save call-safe register
	mov qword ptr [rsp + 24], r13 ; save call-safe register
	
	; put buffer size in rdi - this is meant to speed up writing to the buffer.
	; before a function call, buffer must be flushed, and afterwards this must be reset.
	xor rdi, rdi ; rdi holds buffer size
	
	mov r12, qword ptr [rsp + 0] ; r12 holds address of the character we're processing
	xor r13, r13 ; r13 holds the total number of characters written
	jmp .loop_tst
	.loop_bod:
		cmp al, '%'
		jne .simple_char ; if it's not a %, just print a simple character
		inc r12 ; skip to next char (format flag)
		mov al, byte ptr [r12] ; get the following character
		cmp al, 0
		jz .invalid ; if it's a terminator, invalid format string
		
		cmp al, '%'
		je .simple_char ; escape % can just be printed by simple char code
		
		; parse the format prefix
		lea rsi, [rsp + .FMT_START]
		mov r10, qword ptr [rsp + 8]
		call __vprintf_read_prefix
		cmp eax, 0
		jnz .invalid ; if that returned nonzero we failed to parse prefix
		
		mov al, byte ptr [r12] ; we need to reload the format character after parsing prefix (pos moved)
		
		cmp al, 'd'
		je .i32_decimal
		cmp al, 'i'
		je .i32_decimal
		cmp al, 'u'
		je .u32_decimal
		cmp al, 's'
		je .string
		cmp al, 'c'
		je .char
		
		; otherwise unknown flag
		.invalid:
		push rdi
		mov rdi, $str(`\n[[ERROR]] unrecognized printf format character\n`)
		mov rsi, stderr
		call fputs
		pop rdi
		jmp .loop_brk
		
		.u32_decimal:
		call .__FLUSH_BUFFER ; flush the buffer before we do the formatted output
		mov rdi, qword ptr [rsp + 8] ; load the arglist
		call arglist_i32 ; get the next int arg
		mov edi, eax ; put in rdi (implicitly zero extended)
		call __printf_u64_decimal ; print it (unsigned) (decimal)
		add r13, rax ; update total printed chars
		xor rdi, rdi ; reset the buffer after formatted output
		jmp .loop_aft
		
		.i32_decimal:
		call .__FLUSH_BUFFER ; flush the buffer before we do the formatted output
		mov rdi, qword ptr [rsp + 8] ; load the arglist
		call arglist_i32 ; get the next int arg
		movsx rdi, eax
		call __printf_i64_decimal ; print it (signed) (decimal)
		add r13, rax ; update total printed chars
		xor rdi, rdi ; reset the buffer after formatted output
		jmp .loop_aft
		
		.string:
		call .__FLUSH_BUFFER ; flush the buffer before we do the formatted output
		mov rdi, qword ptr [rsp + 8] ; load the arglist
		call arglist_i64 ; get the pointer (64-bit integer)
		mov rdi, rax
		call r15 ; print the string using the sprinter function
		add r13, rax ; update total printed chars
		xor rdi, rdi ; reset the buffer after formatted output
		jmp .loop_aft
		
		.char:
		mov qword ptr [rsp + .TMP_START], rdi ; save buffer size in tmp space
		mov rdi, qword ptr [rsp + 8]          ; load the arglist
		call arglist_i8                       ; get the character to print (8-bit integer) (now in al)
		mov rdi, qword ptr [rsp + .TMP_START] ; reload the buffer size
		
		; FALL THROUGH INTENTIONAL
		
		.simple_char:
		cmp rdi, .BUF_CAP
		jb .simple_char_append ; if the buffer has space, just append
		mov byte ptr [rsp + .TMP_START], al ; otherwise store the character in tmp space (in case we clobber it)
		call .__FLUSH_BUFFER                ; then flush the (full) buffer
		xor rdi, rdi                        ; and reset it
		mov al, byte ptr [rsp + .TMP_START] ; reload the character to append from tmp space
		.simple_char_append:
		mov byte ptr [rsp + .BUF_START + rdi], al ; append the character to the buffer
		inc rdi ; and bump up buffer size
	.loop_aft:
		inc r12
	.loop_tst:
		mov al, byte ptr [r12]
		cmp al, 0
		jnz .loop_bod
	.loop_brk:

	; perform one final buffer flush in case we had anything left in it
	call .__FLUSH_BUFFER

	add rsp, .BUF_START + (.BUF_CAP+1) + .TMP_SIZE ; clean up stack space
	ret
; this is a pseudo-function to call which flushes buffer.
; the buffer must be reinitialized after this operation (e.g. after any functions calls).
.__FLUSH_BUFFER:
	cmp rdi, 0
	jz .__FLUSH_BUFFER_noop ; if the buffer is empty we don't need to do the overhead of printing it
	
	; terminate the buffer (C string)
	mov byte ptr [rsp + 8 + .BUF_START + rdi], 0 ; +8 skips the return address
	; call the sprinter function
	lea rdi, [rsp + 8 + .BUF_START]
	call r15
	; add #characters written to total char count
	add r13, rax
	
	.__FLUSH_BUFFER_noop:
	ret

; --------------------------------------

; int vfprintf(FILE *stream, const char *fmt, arglist *args)
vfprintf:
	push r14
	push r15
	
	mov r14, rdi
	mov rdi, rsi
	mov rsi, rdx
	mov r15, .__SPRINTER
	call __vprintf
	
	pop r15
	pop r14
	ret
	
	.__SPRINTER:
		mov rsi, r14
		jmp fputs
; int fprintf(FILE *stream, const char *fmt, ...)
fprintf:
	mov r10, rsp
	push r15
	call arglist_start
	push rax
	push rsi
	push rdi
	mov rdi, rax
	call arglist_i64
	call arglist_i64

	mov rdx, rdi
	pop rdi
	pop rsi
	call vfprintf
	mov r15, rax
	
	pop rdi
	call arglist_end
	mov rax, r15
	pop r15
	ret

; int vprintf(const char *fmt, arglist *args)
vprintf:
	mov rdx, rsi
	mov rsi, rdi
	mov rdi, stdout
	jmp vfprintf
; int printf(const char *fmt, ...)
printf:
	mov r10, rsp
	push r15
	call arglist_start
	push rax
	push rdi
	mov rdi, rax
	call arglist_i64
	
	mov rsi, rdi
	pop rdi
	call vprintf
	mov r15, rax
	
	pop rdi
	call arglist_end
	mov rax, r15
	pop r15
	ret
	
; --------------------------------------

; int ungetc(int character, FILE *stream)
ungetc:
	mov dword ptr [rsi + FILE.ungetc_ch], edi ; discard old ungetc_ch if present
	mov eax, edi ; return the character
	ret

; int getchar(void)
getchar:
	mov rdi, stdin
; int fgetc(FILE *stream)
fgetc:
	mov eax, dword ptr [rdi + FILE.ungetc_ch]
	cmp eax, EOF
	jne .fetch_ungetc_ch ; if there's an unget char, get that

	; otherwise read a character from the stream (native buffers for us)
	mov eax, sys_read
	mov ebx, dword ptr [rdi + FILE.fd]
	lea rcx, byte ptr [rsp - 1] ; place the read character on the stack (red zone)
	mov edx, 1
	syscall
	
	; if that failed, return EOF
	cmp rax, 0
	jle .fail
	; otherwise return the read character
	movzx eax, byte ptr [rsp - 1]
	ret
	
	.fail:
	mov eax, EOF
	ret
	
	.fetch_ungetc_ch:
	mov dword ptr [rdi + FILE.ungetc_ch], EOF ; mark ungetc char as eof (none)
	ret ; and return the old ungetc char value

; int fpeek(FILE *stream) -- nonstandard convenience function
fpeek:
	call fgetc
	mov rsi, rdi
	mov edi, eax
	jmp ungetc

; --------------------------------------

; FILE *fopen(const char *filename, const char *mode)
fopen:
	mov al, 0 ; + flag
	mov bl, 0 ; b flag

	mov r8, rsi
	jmp .loop_tst
	.loop_top:
		cmp dl, '+'
		move al, 1
		cmp dl, 'b'
		move bl, 1
	.loop_aft:
		inc r8
	.loop_tst:
		mov dl, byte ptr [r8]
		cmp dl, 0
		jne .loop_top
	
	xor r8, r8 ; flags
	
	mov dl, byte ptr [rsi]
	cmp dl, 'r' ; if reading
	je .reading
	cmp dl, 'w' ; if writing
	je .writing
	cmp dl, 'a' ; if appending
	je .appending
	xor rax, rax ; otherwise invalid mode
	ret

	.reading:
	cmp al, 0
	movz  r8, O_RDONLY
	movnz r8, O_RDWR
	jmp .finish
	
	.writing:
	cmp al, 0
	movz  r8, O_CREAT | O_WRONLY | O_TRUNC
	movnz r8, O_CREAT | O_RDWR   | O_TRUNC
	jmp .finish
	
	.appending:
	cmp al, 0
	movz  r8, O_CREAT | O_WRONLY | O_APPEND
	movnz r8, O_CREAT | O_RDWR   | O_APPEND
	
	.finish:
	; call native open
	mov eax, sys_open
	mov rbx, rdi
	mov rcx, r8
	syscall
	; if it fails, return null
	cmp eax, -1
	jne .success
	xor rax, rax
	ret
	.success:
	
	push eax ; save the fd
	
	; allocate the FILE object
	mov rdi, FILE.SIZE
	call malloc
	; if it fails, return null
	cmp rax, 0
	jne .success_2
	xor rax, rax
	ret
	.success_2:
	
	; initialize the FILE object
	pop dword ptr [rax + FILE.fd] ; restore the fd
	mov dword ptr [rax + FILE.ungetc_ch], EOF ; set no ungetc char
	mov dword ptr [rax + FILE.static], 0 ; set as not static (will pass to free())
	
	; return address of the FILE object
	ret
	
; int fclose(FILE *stream)
fclose:
	call fflush ; flush the stream
	
	; invoke native close
	mov eax, sys_close
	mov ebx, dword ptr [rdi + FILE.fd]
	syscall
	push eax ; save native close result
	
	; if non-static, free the FILE object
	cmp dword ptr [rdi + FILE.static], 0
	jnz .done
	call free ; free the FILE object
	.done:
	
	pop eax ; return native close result
	ret

; int fflush(FILE *stream)
fflush:
	xor eax, eax ; CSX64 does this for us, so no need to buffer
	ret
	
; --------------------------------------

segment .data

align FILE.ALIGN
stdin:
	dd 0   ; fd
	dd EOF ; ungetc_ch
	dd 1   ; static
static_assert $-stdin == FILE.SIZE

align FILE.ALIGN
stdout:
	dd 1   ; fd
	dd EOF ; ungetc_ch
	dd 1   ; static
static_assert $-stdout == FILE.SIZE
	
align FILE.ALIGN
stderr:
	dd 2   ; fd
	dd EOF ; ungetc_ch
	dd 1   ; static
static_assert $-stderr == FILE.SIZE
