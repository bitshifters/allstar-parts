; ============================================================================
; Vector routines.
; ============================================================================

.equ LibVector_IncludeAddSub, 0

.if LibVector_IncludeAddSub
; Vector add.
; Parameters:
;  R0=ptr to vector C.
;  R1=ptr to vector A.
;  R2=ptr to vector B.
; Trashes: R3-R8
;
; Computes C = A + B
;
; A = [ a1 ]   B = [ b1 ]  C = [ a1 + b1 ]
;     [ a2 ]       [ b2 ]      [ a2 + b2 ]
;     [ a3 ]       [ b3 ]      [ a3 + b2 ]
;
vector_add:
    ldmia r1, {r3-r5}
    ldmia r2, {r6-r8}
    
    add r3, r3, r6
    add r4, r4, r7
    add r5, r5, r8

    stmia r0, {r3-r5}
    mov pc, lr


; Vector subtract.
; Parameters:
;  R0=ptr to vector C.
;  R1=ptr to vector A.
;  R2=ptr to vector B.
; Trashes: R3-R8
;
; Computes C = A + B
;
; A = [ a1 ]   B = [ b1 ]  C = [ a1 - b1 ]
;     [ a2 ]       [ b2 ]      [ a2 - b2 ]
;     [ a3 ]       [ b3 ]      [ a3 - b2 ]
;
vector_sub:
    ldmia r1, {r3-r5}
    ldmia r2, {r6-r8}
    
    sub r3, r3, r6
    sub r4, r4, r7
    sub r5, r5, r8

    stmia r0, {r3-r5}
    mov pc, lr
.endif

; Dot product.
; Parameters:
;  R1=ptr to vector A.
;  R2=ptr to vector B.
; Returns:
;  R0=dot product of A and B.
; Trashes: R3-R8
;
; Computes R0 = A . B where:
;
; A = [ a1 ]   B = [ b1 ]
;     [ a2 ]       [ b2 ]
;     [ a3 ]       [ b3 ]
;
; A.B = a1 * b1 + a2 * b2 + a3 * b3
; A.B = |A||B|.cos T
;
vector_dot_product:
    ldmia r1, {r3-r5}                   ; [s15.16]
vector_dot_product_load_B:
    ldmia r2, {r6-r8}                   ; [s15.16]

vector_dot_product_no_load:
    mov r3, r3, asr #MULTIPLICATION_SHIFT    ; [s15.8]
    mov r4, r4, asr #MULTIPLICATION_SHIFT    ; [s15.8]
    mov r5, r5, asr #MULTIPLICATION_SHIFT    ; [s15.8]
    mov r6, r6, asr #MULTIPLICATION_SHIFT    ; [s15.8]
    mov r7, r7, asr #MULTIPLICATION_SHIFT    ; [s15.8]
    mov r8, r8, asr #MULTIPLICATION_SHIFT    ; [s15.8]

    mul r0, r3, r6                      ; r0 = a1 * b1  [s30.16] potential overflow
    mla r0, r4, r7, r0                  ;   += a2 * b2  [s30.16] potential overflow
    mla r0, r5, r8, r0                  ;   += a3 * b3  [s30.16] potential overflow

    mov pc, lr


; Cross product.
; Parameters:
;  [R0, R1, R2] vector A.
;  [R3, R4, R5] vector B.
; Returns vector:
;  [R0, R1, R2]
; Trashes: R3-R7,R9
;
; Computes [R0 R1 R2] = A ^ B where:
;
; A = [ a1 ]   B = [ b1 ]
;     [ a2 ]       [ b2 ]
;     [ a3 ]       [ b3 ]
;
; A^B = [ b3 * a2 - a3 * b2 ]
;       [ a3 * b1 - b3 * a1 ]
;       [ a1 * b2 - a2 * b1 ]
;
vector_cross_product:
    mov r9, r5, asr #MULTIPLICATION_SHIFT    ; [s15.8] b3
    mov r7, r4, asr #MULTIPLICATION_SHIFT    ; [s15.8] b2
    mov r6, r3, asr #MULTIPLICATION_SHIFT    ; [s15.8] b1
    mov r5, r2, asr #MULTIPLICATION_SHIFT    ; [s15.8] a3
    mov r4, r1, asr #MULTIPLICATION_SHIFT    ; [s15.8] a2
    mov r3, r0, asr #MULTIPLICATION_SHIFT    ; [s15.8] a1

; A^B = [ b3 * a2 - a3 * b2 ]
;       [ a3 * b1 - b3 * a1 ]
;       [ a1 * b2 - a2 * b1 ]

    mul r0, r4, r9                      ; a2 * b3   [s15.16]
    mul r1, r5, r7                      ; a3 * b2   [s15.16]
    sub r0, r0, r1                      ; [ b3 * a2 - a3 * b2 ]

    mul r1, r5, r6                      ; a3 * b1   [s15.16]
    mul r2, r3, r9                      ; a1 * b3   [s15.16]
    sub r1, r1, r2                      ; [ a3 * b1 - a1 * b3 ]
    ; R9, R5 no longer used.

    mul r2, r3, r7                      ; a1 * b2   [s15.16]
    mul r5, r4, r6                      ; a2 * b1   [s15.16]
    sub r2, r2, r5                      ; [ a1 * b2 - a2 * b1 ]

    mov pc, lr

vector_sqrt_p:
    .long sqrt_table_no_adr

vector_recip_p:
    .long reciprocal_table_no_adr

; Vector [R0, R1, R2]
; Normalise vector so |V| = 1.0
; Trashes: R3-R4, R8-R10
vector_norm:
    str lr, [sp, #-4]!

    mov r4, r0, asr #10     ; [s8.6] x
    mov r3, r1, asr #10     ; [s8.6] y
    mov r2, r2, asr #10     ; [s8.6] z

    ; Compute A.A = (x*x + y*y + z*z)

    mov r1, r4
    mul r1, r4, r1          ; x*x               [16.12]

    mov r0, r3
    mla r0, r3, r0, r1      ; y*y + x*x         [16.12]

    mov r1, r2
    mla r1, r2, r1, r0      ; z*z + y*y + x*x   [16.12]

    ; Calcaulte L=sqrt(x*x + y*y + z*z)

    ldr r9, vector_sqrt_p           ; 0x10000 entries
    mov r1, r1, asr #14             ; remove fractional part and accuracy only every 4.
    ldr r1, [r9, r1, lsl #2]        ; sqrt(x*x + y*y + z*z)     [9.16]

    ; Calculate 1/L

    ldr r9, vector_recip_p          ; 
    ; Put divisor in table range.
    mov r1, r1, asr #16-LibDivide_Reciprocal_s    ; [9.6]    (b<<s)

    .if _DEBUG
    cmp r1,#0                   ; Test for division by zero
    adreq r0,divbyzero          ; and flag an error
    swieq OS_GenerateError      ; when necessary

    ; Limited precision.
    cmp r1, #1<<LibDivide_Reciprocal_t    ; Test for numerator too large
    adrge r0,divrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

    ; Lookup 1/L

    ldr r0, [r9, r1, lsl #2]    ; [0.16]    (1<<16+s)/(b<<s) = (1<<16)/b

    ; Scale vector components by 1/L

    mul r2, r0, r2              ; zn = z/L          [s8.22]
    mul r1, r3, r0              ; yn = y/L          [s8.22]
    mul r0, r4, r0              ; xn = x/L          [s8.22]

    mov r0, r0, asr #6          ; [s8.16]
    mov r1, r1, asr #6          ; [s8.16]
    mov r2, r2, asr #6          ; [s8.16]

    ldr pc, [sp], #4


; Vector interpolation.
; Parameters:
;  R0=ptr to vector C.
;  R1=ptr to vector A.
;  R2=ptr to vector B.
;  R9=lerp value [0.0-1.0]      ; [1.16]
; Trashes: R3-R9
;
; Computes C = A + (B - A) * v
;
; A = [ a1 ]   B = [ b1 ]  C = [ a1 + (b1 - a1) * v ]
;     [ a2 ]       [ b2 ]      [ a2 + (b2 - a2) * v ]
;     [ a3 ]       [ b3 ]      [ a3 + (b3 - a3) * v ]
;
vector_lerp:
    ldmia r1, {r3-r5}          ; vertex A
    ldmia r2, {r6-r8}          ; vertex B

    ; Calculate B-A
    sub r6, r6, r3              ; (b1 - a1)
    sub r7, r7, r4              ; (b2 - a2)
    sub r8, r8, r5              ; (b3 - a3)

    mov r6, r6, asr #MULTIPLICATION_SHIFT    ; [s15.8]
    mov r7, r7, asr #MULTIPLICATION_SHIFT    ; [s15.8]
    mov r8, r8, asr #MULTIPLICATION_SHIFT    ; [s15.8]
    mov r9, r9, asr #MULTIPLICATION_SHIFT    ; [1.8]

    mla r3, r6, r9, r3          ; a1 + (b1 - a1) * v
    mla r4, r7, r9, r4          ; a2 + (b2 - a2) * v
    mla r5, r8, r9, r5          ; a3 + (b3 - a3) * v

    stmia r0, {r3-r5}
    mov r9, r9, asl #MULTIPLICATION_SHIFT
    mov pc, lr


.if LibConfig_IncludeSqrt && 0           ; these functions rely on SQRT.
; Length of vector.
; Parameters:
;  R1=ptr to vector A.
; Returns:
;  R0=length of vector A.
; Trashes: R2-R9
;
; Compute length = sqrt(x*x + y*y + z*z)
vector_length:
    str lr, [sp, #-4]!
    mov r2, r1              ; B=A
    bl vector_dot_product   ; Compute A.A = (x*x + y*y + z*z)
    mov r1, r0
    bl sqrt                 ; trashes R9
    ldr pc, [sp], #4


; Squared length of vector.
; Parameters:
;  R1=ptr to vector A.
; Returns:
;  R0=length of vector A.
; Trashes: R2-R8
;
; Compute sq_length = x*x + y*y + z*z
vector_sq_length:
    str lr, [sp, #-4]!
    mov r2, r1              ; B=A
    bl vector_dot_product   ; Compute A.A = (x*x + y*y + z*z)
    ldr pc, [sp], #4


; 1/length of vector.
; Parameters:
;  R1=ptr to vector A.
; Returns:
;  R0=length of vector A.
; Trashes: R2-R9
;
; Compute 1/length = rsqrt(x*x + y*y + z*z)
vector_recip_length:
    str lr, [sp, #-4]!
    mov r2, r1              ; B=A
    bl vector_dot_product   ; Compute A.A = (x*x + y*y + z*z)
    mov r1, r0
    bl rsqrt                ; trashes R9
    ldr pc, [sp], #4
.endif

.if 0               ; Feels like too early optimisation.
; Dot product.
; Parameters:
;  R1=ptr to vector A.
;  R2=ptr to unit vector B.
; Returns:
;  R0=dot product of A and B.
; Trashes: R3-R8
;
; Computes R0 = A . B where B is a unit vector.
;
vector_dot_product_unit:
    ldmia r1, {r3-r5}                   ; [s15.16]
    ldmia r2, {r6-r8}                   ; [s1.16]

    mul r0, r3, r6                      ; r0 = a1 * b1  [s16.32] overflow!
    mla r0, r4, r7, r0                  ;   += a2 * b2  [s16.32] overflow!
    mla r0, r5, r8, r0                  ;   += a3 * b3  [s16.32] overflow!

    mov r0, r0, asr #PRECISION_BITS     ; [s15.24]
    mov pc, lr
.endif
