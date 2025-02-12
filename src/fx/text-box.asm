; ============================================================================
; Text box.
; ============================================================================

.equ TextBox_WidthChars,    24
.equ TextBox_HeightChars,   12
.equ TextBox_MaxChars,      TextBox_WidthChars*TextBox_HeightChars
.equ TextBox_MaxGlyphs,     96
.equ TextBox_BaseASCII,     32
.equ TextBox_Colour,        0xf

.equ TextBox_PixelPlot,     1   ; SLOW!

text_box_chars_to_display:
    .long 0                 ; up to TextBox_MaxChars

text_box_text_p:
    .long text_box_test_text_no_adr                 ; ptr to text to display

text_box_pos_x:
    FLOAT_TO_FP 64.0         ; top-left corner (char for now)
;    .long 64        

text_box_pos_y:
    FLOAT_TO_FP 80.0         ; top-left corner (char for now)
;    .long 80                 ; top-left corner (line)

text_box_font_p:
    .long text_box_font_no_adr+32*8         ; skip top row of Atari glyphs.

text_box_font_mode9_p:
    .long text_box_font_mode9_no_adr

text_box_init:
    ; Explode font to MODE 9 for fast plotting.
    ldr r10, text_box_font_p            ; src
    ldr r11, text_box_font_mode9_p      ; dst

    mov r9, #TextBox_MaxGlyphs
.1:

    ldr r0, [r10], #4                   ; src word = 4x8-bit rows.
    mov r2, #8                          ; glyph height.
.2:
    mov r1, #0                          ; dst word.
    .rept 8
    mov r1, r1, lsl #4
    movs r0, r0, lsr #1
    orrcs r1, r1, #TextBox_Colour       ; or 0xf for mask.
    .endr
    str r1, [r11], #4

    cmp r2, #5
    ldreq r0, [r10], #4
    subs r2, r2, #1
    bne .2

    subs r9, r9, #1
    bne .1
    mov pc, lr

text_box_tick:
    ; Check if there's anything to do.
    ldr r0, text_box_text_p
    cmp r0, #0
    moveq pc, lr

    ; Display another char this frame.
    ldr r1, text_box_chars_to_display
    add r1, r1, #1
    cmp r1, #TextBox_MaxChars
    movgt r1, #TextBox_MaxChars
    str r1, text_box_chars_to_display

    ; TODO: Control over when chars appear and speed etc.

    mov pc, lr

; R12=screen addr
text_box_draw:
    str lr, [sp, #-4]!

    ; R8=ptr to string.
    ldr r8, text_box_text_p
    cmp r8, #0
    beq .9      ; nothing to do.

    ldr r14, text_box_chars_to_display
    cmp r14, #0
    beq .9      ; nothing to do.

    ; Calc screen ptr.
    ldr r1, text_box_pos_x
    mov r1, r1, asr #16
    ldr r2, text_box_pos_y
    mov r2, r2, asr #16
    add r11, r12, r2, lsl #7
    add r11, r11, r2, lsl #5        ; y*160
    and r7, r1, #7                  ; pixel offset
    mov r1, r1, lsr #3              ; word
    add r11, r11, r1, lsl #2        ; x*4

    ; R9=ptr to font
    ldr r9, text_box_font_mode9_p

    .if TextBox_PixelPlot
    mov r7, r7, lsl #2      ; P*4 = left word shift
    rsb r6, r7, #32         ; 32-P*4 = right word shift
    .endif

    sub r14, r14, #1        ; col count << 16 | char count
.1:
    ldrb r0, [r8], #1

    ; TODO: Any sort of vdu codes?
    subs r0, r0, #TextBox_BaseASCII
    bmi .10

    cmp r0, #TextBox_MaxGlyphs
    bge .10

    .if TextBox_PixelPlot
    add r12, r9, r0, lsl #5    ; 32 bytes per glyph.

    ; Per row.
    .rept 2
    ; Load word.
    ldmia r12!, {r0-r3}
    ; Shift word into two words to position at pixel.
    ;   Left word mask 0xffffffff << P*4 = R7
    ;   Right word mask 0xffffffff >> 32-P*4 = R6

    ; Load two screen words.
    ; Mask in two screen words.
    ; Write two screen words.
    mov r4, r0, lsl r7      ; left word
    mov r5, r0, lsr r6      ; right word
    ldmia r11, {r0,r10}
    orr r0, r0, r4
    orr r10, r10, r5
    stmia r11, {r0,r10}
    add r11, r11, #Screen_Stride
    ; 1+1+5.5+1+1+5.5+1=16 per row * 8 = 128 per glyph.
    ; 4x slower. :(
    ; Preshifting only saves us 2c per row=16c per glyph.
    ; Although could probably load more registers at once.

    mov r4, r1, lsl r7      ; left word
    mov r5, r1, lsr r6      ; right word
    ldmia r11, {r1,r10}
    orr r1, r1, r4
    orr r10, r10, r5
    stmia r11, {r1,r10}
    add r11, r11, #Screen_Stride

    mov r4, r2, lsl r7      ; left word
    mov r5, r2, lsr r6      ; right word
    ldmia r11, {r2,r10}
    orr r2, r2, r4
    orr r10, r10, r5
    stmia r11, {r2,r10}
    add r11, r11, #Screen_Stride

    mov r4, r3, lsl r7      ; left word
    mov r5, r3, lsr r6      ; right word
    ldmia r11, {r3,r10}
    orr r3, r3, r4
    orr r10, r10, r5
    stmia r11, {r3,r10}
    add r11, r11, #Screen_Stride
    .endr
    .else
    ; Blit glyph.
    add r0, r9, r0, lsl #5    ; 32 bytes per glyph.

    ldmia r0, {r0-r7}
    str r0, [r11], #Screen_Stride
    str r1, [r11], #Screen_Stride
    str r2, [r11], #Screen_Stride
    str r3, [r11], #Screen_Stride
    str r4, [r11], #Screen_Stride
    str r5, [r11], #Screen_Stride
    str r6, [r11], #Screen_Stride
    str r7, [r11], #Screen_Stride
    ; 4c per row=32c per glyph.
    .endif

.10:
    add r14, r14, #1<<16    ; column count in top half word.
    cmp r14, #TextBox_WidthChars<<16

    ; Adjust plot address to next glyph.
    sublt r11, r11, #Screen_Stride*8
    addlt r11, r11, #4

    ; Or the next line.
    subge r11, r11, #4*(TextBox_WidthChars-1)
    bicge r14, r14, #0x00ff0000 ; clear column count.

    ; Decrement char count and test if negative.
    sub r14, r14, #1
    movs r0, r14, asl #16
    bpl .1

.9:
    ldr pc, [sp], #4

text_box_test_text_no_adr:
    ;      012345678901234567890123
    .byte "+----------------------+"        ; 0
    .byte "|                      |"        ; 1
    .byte "|     HELLO WORLD!     |"        ; 2
    .byte "|                      |"        ; 3
    .byte "|    This will be      |"        ; 4
    .byte "|    some text that    |"        ; 5
    .byte "|    gets typed out    |"        ; 6
    .byte "|    with amazing      |"        ; 7
    .byte "|    wit etc.          |"        ; 8
    .byte "|                      |"        ; 9
    .byte "|                      |"        ; 10
    .byte "+----------------------+"        ; 11
