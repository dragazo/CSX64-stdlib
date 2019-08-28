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

; --------------------------------------

global ungetc, fgetc, fpeek

; --------------------------------------

global fopen, fflush, fclose

; --------------------------------------

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
