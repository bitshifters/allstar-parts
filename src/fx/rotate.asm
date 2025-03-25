; ============================================================================
; Rotate and scale
; ============================================================================

.equ Rotate_UnrolledCodeLength, 0x4a0              ; 0x4a0 to inline.
.equ Rotate_Columns,            160
.equ Rotate_Rows,               128

rotate_angle:
    .long 0         ; {s8.16}

rotate_scale:
    .long 2<<16     ; {8.16}

rotate_dir:
    .long 1<<9

rotate_sinus_table_p:
    .long sinus_table_no_adr

rotate_texture_p:
    .long rotate_texture_no_adr

; ============================================================================

; dudy = sin(a) / scale; // horizontal step on image per vertical step on screen
; dvdy = cos(a) / scale; // vertical step on image per vertical step on screen
; dudx = dvdy;           // horizontal step on image per horizontal step on screen
; dvdx = -dudy;          // vertical step on image per horizontal step on screen

; ============================================================================

; R12=screen addr.
rotate_draw:
    str lr, [sp, #-4]!

    ldr r9, rotate_sinus_table_p

    ldr r0, rotate_angle
    mov r1, r0, asl #8                  ; {0.32}
    mov r1, r1, lsr #LibSine_TableShift   ; {14.0}
    ldr r1, [r9, r1, lsl #2]            ; sin(a)    {s1.16}
    mov r1, r1, asr #8                  ; {s1.8}

    add r0, r0, #64<<16                 ; cos
    mov r2, r0, asl #8                  ; {0.32}
    mov r2, r2, lsr #LibSine_TableShift   ; {14.0}
    ldr r2, [r9, r2, lsl #2]            ; cos(a)    {s1.16}
    mov r2, r2, asr #8                  ; {s1.8}

    ldr r0, rotate_scale                ; {8.16}
    mov r0, r0, asr #8                  ; {8.8}

    mul r1, r0, r1                      ; dudy {s15.16} sin(a)*scale
    mul r2, r0, r2                      ; dvdy {s15.16} cos(a)*scale

    ldr r11, rotate_texture_p           ; texture_p

    ; Centre rotation.
    ; Rotate vector to TL corner by -a.
    ; u = x*cos(-a) - y*sin(-a) = x*cos(a) + y*sin(a)
    ; v = x*sin(-a) + y*cos(-a) = -x*sin(a) + y*cos(a)
    mov r3, #-80                        ; TL x
    mov r4, #-64                        ; TL y

    mul r5, r2, r3                      ; x*cos(-a)
    mla r5, r1, r4, r5                  ; -y*sin(-a)

    mvn r3, r3                          ; -TL y
    mul r6, r1, r3                      ; -x*sin(-a)
    mla r6, r2, r4, r6                  ; +y*cos(-a)

    ; Reduce to 16-bit values for u,v,du,dv etc.
    mov r1, r1, asl #9
    mov r2, r2, asl #9
    mov r5, r5, asl #9
    mov r6, r6, asl #9

.if 1                                   ; the fast way.
    mov r10, #Rotate_Rows               ; rows
    stmfd sp!, {r1,r2,r5,r6,r10,r12}

    mov r10, r1                         ; du
    mov r11, r2                         ; dv
    mov r0, #0                          ; U
    mov r1, #0                          ; V

    bl rotate_update_line_code

    ; TODO: The above fn creates all the code from scratch.
    ;       We only need to update the offsets each frame.

    ; Pop all the regs to begin.
    ldmfd sp!, {r1,r2,r5,r6,r10,r12}

    mov r1, r1, lsr #16
    mov r1, r1, lsl #16
    orr r1, r1, r2, lsr #16             ; du:dv

    mov r5, r5, lsr #16
    mov r5, r5, lsl #16
    orr r5, r5, r6, lsr #16             ; U:V

    ; R12 = screen addr = dest pointer

    ; Loop over 128 rows.
rotate_line_loop:
    ; Calculate start U,V (r5, r6 above)

    ; Update texture base ptr for U and V for row.

    ldr r8, rotate_texture_p            ; texture_p
    add r8, r8, r5, lsr #25             ; + u

    mov r6, r5, lsl #16                 ; unpack V
    mov r4, r6, lsr #25                 ; retrieve top 7-bits of v
    add r8, r8, r4, lsl #7              ; + v * tex_width

    ; Update u,v for next line.

    ; This adds du:dv to U:V in packed format.
    add r5, r5, r1                      ; u+=dudy

    ; Unpack dv inline.
    ; add r6, r6, r1, lsl #16           ; v+=dvdy
    ; Pack U:V.
    ; orr r5, r5, r6, lsr #16

    stmfd sp!, {r1,r5,r10}

    ; Derive R8-11 for 4096 byte offsets.

    add r9, r8, #4096
    add r10, r9, #4096
    add r11, r10, #4096                 ; additional regs

    ; Call plot line.
    .if Rotate_UnrolledCodeLength==0
    adr lr, .2
    str lr, [sp, #-4]!
    bl rotate_unrolled_line_code
    .2:
    .else
    rotate_unrolled_line_code:
    .skip Rotate_UnrolledCodeLength
    .endif

    ldmfd sp!, {r1,r5,r10}

    subs r10, r10, #1
    bne rotate_line_loop
.else                                   ; the slow way.
    ; Per row.
    mov r10, #Rotate_Rows               ; rows
.1:
    mov r7, r5                          ; working u
    mov r8, r6                          ; working v

    mov r9, #Rotate_Columns             ; cols
.2:
    ; Load texture

    ; v--- This can be computed as a register select for texture load.
    mov r4, r8, lsr #30                 ; INT(v) 7 bits total select top 2 bits
    add r14, r11, r4, lsl #12           ; Select 4096 byte chunk from top 2 bits

    ; v--- This can be computed as a 12-bit immediate offset.
    mov r4, r8, lsr #25                 ; INT(v) 7 bits total
    and r4, r4, #31                     ; Select bottom 5 bits.
    mov r4, r4, lsl #7                  ; * tex_width
    add r4, r4, r7, lsr #25             ; + INT(u) for 12 bits total.

    ; v--- This becomes lrdb rX, [rSelect, #imm offset]
    ldrb r0, [r14, r4]                  ; texel

    ; Update u,v
    add r7, r7, r2                      ; u+=dudx
    sub r8, r8, r1                      ; v+=dvdx 

    ; Plot 2x2 pixels
    strb r0, [r12, #Screen_Stride]
    strb r0, [r12], #1

    subs r9, r9, #1
    bne .2

    ; Move screen ptr.
    add r12, r12, #Screen_Stride

    ; Update u,v
    add r5, r5, r1                      ; u+=dudy
    add r6, r6, r2                      ; v+=dvdy

    subs r10, r10, #1
    bne .1
.endif
    ldr pc, [sp], #4

; ============================================================================

rotate_tick:
    ; TODO: Move these to sequence script as appropriate.
    ldr r0, rotate_angle
    add r0, r0, #1<<16
    str r0, rotate_angle

    ldr r0, rotate_scale
    ldr r1, rotate_dir
    add r0, r0, r1

    cmp r0, #4<<16          ; max scale.
    movgt r0, #4<<16
    mvngt r1, r1

    cmp r0, #1<<15          ; max angle.
    movlt r0, #1<<15
    mvnlt r1, r1
    
    str r0, rotate_scale
    str r1, rotate_dir
    mov pc, lr

; ============================================================================

; Called once to generate the unrolled code.
rotate_init:
    str lr, [sp, #-4]!

    adr r12, rotate_unrolled_line_code          ; dest

    mov r6, #Rotate_Columns                     ; columns to plot
.3:
    mov r9, #0                      ; dest register

.2:
    adr r8, rotate_line_code_snippet

    ; Copy code snippet updating destination registers.

    ldr r7, [r8], #4                ; ldrb rX, [rY, #Z]
    orr r7, r7, r9, lsl #12         ; dest reg (CONST)
    str r7, [r12], #4               ; write out instruction 0

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    ; Dest reg fixed (R14)
    str r7, [r12], #4               ; write out instruction 1

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #8
    orr r7, r7, r9, lsl #12         ; dest reg (CONST)
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 2

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    ; Dest reg fixed (R14)
    str r7, [r12], #4               ; write out instruction 3

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #8
    orr r7, r7, r9, lsl #12         ; dest reg (CONST)
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 4

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    ; Dest reg fixed (R14)
    str r7, [r12], #4               ; write out instruction 5

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #8
    orr r7, r7, r9, lsl #12         ; dest reg (CONST)
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 6

    ; Four pixels per word.

    ; Do this 8 times for R0-7
    add r9, r9, #1
    cmp r9, #8
    bne .2

    ; Write out plot snippet.
    ldmia r8!, {r2-r4}
    stmia r12!, {r2-r4}

    subs r6, r6, #32                ; 8 words at a time = 32 chunky pixels.
    bne .3

    ; Write out increment screen ptr to skip a line.
    ldr r0, [r8], #4
    str r0, [r12], #4

    .if Rotate_UnrolledCodeLength==0
    ; Write out rts.
    ldr r0, [r8], #4
    str r0, [r12], #4
    .endif

    ldr pc, [sp], #4

; ============================================================================

; Called once per frame to update the immediates in the unrolled code.
; R0=U0
; R1=V0
; R10=du
; R11=dv
rotate_update_line_code:
    adr r12, rotate_unrolled_line_code          ; dest

    mov r6, #Rotate_Columns                    ; columns to plot
.3:
    mov r9, #0                      ; dest register

.2:
    adr r8, rotate_line_code_snippet

    ; Calculate 12-bit offset.

    ldr r7, [r8], #4                ; ldrb rX, [rY, #Z]
    orr r7, r7, r9, lsl #12         ; dest reg (CONST)
    mov r2, r1, lsr #25             ; INT(v) 7 bits total
    and r2, r2, #31                 ; Select bottom 5 bits of V.
    mov r2, r2, lsl #7              ; * tex_width
    add r2, r2, r0, lsr #25         ; + INT(u) for 12 bits total.
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r1, lsr #30             ; INT(v) 7 bits total select top 2 bits
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 0

    ; Update u,v.
    add r0, r0, r11                 ; u+=dudx
    sub r1, r1, r10                 ; v+=dvdx 

    ldr r7, [r8], #8                ; ldrb r14, [rY, #Z]
    ; Dest reg fixed (R14)
    mov r2, r1, lsr #25             ; INT(v) 7 bits total
    and r2, r2, #31                 ; Select bottom 5 bits of V.
    mov r2, r2, lsl #7              ; * tex_width
    add r2, r2, r0, lsr #25         ; + INT(u) for 12 bits total.
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r1, lsr #30             ; INT(v) 7 bits total select top 2 bits
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #8               ; write out instruction 1

    ; skip instruction 2

    ; Update u,v.
    add r0, r0, r11                 ; u+=dudx
    sub r1, r1, r10                 ; v+=dvdx 
    
    ldr r7, [r8], #8                ; ldrb r14, [rY, #Z]
    ; Dest reg fixed (R14)
    mov r2, r1, lsr #25             ; INT(v) 7 bits total
    and r2, r2, #31                 ; Select bottom 5 bits of V.
    mov r2, r2, lsl #7              ; * tex_width
    add r2, r2, r0, lsr #25         ; + INT(u) for 12 bits total.
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r1, lsr #30             ; INT(v) 7 bits total select top 2 bits
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #8               ; write out instruction 3

    ; skip instruction 4

    ; Update u,v.
    add r0, r0, r11                 ; u+=dudx
    sub r1, r1, r10                 ; v+=dvdx 
    
    ldr r7, [r8], #8                ; ldrb r14, [rY, #Z]
    ; Dest reg fixed (R14)
    mov r2, r1, lsr #25             ; INT(v) 7 bits total
    and r2, r2, #31                 ; Select bottom 5 bits of V.
    mov r2, r2, lsl #7              ; * tex_width
    add r2, r2, r0, lsr #25         ; + INT(u) for 12 bits total.
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r1, lsr #30             ; INT(v) 7 bits total select top 2 bits
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #8               ; write out instruction 5

    ; skip instruction 6

    ; Update u,v.
    add r0, r0, r11                 ; u+=dudx
    sub r1, r1, r10                 ; v+=dvdx 

    ; Four pixels per word.

    ; Do this 8 times for R0-7
    add r9, r9, #1
    cmp r9, #8
    bne .2

    ; Skip plot snippet (3 words).
    add r12, r12, #12

    subs r6, r6, #32                ; 8 words at a time = 32 chunky pixels.
    bne .3

    ; Skip post-amble.

    mov pc, lr

; ============================================================================
; NB. Not called directly, copied and patched at runtime.
; ============================================================================

rotate_line_code_snippet:
    ldrb r0, [r0, #0]               ; 4c    <= mod imm offset, base reg, dest reg
    ldrb r14, [r0, #0]              ; 4c    <= mod imm offset, base reg
    orr r0, r0, r14, lsl #8         ; 1c    <= mod dest reg
    ldrb r14, [r0, #0]              ; 4c    <= mod imm offset, base reg
    orr r0, r0, r14, lsl #16        ; 1c    <= mod dest reg
    ldrb r14, [r0, #0]              ; 4c    <= mod imm offset, base reg
    orr r0, r0, r14, lsl #24        ; 1c    <= mod dest reg

    ; Plot the pixels.
    add r14, r12, #Screen_Stride    ; 1c
    stmia r12!, {r0-r7}             ; 3+8*1.25=13c
    stmia r14!, {r0-r7}             ; 3+8*1.25=13c

    ; 19c per word * 8 + 27 = 179c for 8 words * 5 = 895c per row * 128 = 114560c per screen

    ; Skip a line.
    add r12, r12, #Screen_Stride    ; 1c

    ; Return.
    ldr pc, [sp], #4

; ============================================================================
