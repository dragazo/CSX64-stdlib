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
    
; helper for __qsort - performs the swapping using __qsort_buf as an intermediate
; should not be used outside of __qsort
__qsort_swap:
    ; r13/r14 have swap indicies
    ; r15 = size
    push r15
    mov r15, [rsp + 24] ; r15 = size -- 24 is 8 off + r15 push + ret address
    
    ; [buf] <- [left]
    mov rdi, [__qsort_buf]
    mov rax, r13
    mul r15
    add rax, [rsp + 40] ; add base -- 40 is 24 off + r15 push + ret address
    mov rsi, rax
    push rsi
    mov rdx, r15
    call memcpy
    
    ; [left] <- [right]
    pop rdi
    mov rax, r14
    mul r15
    add rax, [rsp + 40] ; add base -- 40 is 24 off + r15 push + ret address
    mov rsi, rax
    push rsi
    mov rdx, r15
    call memcpy
    
    ; [right] <- [buf]
    pop rdi
    mov rsi, [__qsort_buf]
    mov rdx, r15
    call memcpy
    
    pop r15
    ret
; helper for qsort - uses a buffers pointed to by __qsort_buf.
; void __qsort(void *base, size_t num, size_t size, int (*cmp)(const void*, const void*));
__qsort:
    ; if (num < 2) already sorted
    cmp rsi, 2
    jb .ret
    
    ; reserve call-safe registers 13-15 for working pointers
    push r13
    push r14
    push r15
    
    ; [rsp + 24] = base (= rdi)
    ; [rsp + 16] = num  (= rsi)
    ; [rsp +  8] = size (= rdx)
    ; [rsp +  0] = cmp  (= rcx)
    push rdi
    push rsi
    push rdx
    push rcx
    
    ; for now, refer to args with registers
    ; r15 = pointer to pivot (index 0)
    mov r15, rdi
    ; select pivot index
    mov r13, rsi
    shr r13, 1
    ; swap pivot index with index 0 (pivot now in index 0)
    xor r14, r14
    call __qsort_swap
    
    ; from here on, args are referred to by address
    
    ; r13 = 0       = (left index)
    ; r14 = num - 1 = (right index)
    xor r13, r13
    mov r14, [rsp + 16]
    dec r14
    
    ; perform partitioning (<=pivot) | (>pivot)
    ; for (; ; ++left, --right)
    .loop:
        ; get a large item on the left
        ; while(left < num && cmp(base[left], base[0]) <= 0) ++left;
        jmp .left_aft
        .left_loop: inc r13
        .left_aft:
            cmp r13, [rsp + 16]
            jg .left_end
            
            mov rax, r13
            mul qword ptr [rsp + 8]
            add rax, [rsp + 24]
            mov rdi, rax
            mov rsi, r15
            call [rsp]
            
            cmp eax, 0
            jg .left_end
            
            jmp .left_loop
        .left_end:
        
        ; get a small item on the right
        ; while(right >= 0 && cmp(base[0], base[right]) < 0) --right;
        jmp .right_aft
        .right_loop: dec r14
        .right_aft:
            cmp r13, 0
            jl .right_end
            
            mov rdi, r15
            mov rax, r14
            mul qword ptr [rsp + 8]
            add rax, [rsp + 24]
            mov rsi, rax
            call [rsp]
            
            cmp eax, 0
            jge .right_end
            
            jmp .right_loop
        .right_end:
        
        ; if (left >= right) break;
        cmp r13, r14
        jae .loop_end
        
        ; otherwise, swap the items
        call __qsort_swap
        
        inc r13
        dec r14
        jmp .loop
    .loop_end:
    
    ; r13 = partition index (left index)
    ; r14 = size
    mov r14, [rsp + 8]
    ; r15 = base
    
    ; recurse into left sublist    
    mov rdi, r15   ; left starts at same position
    mov rsi, r13   ; left num = partition index
    mov rdx, r14   ; same size items
    mov rcx, [rsp] ; same comparator
    call __qsort
    
    ; recurse into right sublist
    mov rax, r13        ; right starts at partition index
    mul r14
    lea rdi, [rax + r15]
    mov rsi, [rsp + 16] ; right num = num - left num
    sub rsi, r13
    mov rdx, r14        ; same size items
    mov rcx, [rsp]      ; same comparator
    call __qsort
    
    ; undo arg pushes
    add rsp, 32
    
    ; restore call-safe registers
    pop r15
    pop r14
    pop r13
    
    .ret: ret
; void qsort(void *base, size_t num, size_t size, int (*cmp)(const void*, const void*));
qsort:
    ; create temporary buffers for helper to use (each sufficient to hold 1 element)
    push rdi
    push rsi
    push rdx
    push rcx
    
    mov rdi, rdx
    call malloc
    mov [__qsort_buf], rax
    
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    
    ; call helper
    call __qsort
    
    ; free the temporary buffers
    mov rdi, [__qsort_buf]
    call free
    
    ret
    
; --------------------------------------

segment .bss

align 8
__qsort_buf: resq 1 ; pointer to buffer used by __qsort helper
