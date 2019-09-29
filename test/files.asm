#!csx.exe -us

global main

extern EOF
extern puts, fputs
extern fopen, fflush, fclose
extern fgetc, fpeek
extern remove
extern fprintf

extern stdin, stdout, stderr

segment .text

; intern testing
mov rdi, $str("file is not ")
mov rdi, $str("file is not empty")
mov rdi, $str(" is not empty")
mov rdi, $str("is not empty")
mov rdi, $str("pty")
mov rdi, $str("g file is not empty")

main:
	; make sure we can open the file
	mov rdi, path
	mov rsi, $str("wb")
	call fopen
	; make sure it succeeds
	cmp rax, 0
	jnz .success_1
	mov rdi, $str('failed', 'to',"open" , 'f', `ile (`,'1'+0,`)`)
	call puts
	mov eax, 1
	ret
	.success_1:
	
	mov r15, rax ; store pointer for later test
	
	; write the content
	mov rdi, content
	mov rsi, r15
	call fputs
	cmp eax, content.len
	je .write_good
	mov rdi, $str("failed to write the content")
	mov rsi, stderr
	call fputs
	mov eax, -404
	ret
	.write_good:
	
	; make sure we can close it
	mov rdi, r15
	call fclose
	; make sure it succeeds
	cmp rax, 0
	jz .success_2
	mov rdi, $bin("failed to close file (1)", 0)
	call puts
	mov eax, 2
	ret
	.success_2:
	
	; make sure we can open the file again
	mov rdi, path
	mov rsi, $STR("rb")
	call fopen
	; make sure it succeeds
	cmp rax, 0
	jnz .success_3
	mov rdi, $BIN("failed to open file (2)", +--+0x00)
	call puts
	mov eax, 1
	ret
	.success_3:
	
	mov r14, rax ; store pointer for later test
	
	; make sure the file has the correct content
	mov rdi, r15
	call assert_content
	cmp eax, 0
	jz .content_good
	ret
	.content_good:
	
	cmp r14, r15
	je .no_leak
	mov rdi, $str("memory leak: file was not in expected location")
	call puts
	mov eax, -1044
	ret
	.no_leak:
	
	; make sure we can close it
	mov rdi, r14
	call fclose
	; make sure it succeeds
	cmp rax, 0
	jz .success_4
	mov rdi, $str("failed to close file (2)")
	call puts
	mov eax, 2
	ret
	.success_4:
	
	; delete the file (must succeed since we know it exists)
	mov rdi, path
	call remove
	cmp eax, 0
	jz .was_deleted
	mov rdi, $str("failed to delete the file")
	mov rsi, stderr
	call fputs
	mov eax, 12345
	ret
	.was_deleted:
	
	; delete it again (this time it should fail)
	mov rdi, path
	call remove
	cmp eax, 0
	jnz .still_existed_after_delete
	mov rdi, $str("file was deleted but still exists")
	mov rsi, stderr
	call fputs
	mov eax, -67451
	ret
	.still_existed_after_delete:
	
	; and at this point opening the file in read mode should fail
	mov rdi, path
	mov rsi, $str('rb')
	call fopen
	cmp eax, 0
	jz .successfully_failed_to_open
	mov rdi, $str("somehow opened a file for reading that didn't exist")
	mov rsi, stderr
	call fputs
	mov eax, -666
	ret
	.successfully_failed_to_open:
	
	mov rdi, $str("Succeeded all tests prior to closing standard streams")
	call puts
	
	; make sure we can close all the standard streams
	mov rdi, stdin
	call fclose
	mov rdi, stdout
	call fclose
	mov rdi, stderr
	call fclose
	
	xor eax, eax
    ret

; int assert_empty(FILE *file)
; asserts that the file is empty (returns non-zero on failure)
assert_empty:
	call fgetc ; get the next char
	cmp eax, EOF
	je .good
	
	mov rdi, $str("file is not empty")
	mov rsi, stderr
	call fputs
	mov eax, 1
	ret
	
	.good:
	xor eax, eax
	ret
	
; int assert_content(FILE *file)
; asserts that the file contains (only) the content string (returns non-zero on failure)
assert_content:
	push r14
	push r15
	
	mov r14, rdi ; store file address in r14
	
	xor r15, r15
	jmp .peek_loop_test
	.peek_loop_body:
		; peek the next (first) char from file
		mov rdi, r14
		call fpeek
		
		; should not be EOF
		cmp eax, EOF
		jne .peek_good
		mov rdi, $str("failed to peek a character from file")
		mov rsi, stderr
		call fputs
		pop r15
		pop r14
		ret ; eax currently holds nonzero
		.peek_good:
		
		; should be the first char from content string
		movzx ebx, byte ptr [content]
		cmp eax, ebx
		je .peek_cmp_good
		mov rdi, stderr
		mov rsi, $str(`peeked char was wrong at peek iter %d: expected '%d' got '%d'\n`)
		mov edx, r15d
		movzx ecx, byte ptr [content]
		mov r8d, eax
		mov al, 0
		call fprintf
		pop r15
		pop r14
		ret ; eax currently holds nonzero
		.peek_cmp_good:
	.peek_loop_aft:
		inc r15
	.peek_loop_test:
		cmp r15, 47 ; arbitrary loop count
		jl .peek_loop_body
		
	
	xor r15, r15
	jmp .loop_tst
	.loop_top:
		; read the next char from file
		mov rdi, r14
		call fgetc
		
		; if that was EOF the file is missing content
		cmp eax, EOF
		jne .good
		mov rdi, $str("file missing content")
		mov rsi, stderr
		call fputs
		pop r15
		pop r14
		ret ; eax currently holds nonzero
		.good:
		
		; make sure this byte is the expected value
		cmp al, byte ptr [content + r15]
		je .same
		mov rdi, stderr
		mov rsi, $str(`file differed from expected at byte %d: expected '%d' got '%d'\n`)
		mov rdx, r15
		movzx ecx, byte ptr [content + r15]
		movzx r8d, al
		mov al, 0
		call fprintf
		pop r15
		pop r14
		mov eax, 1 ; return nonzero
		ret
		.same:
		
	.loop_aft:
		inc r15
	.loop_tst:
		cmp byte ptr [content + r15], 0
		jnz .loop_top
	
	; now the file should be empty (at EOF)
	mov rdi, r14
	call fgetc
	cmp eax, EOF
	je .now_empty
	mov rdi, $str("file had extra content")
	mov rsi, stderr
	call fputs
	pop r15
	pop r14
	mov eax, -46 ; arbitrary nonzero value
	ret
	.now_empty:
	
	pop r15
	pop r14
	xor eax, eax
	ret
	
	
segment .rodata

path: equ $str("temp_files_test.txt")

content: db `this is the content\nof the file\nthat should be written\n\n...\n`, 0
.len: equ $-content-1

segment .bss

read_area_len: equ 127
read_area: resb read_area_len + 1
