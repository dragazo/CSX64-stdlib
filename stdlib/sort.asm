global bsearch, qsort

; --------------------------------------

extern memcpy
extern malloc, free

; --------------------------------------

segment .text

; void *bsearch(const void *key, const void *base, size_t num, size_t size, int (*cmp)(const void*, const void*));
bsearch:
    ; directly from args:
    ; rsi = base
    ; rdx = num
    
    ; migrating to call-safe registers:
    ; r13 = key
    ; r14 = size
    ; r15  = cmp
    push r13
    push r14
    push r15
    mov r13, rdi
    mov r14, rcx
    mov r15, r8
    
    ; while(num > 0)
    jmp .aft
    .search:
        ; get the midpoint index into r10
        mov r10, rdx
        shr r10, 1
        ; convert into a pointer
        imul r10, r14
        add r10, rsi
        
        ; int _cmp = cmp(key, mid)
        push rsi
        push rdx
        push r10
        mov rdi, r13
        mov rsi, r10
        call r15
        pop r10
        pop rdx
        pop rsi
        
        ; if (_cmp == 0) return mid;
        cmp eax, 0
        move rax, r10
        je .ret
        
        ; if (_cmp < 0) do lower half
        js .lower
        ; if (_cmp > 0) do upper half
        ; v
        
        ; -- upper half -- ;
        .upper:
        
        ; get upper half starting point (not including the item we just tested)
        mov rsi, r10
        add rsi, r14
        
        ; get upper half length (total length - lower half length - 1)
        mov r10, rdx
        shr r10, 1
        sub rdx, r10
        dec rdx
        
        jmp .aft
        
        ; -- lower half -- ;
        .lower:
        
        ; get lower half length
        shr rdx, 1
        
    .aft:
        cmp rdx, 0
        ja .search
    
    ; otherwise we didn't find it - return null
    xor rax, rax
    .ret:
    ; restore call-safe registers
    pop r15
    pop r14
    pop r13
    ret

; ---------------------------------------------
    
; helper for __qsort - performs the swapping using buf as an intermediate
; should not be used outside of __qsort
__qsort_swap:
    ; r13/r14 have swap indicies
    ; r15 = size
    push r15
    mov r15, [rsp + 48] ; r15 = size -- 48 is 32 off + r15 push + ret address
    
    ; [buf] <- [left]
    mov rdi, [rsp + 32] ; buf -- 32 is 16 off + r15 push + ret address
    mov rax, r13
    mul r15
    add rax, [rsp + 56] ; add base -- 56 is 40 off + r15 push + ret address
    mov rsi, rax
    push rsi
    mov rdx, r15
    call memcpy
    
    ; [left] <- [right]
    pop rdi
    mov rax, r14
    mul r15
    add rax, [rsp + 56] ; add base -- 56 is 40 off + r15 push + ret address
    mov rsi, rax
    push rsi
    mov rdx, r15
    call memcpy
    
    ; [right] <- [buf]
    pop rdi
    mov rsi, [rsp + 32] ; buf -- 32 is 16 off + r15 push + ret address
    mov rdx, r15
    call memcpy
    
    mov rax, r13
    mov rbx, r14
    
    
    
    
    extern __read_arr
    ;call __read_arr
    
    
    
    
    pop r15
    ret
; helper for qsort - uses a buffers pointed to by __qsort_buf.
; void __qsort(void *base, size_t size, int (*cmp)(const void*, const void*), void *buf, size_t low, size_t high);
__qsort:
    ; if (low >= high) return;
    cmp r8, r9
    jge .ret
    
    ; reserve call-safe registers 13-15 for working pointers
    push r13
    push r14
    push r15
    
    ; [rsp + 40] = base (= rdi)
    ; [rsp + 32] = size (= rsi)
    ; [rsp + 24] = cmp  (= rdx)
    ; [rsp + 16] = buf  (= rcx)
    ; [rsp +  8] = low  (= r8)
    ; [rsp +  0] = high (= r9)
    push rdi
    push rsi
    push rdx
    push rcx
    push r8
    push r9
    
    ; -- select pivot - swap with high index -- ;
    
    ; r15 = pointer to pivot (index high)
    mov rax, r9
    mul rsi
    lea r15, [rax + rdi]
    
    ; select pivot index -- (low + high) / 2
    lea r13, [r8 + r9]
    shr r13, 1
    ; swap pivot index with high index
    mov r14, r9
    call __qsort_swap
    
    ; -- pivot is now at high index -- ;
    
    ; -- int i = low, j = high - 1;
    ; i = r13 = (left  index)
    ; j = r14 = (right index)
    mov r13, [rsp + 8]
    mov r14, [rsp + 0]
    dec r14
    
    ; perform partitioning
    ; while (true)
    .loop:
        ; while (i < high && cmp(i, high) <= 0) ++i;
        .left_loop:
            cmp r13, [rsp + 0]
            jge .left_end
            
            mov rax, r13
            mul qword ptr [rsp + 32]
            add rax, [rsp + 40]
            mov rdi, rax
            mov rsi, r15
            call [rsp + 24]
            
            cmp eax, 0
            jg .left_end
            
            inc r13
            jmp .left_loop
        .left_end:
        
        ; while (j >= low && cmp(high, j) <= 0) --j;
        .right_loop:
            cmp r14, [rsp + 8]
            jl .right_end
            
            mov rdi, r15
            mov rax, r14
            mul qword ptr [rsp + 32]
            add rax, [rsp + 40]
            mov rsi, rax
            call [rsp + 24]
            
            cmp eax, 0
            jg .right_end
            
            dec r14
            jmp .right_loop
        .right_end:
        
        ; if (i >= j) break;
        cmp r13, r14
        jge .loop_end
        
        ; otherwise, swap the items
        call __qsort_swap
        
        inc r13
        dec r14
        jmp .loop
    .loop_end:
    
    ; -- done partitioning -- ;
    
    ; now we need to put the pivot in its final position (index i)
    ; if (i != high) swap(i, high)
    mov r14, [rsp + 0]
    cmp r13, r14
    je .no_pivot_swap
    call __qsort_swap
    .no_pivot_swap:
    
    ; -- recursive step -- ;
    
    ; recurse into left sublist
    ; __qsort(base, size, cmp, buf, low, i - 1);
    mov rdi, [rsp + 40]
    mov rsi, [rsp + 32]
    mov rdx, [rsp + 24]
    mov rcx, [rsp + 16]
    mov r8,  [rsp +  8]
    lea r9,  [r13 -  1]
    call __qsort
    
    ; recurse into right sublist
    ; __qsort(base, size, cmp, buf, i + 1, high);
    mov rdi, [rsp + 40]
    mov rsi, [rsp + 32]
    mov rdx, [rsp + 24]
    mov rcx, [rsp + 16]
    lea r8,  [r13 +  1]
    mov r9,  [rsp +  0]
    call __qsort
    
    ; undo arg pushes
    add rsp, 48
    
    ; restore call-safe registers
    pop r15
    pop r14
    pop r13
    
    .ret: ret
; void qsort(void *base, size_t num, size_t size, int (*cmp)(const void*, const void*));
qsort:
    ; handle degenerate case num < 2
    cmp rsi, 2
    jl .ret
    
    ; create a temporary buffer for helper to use (sufficient to hold 1 element)
    push rdi ; base = [rsp + 32]
    push rsi ; num  = [rsp + 24]
    push rdx ; size = [rsp + 16]
    push rcx ; cmp  = [rsp +  8]
    mov rdi, rdx
    call malloc
    push rax ; buf  = [rsp +  0]
    
    ; call helper
    ; __qsort(base, size, cmp, buf, 0, num - 1);
    mov rdi, [rsp + 32]
    mov rsi, [rsp + 16]
    mov rdx, [rsp +  8]
    mov rcx, rax
    xor r8,  r8
    mov r9,  [rsp + 24]
    dec r9
    call __qsort
    
    ; free the temporary buffers
    pop rdi
    call free
    ; undo initial pushes
    add rsp, 32
    
    .ret: ret
