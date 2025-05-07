; ============================================================================
;
; UV table map effects.
;
; Standard format: each word is 2 pixels of packed U,V = v1v0u1u0
;   where U, V are [0,127] << 1 and screen_colour = texture[v * 128 + u]
;   if UV_Table_BlankPixels is defined and bottom bit of U or V is set
;   then the screen_colour = 0
; Requires texture to be doubled up 0xLL.
;
; Extended foramt: follows with another word = b1a1b0a0
;   where screen_colour = (texture_colour >> a) + b
; Requires texture to be sparse 0x0L.
;
; ============================================================================

.equ UV_Table_CodeSize,             335876  ; 151556
.equ UV_Table_Columns,              160
.equ UV_Table_Rows,                 128     ; or 120?

.equ UV_Texture_MaxSize,            128*128

.equ UV_Table_TexDim_128_128,       0
.equ UV_Table_TexDim_64_256,        1
.equ UV_Table_TexDim_256_64,        2
.equ UV_Table_TexDim_128_64,        3

.equ UV_Table_BlankPixels,     1       ; TODO: Set const colour not just black.

uv_table_offset_u:
    .byte 0

uv_table_offset_v:
    .byte 0

uv_table_offset_du:
    .byte 1

uv_table_offset_dv:
    .byte 1
.p2align 2

uv_table_texture_p:
    .long uv_texture_data_no_adr

uv_table_map_p:
    .long 0

uv_table_code_p:
    .long uv_table_unrolled_code_no_adr

uv_table_texture_data_p:
    .long uv_texture_data_no_adr

; ============================================================================

; R12=screen addr
uv_table_draw:
	str lr, [sp, #-4]!

    ldrb r9, uv_table_offset_u
    ldrb r1, uv_table_offset_v

    ldr r8, uv_table_texture_p ; base of the texture

    add r8, r8, r9              ; add u offset
    add r8, r8, r1, lsl #7      ; add v offset (128 bytes per row)

    add r9, r8, #4096           ; only 4096 bytes are addressable at a time
    add r10, r9, #4096          ; using offset load, so use registers
    add r11, r10, #4096         ; 4*4096 = 16384 = 128*128

    ldr pc, uv_table_code_p    ; pops return from stack.

; ============================================================================

uv_table_tick:
    ldrb r9, uv_table_offset_u
    ldrb r8, uv_table_offset_du
    add r9, r9, r8
    and r9, r9, #0x7f           ; u [0, 127]
    strb r9, uv_table_offset_u

    ldrb r1, uv_table_offset_v
    ldrb r2, uv_table_offset_dv
    add r1, r1, r2
    and r1, r1, #0x7f           ; v [0, 127]
    strb r1, uv_table_offset_v
    mov pc, lr

; ============================================================================

; Copies 16Kb of texture data to buffer twice (so texture lookup can wrap in V).
; R0=src ptr.
uv_texture_set_data:
    ldr r1, uv_table_texture_data_p
    str r1, uv_table_texture_p
    stmfd sp!, {r0,lr}
    bl mem_copy_16K_fast
    ldmfd sp!, {r0,lr}
    b mem_copy_16K_fast

; ============================================================================

; Params:
;   R0=0000VvUu
; Returns:
;   R2=byte offset   [0, 4096]
;   R3=base register [8, 11]
; Trashes: R4
uv_table_calc_offset:
    and r2, r0, #0x007f             ; u0<<0  [0, 127]   7 bits
    and r3, r0, #0x7f00             ; v0<<8  [0, 127]   7 bits
    mov r4, r3, lsl #12+7           ; bottom 5 bits of v0
    orr r2, r2, r4, lsr #20         ; v0 | u0           12 bits
    mov r3, r3, lsr #6+7            ; top 2 bits of v0
    add r3, r3, #8                  ; [8, 11]
    mov pc, lr


uv_table_tex_dim_128_128:           ; 128x128
    and r2, r0, #0x007f             ; u0<<0  [0, 127]   7 bits
    and r3, r0, #0x7f00             ; v0<<8  [0, 127]   7 bits
    mov r4, r3, lsl #12+7           ; bottom 5 bits of v0
    orr r2, r2, r4, lsr #20         ; v0 | u0           12 bits
    mov r3, r3, lsr #6+7            ; top 2 bits of v0

uv_table_tex_dim_64_256:            ; 64x256
    and r2, r0, #0x003f             ; u0     [0, 63]    6 bits
    and r3, r0, #0xff00             ; v0<<8  [0, 255]   8 bits
    mov r4, r3, lsl #12+6           ; bottom 6 bits of v0
    orr r2, r2, r4, lsr #20         ; v0 | u0           12 bits
    mov r3, r3, lsr #6+8            ; top 2 bits of v0

uv_table_tex_dim_256_64:            ; 256x64
    and r2, r0, #0x00ff             ; u0<<0  [0, 255]  8 bits
    and r3, r0, #0x3f00             ; v0<<8  [0, 63]   6 bits
    mov r4, r3, lsl #12+8           ; bottom 4 bits of v0
    orr r2, r2, r4, lsr #20         ; v0 | u0          12 bits
    mov r3, r3, lsr #6+6            ; top 2 bits of v0

uv_table_tex_dim_128_64:            ; 128x64
    and r2, r0, #0x007f             ; u0<<0  [0, 127]  7 bits
    and r3, r0, #0x3f00             ; v0<<8  [0, 63]   6 bits
    mov r4, r3, lsl #12+7           ; bottom 5 bits of v0
    orr r2, r2, r4, lsr #20         ; v0 | u0          12 bits
    mov r3, r3, lsr #6+7            ; top 1 bits of v0


; Generate plot code from UV data alone.
; R11 = pointer to UV map data
; Each word is 2 pixels of packed U,V  = v1u1v0u0
; u,v [0, 255] => we're going to use half resolution.
; R12 = pointer to where unrolled code is written
; TODO: Feed in row/column count as params?
uv_table_init:

    mov r0, #UV_Table_TexDim_128_128
    ldr r12, uv_table_code_p       ; dest
    ldr r11, uv_table_map_p        ; uv data
    mov r10, #0
    b uv_table_gen_shader_code

; Generate plot code from UV data plus shader data.
; R11 = pointer to UV map data
; Each word is 2 pixels of packed U,V  = v1u1v0u0
; u,v [0, 255] => we're going to use half resolution.
; R12 = pointer to where unrolled code is written
; TODO: Feed in row/column count as params?
uv_table_init_shader:

    ldr r12, uv_table_code_p       ; dest
    ldr r11, uv_table_map_p        ; uv data
    add r10, r11, #UV_Table_Columns*UV_Table_Rows*2 ; shader data
    ; Fall through!

uv_table_gen_shader_code:
    str lr, [sp, #-4]!

    ; R0 = texture dimensions as enum
    ; Poke in code to calculate texture offset from dimensions.
    ; Super hackballs! :)
    adr r2, uv_table_calc_offset    ; dest
    adr r1, uv_table_tex_dim_128_128
    add r1, r1, r0, lsl #4          ; enum*5*4
    add r1, r1, r0, lsl #2          ; enum*5*4
    ldmia r1, {r3-r7}               ; copy 5 instrutions
    stmia r2, {r3-r7}

    ; R0=v1v0u1u0
    ; R1=v3v2u3u2
    ; R2=temp
    ; R3=temp
    ; R4=temp
    ; R5=b3a3b2a2b1a1b0a0
    ; R6=row counter | column counter<<16
    ; R7=opcode being assembled
    ; R8=code snippet ptr
    ; R9=dest register
    ; R10=extended data ptr
    ; R11=UV table ptr
    ; R12=code dest ptr
    ; R14=LR

    mov r6, #UV_Table_Rows          ; rows to plot
.1:

    ; TODO: Create a jump table of entry points for each line.

    orr r6, r6, #UV_Table_Columns<<16  ; columns to plot
.3:
    mov r9, #0                      ; dest register

.2:
    ; Load 4 pixels worth of (u,v)

    ldmia r11!, {r0-r1}             ; R0=v1u1v0u0 R1=v3u3v2u2

    ; And the shader data (if it exists)

    cmp r10, #0
    ldrne r5, [r10], #4             ; R5= 3 2 1 0
                                    ;    babababa

    ; TODO: Don't pay shift penalty if there's no shading!
    moveq r5, #0x04
    orreq r5, r5, r5, lsl #8
    orreq r5, r5, r5, lsl #16

    ; Copy one snippet for 4 pixels = assemble 1 word for writing

    adr r8, uv_table_code_snippet

    ; Write out texture load for pixel 0 in word.

    ; R0=0000v0u0
    bl uv_table_calc_offset

    ldr r7, [r8], #4                ; ldrb rX, [rY, #Z]
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r2                  ; offset [0, 4095]
    orr r7, r7, r3, lsl #16         ; base reg
    .20:
    str r7, [r12], #4               ; write out instruction 0

    ; Write out optional a/b operations for Rdest.
    ands r2, r5, #0x0000000f        ; a0
    beq .201                        ; <== NB always FALSE as a+=4 in the script.
    ldr r7, [r8, #13*4]             ; additional op shift (logical_colour >> a)
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9                  ; base reg
    orr r7, r7, r2, lsl #7          ; shift amount in bits 7-11
    str r7, [r12], #4               ; write out additional instruction 1a
    .201:

    ands r2, r5, #0x000000f0         ; b0 << 4
    beq .202
    ldr r7, [r8, #14*4]             ; additional op add (logical_colour >> a) + b
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    orr r7, r7, r2, lsr #4          ; b0
    str r7, [r12], #4               ; write out additional instruction 1a
    .202:

    ; Write out texture load for pixel 1 in word.

    mov r0, r0, lsr #16             ; R0=0000v1u1
    bl uv_table_calc_offset

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    orr r7, r7, r2                  ; offset [0, 4095]
    orr r7, r7, r3, lsl #16         ; base reg
    .21:
    str r7, [r12], #4               ; write out instruction 1

    ; Write out optional a/b operations for R14.
    ands r2, r5, #0x00000f00        ; a1 << 8
    beq .211                        ; <== NB always FALSE as a+=4 in the script.
    ldr r7, [r8, #14*4]             ; additional op shift (logical_colour >> a)
    orr r7, r7, r2, lsr #8-7        ; shift amount in bits 7-11
    str r7, [r12], #4               ; write out additional instruction 1a
    .211:

    ands r2, r5, #0x0000f000        ; b1 << 12
    beq .212
    ldr r7, [r8, #15*4]             ; additional op add (logical_colour >> a) + b
    orr r7, r7, r2, lsr #12         ; b1
    str r7, [r12], #4               ; write out additional instruction 1a
    .212:

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #8
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 2

    ; Write out texture load for pixel 2 in word.

    mov r0, r1                      ; R0=0000v2u2
    bl uv_table_calc_offset

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    orr r7, r7, r2                  ; offset [0, 4095]
    orr r7, r7, r3, lsl #16         ; base reg
    .22:
    str r7, [r12], #4               ; write out instruction 3

    ; Write out optional a/b operations for R14.
    ands r2, r5, #0x000f0000        ; a2 << 16
    beq .221                        ; <== NB always FALSE as a+=4 in the script.
    ldr r7, [r8, #12*4]             ; additional op shift (logical_colour >> a)
    orr r7, r7, r2, lsr #16-7       ; shift amount in bits 7-11
    str r7, [r12], #4               ; write out additional instruction 1a
    .221:

    ands r2, r5, #0x00f00000        ; b2 << 20
    beq .222
    ldr r7, [r8, #13*4]             ; additional op add (logical_colour >> a) + b
    orr r7, r7, r2, lsr #20         ; b2
    str r7, [r12], #4               ; write out additional instruction 1a
    .222:

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #16
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 4

    ; Write out texture load for pixel 3 in word.

    mov r0, r1, lsr #16             ; R0=0000v3u3  
    bl uv_table_calc_offset

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    orr r7, r7, r2                  ; offset [0, 4095]
    orr r7, r7, r3, lsl #16         ; base reg
    .23:
    str r7, [r12], #4               ; write out instruction 5

    ; Write out optional a/b operations for R14.
    ands r2, r5, #0x0f000000        ; a3 << 24
    beq .231                        ; <== NB always FALSE as a+=4 in the script.
    ldr r7, [r8, #10*4]             ; additional op shift (logical_colour >> a)
    orr r7, r7, r2, lsr #24-7       ; shift amount in bits 7-11
    str r7, [r12], #4               ; write out additional instruction 1a
    .231:

    ands r2, r5, #0xf0000000        ; b3 << 28
    beq .232
    ldr r7, [r8, #11*4]             ; additional op add (logical_colour >> a) + b
    orr r7, r7, r2, lsr #28         ; b3
    str r7, [r12], #4               ; write out additional instruction 1a
    .232:

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #24
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 6

    ; Write out full word ORR.
    ldr r7, [r8, #11*4]             ; orr r0, r0, r0, lsl #4
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    orr r7, r7, r9                  ; src reg
    str r7, [r12], #4               ; write out full word shift

    ; Do this 8 times for R0-7
    add r9, r9, #1
    cmp r9, #8
    bne .2
    ; Code size = 7 words x 8 times = 56 words
    ;           = 16 words x 8 times = 335876 bytes (!)

    ; Write out plot snippet.
    ldmia r8!, {r0-r2}
    stmia r12!, {r0-r2}
    ; Code size = 56 words + 3 words = 59 words

    sub r6, r6, #32<<16            ; 8 words at a time = 32 chunky pixels.
    cmp r6, #1<<16
    bgt .3
    ; Code size = 59 words * 5 times = 295 words

    ; Write out increment screen ptr to skip a line.
    ldr r0, [r8], #4
    str r0, [r12], #4
    ; Code size = 295 words + 1 word = 296 words per row

    subs r6, r6, #1               ; next row
    bne .1
    ; Code size = 296 words * 128 rows = 37888 words

    ; Write out rts.
    ldr r0, [r8], #4
    str r0, [r12], #4
    ; Code size = 37889 words = 151556 bytes = 148K + 4 bytes!

    ldr pc, [sp], #4

; ============================================================================
; NB. Not called directly, copied and patched at runtime.
; ============================================================================

uv_table_code_snippet:
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
    ; ~5.6c per chunky pixel

    ; Skip a line.
    add r12, r12, #Screen_Stride    ; 1c

    ; Return.
    ldr pc, [sp], #4

    .if UV_Table_BlankPixels
    ; Blank a pixel.
    mov r0, #0
    mov r14, #0
    .endif

    ; Texture byte is 0xLL where L=logical colour
    ; But could be 0x0L or 0xAB

    ; Optional operation:
    ; logical_colour = (logical_colour >> a) + b
    ; Assumes texture bytes are 0x0L.
    mov r0, r0, lsr #0              ; For Rdest.
    add r0, r0, #0

    mov r14, r14, lsr #0            ; For R14.
    add r14, r14, #0

    orr r0, r0, r0, lsl #4          ; <= do this once per word, not per byte
    ; 28c per word * 8 + 27 = 251 * 5 = 1255 * 128 = 160640c
    ; ~7.8c per chunky pixel (160x90 gives approx same count as vanilla version)

    .if 0   ; not used yet!
    and r0, r0, #0x0f               ; either texture select A
    mov r0, r0, lsr #4              ;     or texture select B
    orr r0, r0, r0, lsl #4          ; <= do this once per word, not per byte
    ; 25c per word * 8 + 27 = 227 * 5 = 1135 * 128 = 145280c
    ; ~7.1c per chunky pixel (160x100 gives approx same count as vanilla version)
    .endif

; ============================================================================
; ============================================================================





; ============================================================================
; Previous code path.
; ============================================================================

    .if 0
; R11 = pointer to UV map data
; Each word is 2 pixels of packed U,V  = v1v0u1u0
; u,v [0, 255] => we're going to use half resolution.
; R12 = pointer to where unrolled code is written
; TODO: Feed in row/column count as params?
; TODO: Combine code paths ideally?
uv_table_gen_code:
    str lr, [sp, #-4]!

    mov r10, #UV_Table_Rows        ; rows to plot
.1:

    mov r6, #UV_Table_Columns      ; columns to plot
.3:
    mov r9, #0                      ; dest register

.2:
    ; Load 4 pixels worth of (u,v)

    ldmia r11!, {r0-r1}             ; R0=v1u1v0u0 R1=v3u3v2u2

    ; Copy one snippet for 4 pixels = assemble 1 word for writing

    adr r8, uv_table_code_snippet

    ldr r7, [r8], #4                ; ldrb rX, [rY, #Z]
    .if UV_Table_BlankPixels
    and r2, r0, #0x0001             ; u0 invalid bit
    and r3, r0, #0x0100             ; v0 invalid bit
    orrs r14, r2, r3                ; u0 invalid or v0 invalid?
    ldrne r7, [r8, #11*4]           ; mov rX, #0
    .endif
    orr r7, r7, r9, lsl #12         ; dest reg
    .if UV_Table_BlankPixels
    bne .20                         ; Skip pixel
    .endif

    ; R0=0000v0u0
    bl uv_table_calc_offset
    orr r7, r7, r2                  ; offset [0, 4095]
    orr r7, r7, r3, lsl #16         ; base reg
    .20:
    str r7, [r12], #4               ; write out instruction 0

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    .if UV_Table_BlankPixels
    and r2, r0, #0x00010000         ; u1 invalid bit
    and r3, r0, #0x01000000         ; v1 invalid bit
    orrs r14, r2, r3                ; u1 invalid or v1 invalid?
    ldrne r7, [r8, #11*4]           ; mov r14, #0
    bne .21                         ; Skip pixel
    .endif

    mov r0, r0, lsr #16             ; R0=0000v1u1
    bl uv_table_calc_offset
    orr r7, r7, r2                  ; offset [0, 4095]
    orr r7, r7, r3, lsl #16         ; base reg
    .21:
    str r7, [r12], #4               ; write out instruction 1

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #8
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 2

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    .if UV_Table_BlankPixels
    and r2, r1, #0x0001             ; u2 invalid bit
    and r3, r1, #0x0100             ; v2 invalid bit
    orrs r14, r2, r3                ; u2 invalid or v2 invalid?
    ldrne r7, [r8, #9*4]            ; mov r14, #0
    bne .22                         ; Skip pixel
    .endif

    mov r0, r1                      ; R0=0000v2u2
    bl uv_table_calc_offset
    orr r7, r7, r2                  ; offset [0, 4095]
    orr r7, r7, r3, lsl #16         ; base reg
    .22:
    str r7, [r12], #4               ; write out instruction 3

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #16
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 4

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    .if UV_Table_BlankPixels
    and r2, r1, #0x00010000         ; u3 invalid bit
    and r3, r1, #0x01000000         ; v3 invalid bit
    orrs r14, r2, r3                ; u3 invalid or v3 invalid?
    ldrne r7, [r8, #7*4]            ; mov r14, #0
    bne .23                         ; Skip pixel
    .endif

    mov r0, r1, lsr #16             ; R0=0000v3u3  
    bl uv_table_calc_offset
    orr r7, r7, r2                  ; offset [0, 4095]
    orr r7, r7, r3, lsl #16         ; base reg
    .23:
    str r7, [r12], #4               ; write out instruction 5

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #24
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 6

    ; Do this 8 times for R0-7
    add r9, r9, #1
    cmp r9, #8
    bne .2
    ; Code size = 7 words x 8 times = 56 words

    ; Write out plot snippet.
    ldmia r8!, {r0-r2}
    stmia r12!, {r0-r2}
    ; Code size = 56 words + 3 words = 59 words

    subs r6, r6, #32                ; 8 words at a time = 32 chunky pixels.
    bne .3
    ; Code size = 59 words * 5 times = 295 words

    ; Write out increment screen ptr to skip a line.
    ldr r0, [r8], #4
    str r0, [r12], #4
    ; Code size = 295 words + 1 word = 296 words per row

    subs r10, r10, #1               ; next row
    bne .1
    ; Code size = 296 words * 128 rows = 37888 words

    ; Write out rts.
    ldr r0, [r8], #4
    str r0, [r12], #4
    ; Code size = 37889 words = 151556 bytes = 148K + 4 bytes!

    ldr pc, [sp], #4
.endif
