; source http://www.cplusplus.com/reference/cstdio/
; needs a TON of file handling code

; --------------------------------------

global remove
global rename

; --------------------------------------

extern malloc, free

; --------------------------------------
    
segment .text

; int remove(const char *path);
remove:
    ; delete the file
    mov eax, sys_unlink
    mov rbx, rdi
    syscall
    ret

; int rename(const char *from, const char *to);
rename:
    ; rename the file
    mov eax, sys_rename
    mov rbx, rdi
    mov rcx, rsi
    syscall
    ret

; --------------------------------------

; FILE *fopen(const char *path, const char *mode)
fopen:
    ; decode mode from first char - into r8b
    mov dl, [rsi]
    cmp dl, 'r' ; read mode
    move r8b, 1
    je .decoded
    cmp dl, 'w' ; write mode
    move r8b, 2
    je .decoded
    cmp dl, 'a' ; append mode
    move r8b, 3
    je .decoded
    ; otherwise unknown open mode
    xor rax, rax
    ret
    
    .decoded:
    ; decode the rest of the characters
    
    
; --------------------------------------

segment .rodata




