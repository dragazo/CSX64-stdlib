; source http://www.cplusplus.com/reference/cstdio/
; needs a TON of file handling code

; --------------------------------------

global EOF
global stdin, stdout, stderr

; --------------------------------------

global fputc, putc, putchar
global fputs, puts

; --------------------------------------

global fopen, fflush, fclose

; --------------------------------------

extern malloc, free
extern strlen

; --------------------------------------

segment .text

FILE:
	.ALIGN:  equ 4
	.SIZE:   equ 8
	
	.fd:     equ 0 ; int
	.static: equ 4 ; int (bool)
	
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
	ret
; int putchar(int ch)
putchar:
	mov rsi, stdout
	call fputc
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
	
	ret
; int puts(const char *str)
puts:
	mov rsi, stdout
	call fputs
	ret

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
	
	; return number of successes
	xor rdx, rdx
	div rsi ; quotient stored in rax
	ret
	
	.nop: ; nop case returns zero and does nothing else
	xor rax, rax
	ret
    
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

EOF: equ -1

align FILE.ALIGN
stdin:
	dd 0 ; fd
	dd 1 ; static
static_assert $-stdin == FILE.SIZE

align FILE.ALIGN
stdout:
	dd 1 ; fd
	dd 1 ; static
static_assert $-stdout == FILE.SIZE
	
align FILE.ALIGN
stderr:
	dd 2 ; fd
	dd 1 ; static
static_assert $-stderr == FILE.SIZE
