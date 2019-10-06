#!csx.exe -s

global main

extern printf, exit, puts

extern iscntrl, isblank, isspace
extern isupper, islower, isalpha
extern isdigit, isxdigit, isalnum
extern ispunct, isgraph, isprint
extern tolower, toupper

segment .text

; r8:  correct answer array
; r9:  function to call
; r10: function name
tester:
	xor ebx, ebx
	.top:
		mov edi, ebx
		call r9
		cmp al, byte ptr [r8 + rbx]
		jne .incorrect
	.aft:
		inc bl
		jnz .top
	ret
	
	.incorrect:
	mov rdi, $str(`%s: answer for byte %u incorrect - expected %u\n`)
	mov rsi, r10
	mov edx, ebx
	movzx ecx, byte ptr [r8 + rbx]
	mov al, 0
	call printf
	
	.fail:
	mov edi, 1
	call exit
	
main:
	mov r8, iscntrl_ans
	mov r9, iscntrl
	mov r10, $str("iscntrl")
	call tester
	
	mov r8, isblank_ans
	mov r9, isblank
	mov r10, $str("isblank")
	call tester
	
	mov r8, isspace_ans
	mov r9, isspace
	mov r10, $str("isspace")
	call tester
	
	mov r8, isupper_ans
	mov r9, isupper
	mov r10, $str("isupper")
	call tester
	
	mov r8, islower_ans
	mov r9, islower
	mov r10, $str("islower")
	call tester
	
	mov r8, isalpha_ans
	mov r9, isalpha
	mov r10, $str("isalpha")
	call tester
	
	mov r8, isdigit_ans
	mov r9, isdigit
	mov r10, $str("isdigit")
	call tester
	
	mov r8, isxdigit_ans
	mov r9, isxdigit
	mov r10, $str("isxdigit")
	call tester
	
	mov r8, isalnum_ans
	mov r9, isalnum
	mov r10, $str("isalnum")
	call tester
	
	mov r8, ispunct_ans
	mov r9, ispunct
	mov r10, $str("ispunct")
	call tester
	
	mov r8, isgraph_ans
	mov r9, isgraph
	mov r10, $str("isgraph")
	call tester
	
	mov r8, isprint_ans
	mov r9, isprint
	mov r10, $str("isprint")
	call tester
	
	mov r8, tolower_ans
	mov r9, tolower
	mov r10, $str("tolower")
	call tester
	
	mov r8, toupper_ans
	mov r9, toupper
	mov r10, $str("toupper")
	call tester
	
	mov rdi, $str("all good")
	call puts
	
	xor eax, eax
	ret

segment .bss

name_cap: equ 32
name: resb name_cap + 1

segment .rodata

align 256 ; just to make sure it'll do it

iscntrl_ans:
times 32  db 1
times 95  db 0
          db 1
times 128 db 0
static_assert $-iscntrl_ans == 256

isblank_ans:
times 9   db 0
          db 1
times 22  db 0
          db 1
times 95  db 0
times 128 db 0
static_assert $-isblank_ans == 256

isspace_ans:
times 9   db 0
times 5   db 1
times 18  db 0
          db 1
times 95  db 0
times 128 db 0
static_assert $-isspace_ans == 256

isupper_ans:
times 0x41 db 0
times 26   db 1
times 37   db 0
times 128  db 0
static_assert $-isupper_ans == 256

islower_ans:
times 0x61 db 0
times 26   db 1
times 5    db 0
times 128  db 0
static_assert $-islower_ans == 256

isalpha_ans:
times 0x41 db 0
times 26   db 1
times 6    db 0
times 26   db 1
times 5    db 0
times 128  db 0
static_assert $-isalpha_ans == 256

isdigit_ans:
times 0x30 db 0
times 10   db 1
times 70   db 0
times 128  db 0
static_assert $-isdigit_ans == 256

isxdigit_ans:
times 0x30 db 0
times 10   db 1
times 7    db 0
times 6    db 1
times 20   db 0
times 6    db 0
times 6    db 1
times 20   db 0
times 5    db 0
times 128  db 0
static_assert $-isxdigit_ans == 256

isalnum_ans:
times 0x30 db 0
times 10   db 1
times 7    db 0
times 26   db 1
times 6    db 0
times 26   db 1
times 5    db 0
times 128  db 0
static_assert $-isalnum_ans == 256

ispunct_ans:
times 0x21 db 0
times 15   db 1
times 10   db 0
times 7    db 1
times 26   db 0
times 6    db 1
times 26   db 0
times 4    db 1
           db 0
times 128  db 1
static_assert $-ispunct_ans == 256

isgraph_ans:
times 0x21 db 0
times 94   db 1
           db 0
times 128  db 1
static_assert $-isgraph_ans == 256

isprint_ans:
times 0x20 db 0
times 95   db 1
           db 0
times 128  db 1
static_assert $-isprint_ans == 256

tolower_ans:
times 0x41 db $i
times 26   db 'a' + $i
times 6    db 0x5b + $i
times 26   db 'a' + $i
times 5    db 0x7b + $i
times 128  db 128 + $i
static_assert $-tolower_ans == 256

toupper_ans:
times 0x41 db $i
times 26   db 'A' + $i
times 6    db 0x5b + $i
times 26   db 'A' + $i
times 5    db 0x7b + $i
times 128  db 128 + $i
static_assert $-toupper_ans == 256
