; ============================================================================
; LUT scroller, one byte per column plotted to texture
; ============================================================================

.equ LUTScroller_GlyphWidth,        24
.equ LUTScroller_GlyphHeight,       24
.equ LUTScroller_NumGlyphs,         96

.equ LUTScroller_FontDataSize,      (LUTScroller_GlyphWidth*LUTScroller_GlyphHeight*LUTScroller_NumGlyphs)

.equ LUTScroller_TextureWidth,      32
.equ LUTScroller_TextureHeight,     256
.equ LUTScroller_TextureSize,       (LUTScroller_TextureWidth*LUTScroller_TextureHeight)

lut_scroller_text_p:
    .long 0

lut_scroller_text_base_p:
    .long 0

lut_scroller_font_p:
    .long uv_table_code_max_no_adr - LUTScroller_FontDataSize

lut_scroller_v_pos:
    .long 255

lut_scroller_col:
    .long 0

lut_scroller_texture_p:
    .long uv_texture_data_no_adr

lut_scroller_prop_p:
    .long 0

; R0=compressed font data.
; R1=ptr to scroll text.
; R2=ptr to proportional glyph data.
lut_scroller_init:
    str r1, lut_scroller_text_base_p
    str r1, lut_scroller_text_p
    str r2, lut_scroller_prop_p

    ldr r2, uv_table_fp_v
    mov r2, r2, asr #16
    and r2, r2, #0xff
    str r2, lut_scroller_v_pos

    ldr r1, lut_scroller_font_p

    .if _DEBUG
    ldr r3, uv_table_code_top
    cmp r1, r3

    adrlt r0, err_fonthituvcode
    swilt OS_GenerateError
    .endif

    b unlz4

.if _DEBUG
err_fonthituvcode:
	.long 0
	.byte "LUT scroller font data hit unrolled UV code!"
	.p2align 2
	.long 0
.endif

lut_scroller_tick:
    str lr, [sp, #-4]!

    ; R0-R5 = texture col
    ; R6 = number cols to plot
    ; R7 = current glyph column
    ; R8 = v pos
    ; R9 = glyph ptr
    ; R10 = glyph no. / glyph width
    ; R11 = text ptr
    ; R12 = write
    ; R14 = prop data ptr.

    ldr r8, uv_table_fp_v
    mov r8, r8, asr #16
    and r8, r8, #0xff               ; relies on TextureHeight==256
    ldr r7, lut_scroller_v_pos
    subs r6, r8, r7  ; number of cols to plot
    addmi r6, r6, #LUTScroller_TextureHeight
    str r8, lut_scroller_v_pos      ; end v pos
    mov r8, r7                      ; start from prev v pos

    ldr r9, lut_scroller_font_p     ; R9=glyph read addr
    ldr r11, lut_scroller_text_p
    ldr r12, lut_scroller_texture_p
    ldr r14, lut_scroller_prop_p

    ; Plot into texture at old v pos
    add r12, r12, r7, lsl #5        ; 32 byte stride

    ldr r7, lut_scroller_col

    ; Calc start address of glyph.
    ldrb r10, [r11]                 ; get ASCII
    sub r10, r10, #32
    add r9, r9, r10, lsl #9         ; +512
    add r9, r9, r10, lsl #6         ; +64 =576 bytes per glyph.

    ; r7=current byte column
    add r9, r9, r7, lsl #4          ; +16
    add r9, r9, r7, lsl #3          ; +8 = 24 bytes per column

    ; r10=glyph width
    add r10, r14, r10, lsl #1
    ldrb r10, [r10, #1]             ; end

    ; For each column.
.3:
    ; Plot a column (twice).
    ldmia r9!, {r0-r5}              ; 24 bytes
    stmia r12, {r0-r5}
    add r12, r12, #LUTScroller_TextureSize
    stmia r12, {r0-r5}
    sub r12, r12, #LUTScroller_TextureSize-LUTScroller_TextureWidth

    ; Next column in glyph.
    add r7, r7, #1
    cmp r7, r10                     ; #LUTScroller_GlyphWidth
    ble .2

    ; Next char in text.
    ldrb r10, [r11, #1]!
    cmp r10, #0
    ldreq r11, lut_scroller_text_base_p
    ldreqb r10, [r11]
    sub r10, r10, #32               ; ASCII

    ; Calc start address of glyph.
    ldr r9, lut_scroller_font_p     ; R9=glyph read addr
    add r9, r9, r10, lsl #9         ; +512
    add r9, r9, r10, lsl #6         ; +64 =576 bytes per glyph.

    ; r10=glyph width
    add r10, r14, r10, lsl #1
    ldrb r7, [r10, #0]              ; start
    ldrb r10, [r10, #1]             ; end

.2:
    ; Next column in texture.
    add r8, r8, #1
    cmp r8, #LUTScroller_TextureHeight

    ; Reset texture ptr to base when we wrap.
    movge r8, #0
    ldrge r12, lut_scroller_texture_p

    ; Next column this frame.
    subs r6, r6, #1
    bne .3
    
    ; For next time.
    str r7, lut_scroller_col
    str r11, lut_scroller_text_p

    ldr pc, [sp], #4
