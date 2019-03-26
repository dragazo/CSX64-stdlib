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
    movsd [rsp - 8], xmm0
    finit
    fld qword ptr [rsp - 8]
    fsin
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
    ret
; double cos(double x);
cos:
    movsd [rsp - 8], xmm0
    finit
    fld qword ptr [rsp - 8]
    fcos
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
    ret
; double tan(double x);
tan:
    movsd [rsp - 8], xmm0
    finit
    fld qword ptr [rsp - 8]
    fsincos
    fdivp st1, st0
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
    ret

; double atan(double x);
atan:
    movsd [rsp - 8], xmm0
    finit
    fld qword ptr [rsp - 8]
    fld1
    fpatan
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
    ret
; double atan2(double y, double x);
atan2:
    movsd [rsp - 8], xmm0
    movsd [rsp - 16], xmm1
    finit
    fld qword ptr [rsp - 8]
    fld qword ptr [rsp - 16]
    fpatan
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
    ret

; -----------------------------

; double pow(double base, double exponent);
pow:
    ; we'll compute it as 2^log2(a^b) = 2^(b*log2(a))
    
    ; get args out of xmm and into the fpu
    movsd [rsp - 8], xmm1
    movsd [rsp - 16], xmm0
    finit
    fld qword ptr [rsp - 8]  ; st1 holds exponent
    fld qword ptr [rsp - 16] ; st0 holds base
    
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
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
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
    movsd [rsp - 8], xmm0
    finit
    fld1
    fld qword ptr [rsp - 8]
    fyl2x
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
    ret
; double log(double x);
log:
    movsd [rsp - 8], xmm0
    finit
    fld qword ptr [rl2e]
    fld qword ptr [rsp - 8]
    fyl2x
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
    ret
; double log1p(double x);
log1p:
    movsd [rsp - 8], xmm0
    finit
    fld qword ptr [rl2e]
    fld qword ptr [rsp - 8]
    fyl2xp1
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
    ret
; double log10(double x);
log10:
    movsd [rsp - 8], xmm0
    finit
    fld qword ptr [rl2t]
    fld qword ptr [rsp - 8]
    fyl2x
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
    ret

; -----------------------------

; double round(double x);
round:
    ; get x into the fpu
    movsd [rsp - 8], xmm0
    finit
    fld qword ptr [rsp - 8]
    
    ; set rounding mode
    fstcw [rsp - 8]
    fwait
    and word ptr [rsp - 8], ~0xc00
    fldcw [rsp - 8]
    
    ; return result
    frndint
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
    ret
; double floor(double x);
floor:
    ; get x into the fpu
    movsd [rsp - 8], xmm0
    finit
    fld qword ptr [rsp - 8]
    
    ; set rounding mode
    fstcw [rsp - 8]
    fwait
    and word ptr [rsp - 8], ~0xc00
    or word ptr [rsp - 8], 0x100
    fldcw [rsp - 8]
    
    ; return result
    frndint
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
    ret
; double ceil(double x);
ceil:
    ; get x into the fpu
    movsd [rsp - 8], xmm0
    finit
    fld qword ptr [rsp - 8]
    
    ; set rounding mode
    fstcw [rsp - 8]
    fwait
    and word ptr [rsp - 8], ~0xc00
    or word ptr [rsp - 8], 0x200
    fldcw [rsp - 8]
    
    ; return result
    frndint
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
    ret
; double trunc(double x);
trunc:
    ; get x into the fpu
    movsd [rsp - 8], xmm0
    finit
    fld qword ptr [rsp - 8]
    
    ; set rounding mode
    fstcw [rsp - 8]
    fwait
    or word ptr [rsp - 8], 0xc00
    fldcw [rsp - 8]
    
    ; return result
    frndint
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
    ret

; -----------------------------

; double fmod(double numer, double denom);
fmod:
    movsd [rsp - 8], xmm1
    movsd [rsp - 16], xmm0
    finit
    fld qword ptr [rsp - 8]  ; st1 holds denom
    fld qword ptr [rsp - 16] ; st0 holds numer
    
    ; compute remainder
    fprem
    fstp st1
    
    ; return result
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
    ret
; double remainder(double numer, double denom);
remainder:
    movsd [rsp - 8], xmm1
    movsd [rsp - 16], xmm0
    finit
    fld qword ptr [rsp - 8]  ; st1 holds denom
    fld qword ptr [rsp - 16] ; st0 holds numer
    
    ; compute remainder
    fprem1
    fstp st1
    
    ; return result
    fstp qword ptr [rsp - 8]
    fwait
    movsd xmm0, [rsp - 8]
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
rl2e: dq 0.6931471805599453094172321214582 ; 1 / log2(e)
rl2t: dq 0.3010299956639811952137388947245 ; 1 / log2(10)
