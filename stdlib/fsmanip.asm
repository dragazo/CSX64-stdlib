; source http://www.cplusplus.com/reference/cstdio/
; needs a TON of file handling code

; --------------------------------------

global remove
global rename

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
