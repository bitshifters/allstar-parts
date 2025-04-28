; ============================================================================
; Memory functions.
; ============================================================================

; R0=src
; R1=dst
; R2=src end
mem_copy_words_to_end_ptr:
    sub r2, r2, r0      ; bytes
    mov r2, r2, lsr #2  ; words

; R0=src
; R1=dst
; R2=num words.
mem_copy_words:
    .if _DEBUG
    ; TODO: Check for call with <=0
    .endif
.1:
    ldr r3, [r0], #4
    str r3, [r1], #4
    subs r2, r2, #1
    bne .1
    mov pc, lr

; R0=dst
; R1=num words.
mem_clr_words:
    mov r2, #0

; R0=dst
; R1=num repts
; R2=word
mem_rept_word:
    .if _DEBUG
    ; TODO: Check for call with <=0
    .endif
.1:
    str r2, [r0], #4
    subs r1, r1, #1
    bne .1
    mov pc, lr

; ============================================================================

; R0=src
; R1=dst
mem_copy_16K_fast:
    .rept 409                       ; 409*40=16360 bytes
    ldmia r0!, {r3-r12}             ; 40 bytes
    stmia r1!, {r3-r12}
    .endr                           ; 25c*40=1000c
    ldmia r0!, {r3-r8}              ; 24 bytes
    stmia r1!, {r3-r8}
    mov pc, lr

; ============================================================================
