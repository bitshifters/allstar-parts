; ============================================================================
; UV tunnel (made into generic UV table map)
; ============================================================================

.equ UV_Tunnel_CodeSize,        151556
.equ UV_Tunnel_Columns,         160
.equ UV_Tunnel_Rows,            128

uv_tunnel_offset_u:
    .byte 0

uv_tunnel_offset_v:
    .byte 0

.p2align 2

uv_tunnel_texture_p:
    .long uv_tunnel_texture_no_adr

uv_tunnel_map_p:
    .long uv_tunnel_map_no_adr

uv_tunnel_code_p:
    .long uv_tunnel_unrolled_code_no_adr

; ============================================================================

; R12=screen addr
uv_tunnel_draw:
	str lr, [sp, #-4]!

    ldrb r9, uv_tunnel_offset_u
    ldrb r1, uv_tunnel_offset_v

    ldr r8, uv_tunnel_texture_p ; base of the texture

    add r8, r8, r9              ; add u offset
    add r8, r8, r1, lsl #7      ; add v offset (128 bytes per row)

    add r9, r8, #4096           ; only 4096 bytes are addressable at a time
    add r10, r9, #4096          ; using offset load, so use registers
    add r11, r10, #4096         ; 4*4096 = 16384 = 128*128

    ldr pc, uv_tunnel_code_p    ; pops return from stack.

; ============================================================================

uv_tunnel_tick:
    ldrb r9, uv_tunnel_offset_u
    add r9, r9, #1
    and r9, r9, #0x7f           ; u [0, 127]
    strb r9, uv_tunnel_offset_u

    ldrb r1, uv_tunnel_offset_v
    add r1, r1, #1
    and r1, r1, #0x7f           ; v [0, 127]
    strb r1, uv_tunnel_offset_v
    mov pc, lr

; ============================================================================

uv_tunnel_init:
    ldr r12, uv_tunnel_code_p       ; dest
    ldr r11, uv_tunnel_map_p        ; uv data
    ; Fall through!

; R11 = pointer to UV map data
; Each word is 2 pixels of packed U,V  = v1v0u1u0
; u,v [0, 255] => we're going to use half resolution.
; R12 = pointer to where unrolled code is written
; TODO: Feed in row/column count as params?
uv_tunnel_gen_code:
    str lr, [sp, #-4]!

    mov r10, #UV_Tunnel_Rows        ; rows to plot
.1:

    mov r6, #UV_Tunnel_Columns      ; columns to plot
.3:
    mov r9, #0                      ; dest register

.2:
    ; Load 4 pixels worth of (u,v)

    ldmia r11!, {r0-r1}             ; R0=v1v0u1u0 R1=v3v2u3u2

    ; Copy one snippet for 4 pixels = assemble 1 word for writing

    adr r8, uv_tunnel_code_snippet

    ldr r7, [r8], #4                ; ldrb rX, [rY, #Z]
    orr r7, r7, r9, lsl #12         ; dest reg
    and r2, r0, #0xfe               ; u0<<1  [0, 127]
    and r3, r0, #0xfe0000           ; v0<<17 [0, 127]
    mov r4, r3, lsl #10             ; bottom 5 bits of v0
    mov r2, r2, lsr #1
    orr r2, r2, r4, lsr #20         ; v0 | u0
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r3, lsr #22             ; top 2 bits of v0
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 0

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    and r2, r0, #0xfe00             ; u1<<9  [0, 127]
    and r3, r0, #0xfe000000         ; v1<<25 [0, 127]
    mov r4, r3, lsl #2              ; bottom 5 bits of v1
    mov r2, r2, lsr #9
    orr r2, r2, r4, lsr #20         ; v1 | u1
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r3, lsr #30             ; top 2 bits of v1
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 1

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #8
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 2

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    and r2, r1, #0xfe               ; u2<<1  [0, 127]
    and r3, r1, #0xfe0000           ; v2<<17 [0, 127]
    mov r4, r3, lsl #10             ; bottom 5 bits of v2
    mov r2, r2, lsr #1
    orr r2, r2, r4, lsr #20         ; v2 | u2
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r3, lsr #22             ; top 2 bits of v2
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 3

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #16
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 4

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    and r2, r1, #0xfe00             ; u3<<9  [0, 127]
    and r3, r1, #0xfe000000         ; v3<<25 [0, 127]
    mov r4, r3, lsl #2              ; bottom 5 bits of v3
    mov r2, r2, lsr #9
    orr r2, r2, r4, lsr #20         ; v3 | u3
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r3, lsr #30             ; top 2 bits of v3
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
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

; ============================================================================
; NB. Not called directly, copied and patched at runtime.
; ============================================================================

uv_tunnel_code_snippet:
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
