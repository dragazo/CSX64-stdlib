; source http://www.cplusplus.com/reference/cassert/

global assert

extern abort

segment .text

; void assert(int);
assert:
    cmp edi, 0
    jnz .ret
    
    ; write error message
    mov eax, sys_write
    mov ebx, 2
    mov ecx, err_msg
    mov edx, err_msg_len
    syscall
    
    ; abort execution
    call abort
    
    .ret: ret

segment .rodata

err_msg: db `\n\nASSERTION FAILURE\n\n`
err_msg_len: equ $-err_msg
