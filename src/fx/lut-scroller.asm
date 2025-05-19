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
    .long lut_scrolltext_text_no_adr

lut_scroller_text_base_p:
    .long lut_scrolltext_text_no_adr

; TODO: Decomp scroller font to top of unrolled code space!

lut_scroller_font_p:
    .long uv_table_code_max_no_adr - LUTScroller_FontDataSize

lut_scroller_v_pos:
    .long 255

lut_scroller_col:
    .long 0

lut_scroller_texture_p:
    .long uv_texture_data_no_adr

; R0=compressed font data.
lut_scroller_init:
    ldr r2, lut_scroller_text_base_p
    str r2, lut_scroller_text_p

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
    ; Update column.

    ldr r1, lut_scroller_text_p
    ldr r0, lut_scroller_col
    add r0, r0, #1
    cmp r0, #LUTScroller_GlyphWidth
    blt .1
    
    ; Update glyph.

    mov r0, #0
    ldrb r2, [r1, #1]!
    cmp r2, #0
    ldreq r1, lut_scroller_text_base_p
    str r1, lut_scroller_text_p

    .1:
    str r0, lut_scroller_col

    ; R12=texture map base
    ldr r12, lut_scroller_texture_p

    ; Update texture row.

    ldr r2, lut_scroller_v_pos
    add r2, r2, #1              ; assumes fixed scroll in v.
    cmp r2, #LUTScroller_TextureHeight
    movge r2, #0
    str r2, lut_scroller_v_pos

    ; Plot a line to the texture and the following texture.

    ; Plot address
    add r12, r12, r2, lsl #5    ; 32 byte stride


    ; R9=glyph read addr--
    ldr r9, lut_scroller_font_p

    ; R8=text ptr
    ldrb r3, [r1]               ; get ASCII

    ; Calc start address of glyph.
    sub r3, r3, #32
    add r9, r9, r3, lsl #9      ; +512
    add r9, r9, r3, lsl #6      ; +64 =576 bytes per glyph.

    ; R0=current byte column
    add r9, r9, r0, lsl #4      ; +16
    add r9, r9, r0, lsl #3      ; +8 = 24 bytes per column

    ; Plot a column twice.

    ldmia r9, {r0-r5}          ; 24 bytes
    stmia r12, {r0-r5}

    add r12, r12, #LUTScroller_TextureSize

    ldmia r9, {r0-r5}          ; 24 bytes
    stmia r12, {r0-r5}

    mov pc, lr

lut_scrolltext_text_no_adr:
    .byte "SPACE GREETS GO OUT TO... Alcatraz - Ate-Bit - AttentionWhore - "
    .byte "CRTC - DESiRE - Hooy Program - Inverse Phase - Logicoma - Loonies - "
    .byte "Proxima - Pulpo Corrosivo - Rabenauge - RiFT - Slipstream - YM Rockerz - "
    .byte "NOVA orgas - IRIS - Defekt - Epoch & Ivory - Bus Error Collective - "
    .byte "Evvvil (not a pity greet :)"
    .byte "          "
    .byte 0 ; end.
.p2align 2
