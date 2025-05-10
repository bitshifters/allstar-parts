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

.equ UV_Table_Size,                 UV_Table_Columns*UV_Table_Rows

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
; NB. Not called directly, copied and patched at runtime.
; ============================================================================

uv_table_tex_dim_128_128:           ; 128x128
    and r2, r0, #0x007f             ; u0<<0  [0, 127]   7 bits
    and r3, r1, #0x007f             ; v0<<0  [0, 127]   7 bits
    mov r3, r3, lsl #20+7           ; bottom 5 bits of v0
    orr r2, r2, r3, lsr #20         ; v0 | u0           12 bits
    and r3, r1, #0x007f             ; v0<<8  [0, 127]   7 bits
    mov r3, r3, lsr #5              ; top 2 bits of v0

uv_table_tex_dim_64_256:            ; 64x256
    and r2, r0, #0x003f             ; u0<<0  [0, 63]    6 bits
    and r3, r1, #0x00ff             ; v0<<0  [0, 255]   8 bits
    mov r3, r3, lsl #20+6           ; bottom 6 bits of v0
    orr r2, r2, r3, lsr #20         ; v0 | u0           12 bits
    and r3, r1, #0x00ff             ; v0<<0  [0, 255]   8 bits
    mov r3, r3, lsr #6              ; top 2 bits of v0

uv_table_tex_dim_256_64:            ; 256x64
    and r2, r0, #0x00ff             ; u0<<0  [0, 255]  8 bits
    and r3, r1, #0x003f             ; v0<<0  [0, 63]   6 bits
    mov r3, r3, lsl #20+8           ; bottom 4 bits of v0
    orr r2, r2, r3, lsr #20         ; v0 | u0          12 bits
    and r3, r1, #0x003f             ; v0<<8  [0, 63]   6 bits
    mov r3, r3, lsr #4              ; top 2 bits of v0

uv_table_tex_dim_128_64:            ; 128x64
    and r2, r0, #0x007f             ; u0<<0  [0, 127]  7 bits
    and r3, r1, #0x003f             ; v0<<0  [0, 63]   6 bits
    mov r3, r3, lsl #20+7           ; bottom 5 bits of v0
    orr r2, r2, r3, lsr #20         ; v0 | u0          12 bits
    and r3, r1, #0x003f             ; v0<<0  [0, 63]   6 bits
    mov r3, r3, lsr #5              ; top 1 bits of v0

; ============================================================================
; Calculate the byte offset into a texture from the UV parameters.
; Params:
;   R0=0000VvUu
;   R5=000000ba
; No longer returns!
;   R2=byte offset   [0, 4096]
;   R3=base register [8, 11]
; Trashes: R4
; ============================================================================

uv_table_calc_offset:
    ; NB. v---- these instructions get overwritten at runtime!
    and r2, r0, #0x007f             ; u0<<0  [0, 127]   7 bits
    and r3, r1, #0x007f             ; v0<<0  [0, 127]   7 bits
    mov r3, r3, lsl #20+7           ; bottom 5 bits of v0
    orr r2, r2, r3, lsr #20         ; v0 | u0           12 bits
    and r3, r1, #0x007f             ; v0<<0  [0, 127]   7 bits
    mov r3, r3, lsr #5              ; top 2 bits of v0
    add r3, r3, #8                  ; [8, 11]
    ; NB. ^---- these instructions get overwritten at runtime!

    ; Shift value: a=0 (just LUT) a={1,3} (shading) a=4 (const colour)
    tst r5, #4                      ; test const bit
    bne .1                          ; const colour

    ; Read pixel from LUT.

    ; Write out pixel read instruction.
    ldr r7, [r8, #4]                ; ldrb rX, [rY, #Z]
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r2                  ; offset [0, 4095]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 0

    ; Write out optional shading operations.
    and r2, r5, #0x0000000f         ; a0

    ; If there is shading in this word then shift must be used.
    cmp r4, #0
    bne .200

    cmp r2, #0
    beq .201                        ; no shift

    .200:
    ldr r7, [r8, #8]                ; additional op shift (logical_colour >> a)
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9                  ; base reg
    add r2, r2, #4                  ; turn double pixel byte into single pixel
    orr r7, r7, r2, lsl #7          ; shift amount in bits 7-11
    str r7, [r12], #4               ; write out additional instruction 1a
    .201:

    ands r3, r5, #0x000000f0        ; b0 << 4
    beq .202
    ldr r7, [r8, #12]               ; additional op add (logical_colour >> a) + b
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    orr r7, r7, r3, lsr #4          ; b0
    str r7, [r12], #4               ; write out additional instruction 1a
    .202:
    b .3                            ; skip texture read and shade

    .1:

    ; Constant colour then use mov #imm.
    
    and r3, r5, #0x000000f0         ; b0 << 4

    ; Write out mov #imm const instruction.

    ldr r7, [r8, #0]                ; mov rX, #Y
    orr r7, r7, r9, lsl #12         ; dest reg

    ; If no shading in this word then use double pixels.
    cmp r4, #0
    orreq r3, r3, r3, lsl #4        ; no shading.
    orr r7, r7, r3, lsr #4          ; b0

    str r7, [r12], #4               ; write out instruction 0

    .3:
    add r8, r8, #16
    mov r5, r5, lsr #8              ; R5=00bababa
    mov r0, r0, lsr #8              ; R0=000000u1
    mov r1, r1, lsr #8              ; R1=000000v1
    mov pc, lr

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
    add r10, r11, #UV_Table_Size*2 ; shader data
    ; Fall through!

uv_table_gen_shader_code:
    str lr, [sp, #-4]!

    ; R0 = texture dimensions as enum
    ; Poke in code to calculate texture offset from dimensions.
    ; Super hackballs! :)
    adr r2, uv_table_calc_offset    ; dest
    adr r1, uv_table_tex_dim_128_128
    add r1, r1, r0, lsl #4          ; enum*6*4
    add r1, r1, r0, lsl #3          ; enum*6*4
    ldmia r1, {r3-r8}               ; copy 6 instrutions
    stmia r2, {r3-r8}

    ; R0=v1v0u1u0
    ; R1=v3v2u3u2
    ; R2=temp
    ; R3=temp
    ; R4=shading flag
    ; R5=b3a3b2a2b1a1b0a0
    ; R6=row counter | column counter<<16
    ; R7=opcode being assembled
    ; R8=code snippet ptr
    ; R9=dest register
    ; R10=shader data ptr
    ; R11=UV table ptr
    ; R12=code dest ptr
    ; R14=LR

    mov r5, #0
    mov r6, #UV_Table_Rows          ; rows to plot
.1:

    ; TODO: Create a jump table of entry points for each line.

    orr r6, r6, #UV_Table_Columns<<16  ; columns to plot
.3:
    mov r9, #0                      ; dest register

.2:
    ; Load 4 pixels worth of (u,v)

    ldr r0, [r11]                   ; R0=u3u2u1u0
    add r11, r11, #UV_Table_Size
    ldr r1, [r11], #4               ; R1=v3v2v1v0
    sub r11, r11, #UV_Table_Size

    ; And the shader data (if it exists)

    cmp r10, #0
    ldrne r5, [r10], #4             ; R5= 3 2 1 0
                                    ;    babababa

    ; Shift of zero (a=0) means 'just LUT', expect b=0.
    ; Shift of >=4 means 'const colour', b is the colour index.

    ; So R5=0x00000000 means no shading in this word.
    ; Or R5=0x04040404 means word is const colour = no shading.
    ; So shading mask is 0x03030303 if any shift bits set then have shading.
    ; If any shading in word then all shift 0's have to be taken.

    mov r4, #0x03
    orr r4, r4, r4, lsl #8
    orr r4, r4, r4, lsl #16         ; shading mask=0x03030303
    and r4, r5, r4                  ; any shading in word?

    ; Copy one snippet for 4 pixels = assemble 1 word for writing

    adr r8, uv_table_code_snippet

    ; Write out texture load & shade for pixel 0 in word.

    ; R0=000000u0
    ; R1=000000v0
    bl uv_table_calc_offset

    ; Write out texture load & shade for pixel 1 in word.

    str r9, [sp, #-4]!
    mov r9, #14                     ; dest=R14
    bl uv_table_calc_offset
    ldr r9, [sp], #4

    ; Merge texture pixel into screen word.

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #8
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 2

    ; Write out texture load & shade for pixel 2 in word.

    str r9, [sp, #-4]!
    mov r9, #14                     ; dest=R14
    bl uv_table_calc_offset
    ldr r9, [sp], #4

    ; Merge texture pixel into screen word.

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #16
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 4

    ; Write out texture load & shade for pixel 3 in word.

    str r9, [sp, #-4]!
    mov r9, #14                     ; dest=R14
    bl uv_table_calc_offset
    ldr r9, [sp], #4

    ; Merge texture pixel into screen word.

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #24
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 6

    ; If no shading in this word then use double-pixels.

    cmp r4, #0
    beq .290

    ; Write out full word ORR to double-up pixels.

    ldr r7, [r8]                    ; orr r0, r0, r0, lsl #4
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    orr r7, r7, r9                  ; src reg
    str r7, [r12], #4               ; write out full word shift
    .290:
    add r8, r8, #4

    ; Do this 8 times for R0-7.

    add r9, r9, #1
    cmp r9, #8
    bne .2
    ; Code size = 7 words x 8 times = 56 words
    ;           = 16 words x 8 times = 335876 bytes (!)

    ; Write out plot snippet.

    ldmia r8!,  {r0-r2}
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
    mov r0, #0                      ; 1c    <= mod base reg, imm value
    ldrb r0, [r0, #0]               ; 4c    <= mod imm offset, base reg, dest reg
    mov r0, r0, lsr #0              ; 1c    <= mod dest reg, shift value (optional)
    add r0, r0, #0                  ; 1c    <= mod dest reg, additional value (optional)

    mov r0, #0                      ; 1c    <= mod base reg, imm value
    ldrb r14, [r0, #0]              ; 4c    <= mod imm offset, base reg
    mov r14, r14, lsr #0            ; 1c    (optional)
    add r14, r14, #0                ; 1c    (optional)
    orr r0, r0, r14, lsl #8         ; 1c    <= mod dest reg

    mov r0, #0                      ; 1c    <= mod base reg, imm value
    ldrb r14, [r0, #0]              ; 4c    <= mod imm offset, base reg
    mov r14, r14, lsr #0            ; 1c    (optional)
    add r14, r14, #0                ; 1c    (optional)
    orr r0, r0, r14, lsl #16        ; 1c    <= mod dest reg

    mov r0, #0                      ; 1c    <= mod base reg, imm value
    ldrb r14, [r0, #0]              ; 4c    <= mod imm offset, base reg
    mov r14, r14, lsr #0            ; 1c    (optional)
    add r14, r14, #0                ; 1c    (optional)
    orr r0, r0, r14, lsl #24        ; 1c    <= mod dest reg

    orr r0, r0, r0, lsl #4          ; <= do this once per word, if needed

    ; Plot the pixels.
    add r14, r12, #Screen_Stride    ; 1c
    stmia r12!, {r0-r7}             ; 3+8*1.25=13c
    stmia r14!, {r0-r7}             ; 3+8*1.25=13c

    ; Skip a line.
    add r12, r12, #Screen_Stride    ; 1c

    ; Return.
    ldr pc, [sp], #4

; ============================================================================
; ============================================================================
