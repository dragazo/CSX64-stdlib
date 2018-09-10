; source http://www.cplusplus.com/reference/cmath/
; needs a lot of work - mostly simple but tedious
; needs asin/acos + ...

; -----------------------------

global sin, cos, tan
global atan, atan2

global pow, exp, sqrt
global log2, log, log1p, log10

global round, floor, ceil, trunc
global fmod, remainder

global fmin, fminf
global fmax, fmaxf

; -----------------------------

segment .text

; -----------------------------

; double sin(double x);
sin:
    movsd [qtemp], xmm0
    finit
    fld qword ptr [qtemp]
    fsin
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret
; double cos(double x);
cos:
    movsd [qtemp], xmm0
    finit
    fld qword ptr [qtemp]
    fcos
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret
; double tan(double x);
tan:
    movsd [qtemp], xmm0
    finit
    fld qword ptr [qtemp]
    fsincos
    fdivp st1, st0
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret

; double atan(double x);
atan:
    movsd [qtemp], xmm0
    finit
    fld qword ptr [qtemp]
    fld1
    fpatan
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret
; double atan2(double y, double x);
atan2:
    movsd [qtemp], xmm0
    movsd [qtemp2], xmm1
    finit
    fld qword ptr [qtemp]
    fld qword ptr [qtemp2]
    fpatan
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret

; -----------------------------

; double pow(double base, double exponent);
pow:
    ; we'll compute it as 2^log2(a^b) = 2^(b*log2(a))
    
    ; get args out of xmm and into the fpu
    movsd [qtemp], xmm1
    movsd [qtemp2], xmm0
    finit
    fld qword ptr [qtemp]  ; st1 holds exponent
    fld qword ptr [qtemp2] ; st0 holds base
    
    ; do the b*log2(a) part -- only thing on stack now is result
    fyl2x
    
    ; 2^(b*log2(a)) = 2^(i.f) = (2^i) * (2^0.f)
    
    ; compute i
    fld st0
    frndint
    
    ; compute 0.f
    fsub st1, st0
    
    ; compute 2^0.f
    fxch st1
    f2xm1
    fld1
    faddp st1, st0
    
    ; mutiply by 2^i
    fscale
    fstp st1
    
    ; store back in xmm0 for return
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret
; double exp(double x);
exp:
    movsd xmm1, xmm0
    movsd xmm0, [fe]
    call pow
    ret
; double sqrt(double x);
sqrt:
    sqrtsd xmm0, xmm0
    ret
    
; -----------------------------------

; double log2(double x);
log2:
    movsd [qtemp], xmm0
    finit
    fld1
    fld qword ptr [qtemp]
    fyl2x
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret
; double log(double x);
log:
    movsd [qtemp], xmm0
    finit
    fld qword ptr [rl2e]
    fld qword ptr [qtemp]
    fyl2x
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret
; double log1p(double x);
log1p:
    movsd [qtemp], xmm0
    finit
    fld qword ptr [rl2e]
    fld qword ptr [qtemp]
    fyl2xp1
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret
; double log10(double x);
log10:
    movsd [qtemp], xmm0
    finit
    fld qword ptr [rl2t]
    fld qword ptr [qtemp]
    fyl2x
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret

; -----------------------------

; double round(double x);
round:
    ; get x into the fpu
    movsd [qtemp], xmm0
    finit
    fld qword ptr [qtemp]
    
    ; set rounding mode
    fstcw [qtemp]
    fwait
    and word ptr [qtemp], ~0xc00
    fldcw [qtemp]
    
    ; return result
    frndint
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret
; double floor(double x);
floor:
    ; get x into the fpu
    movsd [qtemp], xmm0
    finit
    fld qword ptr [qtemp]
    
    ; set rounding mode
    fstcw [qtemp]
    fwait
    and word ptr [qtemp], ~0xc00
    or word ptr [qtemp], 0x100
    fldcw [qtemp]
    
    ; return result
    frndint
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret
; double ceil(double x);
ceil:
    ; get x into the fpu
    movsd [qtemp], xmm0
    finit
    fld qword ptr [qtemp]
    
    ; set rounding mode
    fstcw [qtemp]
    fwait
    and word ptr [qtemp], ~0xc00
    or word ptr [qtemp], 0x200
    fldcw [qtemp]
    
    ; return result
    frndint
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret
; double trunc(double x);
trunc:
    ; get x into the fpu
    movsd [qtemp], xmm0
    finit
    fld qword ptr [qtemp]
    
    ; set rounding mode
    fstcw [qtemp]
    fwait
    or word ptr [qtemp], 0xc00
    fldcw [qtemp]
    
    ; return result
    frndint
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret

; -----------------------------

; double fmod(double numer, double denom);
fmod:
    movsd [qtemp], xmm1
    movsd [qtemp2], xmm0
    finit
    fld qword ptr [qtemp]  ; st1 holds denom
    fld qword ptr [qtemp2] ; st0 holds numer
    
    ; compute remainder
    fprem
    fstp st1
    
    ; return result
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret
; double remainder(double numer, double denom);
remainder:
    movsd [qtemp], xmm1
    movsd [qtemp2], xmm0
    finit
    fld qword ptr [qtemp]  ; st1 holds denom
    fld qword ptr [qtemp2] ; st0 holds numer
    
    ; compute remainder
    fprem1
    fstp st1
    
    ; return result
    fstp qword ptr [qtemp]
    fwait
    movsd xmm0, [qtemp]
    ret

; -----------------------------

; double fmin(double x, double y);
fmin:
    minsd xmm0, xmm1
    ret
; float fminf(float x, float y);
fminf:
    minss xmm0, xmm1
    ret

; double fmax(double x, double y);
fmax:
    maxsd xmm0, xmm1
    ret
; float fmaxf(float x, float y);
fmaxf:
    maxss xmm0, xmm1
    ret

; -----------------------------

segment .rodata

align 8
fe:   dq 2.7182818284590452353602874713527 ; e
rl2e: dq 0.6931471805599453094172321214582 ; 1 / log2(2)
rl2t: dq 0.3010299956639811952137388947245 ; 1 / log2(10)

segment .bss

align 8
qtemp:  resq 1 ; 64-bit temporary
qtemp2: resq 1 ; extra 64-bit temporary (e.g. used by binary math functions)
