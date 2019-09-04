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
global fprintf

; --------------------------------------

global ungetc, fgetc, fpeek

; --------------------------------------

global fopen, fflush, fclose

; --------------------------------------

extern arglist_start, arglist_end
extern arglist_i64, arglist_f64

extern malloc, free
extern strlen

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

; int puts(const char *str)
puts:
	mov rsi, stdout
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
	mov rax, rsi ; put the value in rax for division
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
		
; u64 __printf_i64_decimal(i64 val)
; prints the (signed) value and returns the number of characters written to the stream
__printf_i64_decimal:
	cmp rsi, 0
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

; int __vprintf(const char *fmt, arglist *args, sprinter : r15, sprinter_arg : r14)
; this serves as the implementation for all the various fprint functions.
; the format string and arglist should be passed as normal args.
; the arglist should already be advanced to the location of the first arg to print.
; the sprinter function and sprinter args should be set up in registers r14,r15
__vprintf:
	.BUF_CAP: equ 63 ; amount of buffer space to put on the stack for efficiency
	.BUF_START: equ 32 ; starting position of stack buffer (also amount of space for storing registers)
	sub rsp, .BUF_START + (.BUF_CAP+1) ; put args and call safe registers on the stack + buffer space
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
		jz .loop_brk ; if it's a terminator, just break from the loop
		
		cmp al, 'd'
		je .i64_decimal
		cmp al, 'i'
		je .i64_decimal
		cmp al, 'u'
		je .u64_decimal
		jmp .loop_aft ; if we don't recognize the format flag, just skip it
		
		.u64_decimal:
		call .__FLUSH_BUFFER ; flush the buffer before we do the formatted output
		mov rdi, qword ptr [rsp + 8] ; load the arglist
		call arglist_i64 ; get the next int arg
		mov rdi, rax
		call __printf_u64_decimal ; print it (unsigned) (decimal)
		add r13, rax ; update total printed chars
		xor rdi, rdi ; reset the buffer after formatted output
		jmp .loop_aft
		
		.i64_decimal:
		call .__FLUSH_BUFFER ; flush the buffer before we do the formatted output
		mov rdi, qword ptr [rsp + 8] ; load the arglist
		call arglist_i64 ; get the next int arg
		mov rdi, rax
		call __printf_i64_decimal ; print it (signed) (decimal)
		add r13, rax ; update total printed chars
		xor rdi, rdi ; reset the buffer after formatted output
		jmp .loop_aft
		
		.simple_char:
		cmp rdi, .BUF_CAP
		jb .simple_char_append ; if the buffer has space, just append
		call .__FLUSH_BUFFER   ; otherwise flush the buffer
		xor rdi, rdi           ; and reset it
		mov al, byte ptr [r12] ; also reload the character since we might clobber it
		.simple_char_append:
		mov byte ptr [rsp + .BUF_START + rdi], al ; append al to the buffer
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
	
	add rsp, .BUF_START + (.BUF_CAP+1) ; clean up stack space
	ret
; this is a pseudo-function to call which flushes buffer.
; the buffer must be reinitialized after this operation (e.g. after any functions calls).
.__FLUSH_BUFFER:
	; terminate the buffer (C string)
	mov byte ptr [rsp + 8 + .BUF_START + rdi], 0 ; +8 skips the return address
	; call the sprinter function
	lea rdi, [rsp + 8 + .BUF_START]
	call r15
	; add #characters written to total char count
	add r13, rax
	ret

; --------------------------------------

; int vfprintf(FILE *stream, comst char *fmt, arglist *args)
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
	
; --------------------------------------

; int ungetc(int character, FILE *stream)
ungetc:
	mov dword ptr [rsi + FILE.ungetc_ch], edi ; discard old ungetc_ch if present
	mov eax, edi ; return the character
	ret

; int fgetc(FILE *stream)
fgetc:
	mov eax, dword ptr [rdi + FILE.ungetc_ch]
	cmp eax, EOF
	je .fetch_ungetc_ch ; if there's an unget char, get that
	
	; otherwise read a character from the stream (native buffers for us)
	mov eax, sys_read
	mov ebx, dword ptr [rdi + FILE.fd]
	lea rcx, byte ptr [rsp - 1] ; place the read character on the stack (red zone)
	mov edx, 1
	syscall
	
	; if that failed, return EOF
	cmp rax, 0
	jz .fail
	; otherwise return the read character
	mov al, byte ptr [rsp - 1]
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
		mov dl, [r8]
		cmp dl, 0
		jne .loop_top
	
	xor r8, r8 ; flags
	
	mov dl, [rsi]
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
