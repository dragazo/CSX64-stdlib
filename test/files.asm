#!echo [[ERROR]] run as ./csx.exe -s --fs

global main

extern EOF
extern puts, fputs
extern fopen, fflush, fclose
extern fgetc
extern remove

extern stdin, stdout, stderr

segment .text

main:
	; make sure we can open the file
	mov rdi, path
	mov rsi, write_mode
	call fopen
	; make sure it succeeds
	cmp rax, 0
	jnz .success_1
	mov rdi, open_err_msg_1
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
	mov rdi, write_failure
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
	mov rdi, close_err_msg_1
	call puts
	mov eax, 2
	ret
	.success_2:
	
	; make sure we can open the file again
	mov rdi, path
	mov rsi, read_mode
	call fopen
	; make sure it succeeds
	cmp rax, 0
	jnz .success_3
	mov rdi, open_err_msg_2
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
	mov rdi, memory_leak_msg
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
	mov rdi, close_err_msg_2
	call puts
	mov eax, 2
	ret
	.success_4:
	
	; delete the file (must succeed since we know it exists)
	mov rdi, path
	call remove
	cmp eax, 0
	jz .was_deleted
	mov rdi, delete_failure
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
	mov rdi, still_existed
	mov rsi, stderr
	call fputs
	mov eax, -67451
	ret
	.still_existed_after_delete:
	
	; and at this point opening the file in read mode should fail
	mov rdi, path
	mov rsi, read_mode
	call fopen
	cmp eax, 0
	jz .successfully_failed_to_open
	mov rdi, open_read_file_that_didnt_exist
	mov rsi, stderr
	call fputs
	mov eax, -666
	ret
	.successfully_failed_to_open:
	
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
	
	mov rdi, not_empty_msg
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
	jmp .loop_tst
	.loop_top:
		; read the next char from file
		mov rdi, r14
		call fgetc
		
		; if that was EOF the file is missing content
		cmp eax, EOF
		jne .good
		mov rdi, missing_content_msg
		mov rsi, stderr
		call fputs
		pop r15
		pop r14
		ret ; eax currently holds nonzero
		.good:
		
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
	mov rdi, extra_content_msg
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

path: db "temp_files_test.txt", 0
read_mode: db "rb", 0
write_mode: db "wb", 0

content: db `this is the content\nof the file\nthat should be written\n\n...\n`, 0
.len: equ $-content-1

open_err_msg_1: db "failed to open file (1)", 0
close_err_msg_1: db "failed to close file (1)", 0
open_err_msg_2: db "failed to open file (2)", 0
close_err_msg_2: db "failed to close file (2)", 0

memory_leak_msg: db "memory leak: file was not in expected location", 0

not_empty_msg: db "file is not empty", 0

missing_content_msg: db "file missing content", 0
extra_content_msg: db "file had extra content", 0

write_failure: db "failed to write the content", 0

delete_failure: db "failed to delete the file", 0
still_existed: db "file was deleted but still exists", 0

open_read_file_that_didnt_exist: db "somehow opened a file for reading that didn't exist", 0

segment .bss

read_area_len: equ 127
read_area: resb read_area_len + 1
