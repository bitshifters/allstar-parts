; ============================================================================
; Fine (8x8) scroller with 1 pixel scroll speed.
; Used in: Tipsy Cube.
; By default is masked on top of the screen.
; ============================================================================

.equ TipsyScroller_MaxGlyphs,   96
.equ TipsyScroller_Y_Pos,       256-8

.equ TipsyScroller_DropShadow,  0
.equ TipsyScroller_MaskPlot,    0
.equ TipsyScroller_UnrollPlot,  1

; ============================================================================

tipsy_scroller_text_p:
    .long tipsy_scroller_message_no_adr

tipsy_scroller_base_p:
    .long tipsy_scroller_message_no_adr

tipsy_scroller_speed:
    .long 1

tipsy_scroller_column:
    .long 0

tipsy_scroller_y_pos:
    .long TipsyScroller_Y_Pos

tipsy_scroller_font_p:
    .long fine_font_no_adr

; ============================================================================
; Assume glyphs are 8x8 pixels = 1 word per row in MODE 9 = 32 bytes per glyph.
; ============================================================================

; R0=glyph number.
; R6=glyph colour word.
; R8=screen background word.
; R11=screen addr ptr.
; Trashes: R0, R4, R5, R7.
.if 0
plot_gylph:
    mov r10, r11
    adr r9, font_data
    add r9, r9, r0, lsl #5              ; assumes 32 bytes per glyph.

    mov r7, #8
.1:                                     ; I don't think this has to be super fast.
    ldr r0, [r9], #4
.if 0
    ldr r4, [r10]
    bic r4, r4, r0
    orr r4, r4, r0
.else
    bic r4, r8, r0  ; clear glyph bits from screen bg
    and r5, r0, r6  ; colour gylph bits
    orr r4, r4, r5
.endif
    str r4, [r10], #Screen_Stride

    subs r7, r7, #1
    bne .1

    add r11, r11, #4                ; next word
    mov pc, lr

; R1=string ptr
; R6=glyph colour word.
; R8=screen background word.
; R11=screen addr ptr.
plot_string:
    str lr, [sp, #-4]!
.1:
    ldrb r0, [r1], #1
    cmp r0, #0
    ldreq pc, [sp], #4

    sub r0, r0, #32    ; ASCII ' '
    bl plot_gylph
    b .1    
.endif

; ============================================================================

tipsy_scroller_tick:
    str lr, [sp, #-4]!

    ldr r0, tipsy_scroller_column
    ldr r1, tipsy_scroller_speed
    add r0, r0, r1
    cmp r0, #8
    blt .1

    sub r0, r0, #8
    ldr r12, tipsy_scroller_text_p
    add r12, r12, #1
    ldrb r1, [r12]
    cmp r1, #0
    ldreq r12, tipsy_scroller_base_p
    str r12, tipsy_scroller_text_p

.1:
    str r0, tipsy_scroller_column
    ldr pc, [sp], #4


; R12=screen addr ptr.
tipsy_scroller_draw:
    str lr, [sp, #-4]!

    ldr r0, tipsy_scroller_y_pos
    add r11, r12, r0, lsl #7
    add r11, r11, r0, lsl #5        ; assume stride is 160.

    ldr r12, tipsy_scroller_text_p
    ldr r8, tipsy_scroller_column
    mov r8, r8, lsl #2              ; shift for second word.
    rsb r7, r8, #32                 ; shift for first word.
    mov r10, #0                     ; screen column

    ldr r14, tipsy_scroller_font_p

    ; Character loop.
    .1:
    ldrb r0, [r12], #1
    cmp r0, #0
    ldreq r12, tipsy_scroller_base_p
    beq .1

    sub r0, r0, #32                 ; ascii space
    add r9, r14, r0, lsl #5         ; assumes 32 bytes per glyph.

    .if TipsyScroller_UnrollPlot
    ; R14=font base p
    ; R12=text p
    ; R11=screen p
    ; R10=screen col
    ; R9=font p
    ; R8=shift 2
    ; R7=shift 1

    .rept 2
    ldmia r9!, {r3-r6}              ; four words = four rows

    mov r1, r3, lsr r8              ; second glyph word shifted.
    cmp r10, #0
    addeq pc, pc, #16               ; skip 5 instructions
    movs r3, r3, lsl r7             ; first glyph word shifted.
    ldrne r2, [r11, #-4]            ; load prev screen word.
    bicne r2, r2, r3
    orrne r2, r2, r3                ; mask in first glyph word.
    strne r2, [r11, #-4]            ; store prev screen word.
    cmp r10, #40                    ; skip RH edge
    strlt r1, [r11]
    add r11, r11, #Screen_Stride

    mov r1, r4, lsr r8              ; second glyph word shifted.
    cmp r10, #0
    addeq pc, pc, #16               ; skip 5 instructions
    movs r4, r4, lsl r7             ; first glyph word shifted.
    ldrne r2, [r11, #-4]            ; load prev screen word.
    bicne r2, r2, r4
    orrne r2, r2, r4                ; mask in first glyph word.
    strne r2, [r11, #-4]            ; store prev screen word.
    cmp r10, #40                    ; skip RH edge
    strlt r1, [r11]
    add r11, r11, #Screen_Stride

    mov r1, r5, lsr r8              ; second glyph word shifted.
    cmp r10, #0
    addeq pc, pc, #16               ; skip 5 instructions
    movs r5, r5, lsl r7             ; first glyph word shifted.
    ldrne r2, [r11, #-4]            ; load prev screen word.
    bicne r2, r2, r5
    orrne r2, r2, r5                ; mask in first glyph word.
    strne r2, [r11, #-4]            ; store prev screen word.
    cmp r10, #40                    ; skip RH edge
    strlt r1, [r11]
    add r11, r11, #Screen_Stride

    mov r1, r6, lsr r8              ; second glyph word shifted.
    cmp r10, #0
    addeq pc, pc, #16               ; skip 5 instructions
    movs r6, r6, lsl r7             ; first glyph word shifted.
    ldrne r2, [r11, #-4]            ; load prev screen word.
    bicne r2, r2, r6
    orrne r2, r2, r6                ; mask in first glyph word.
    strne r2, [r11, #-4]            ; store prev screen word.
    cmp r10, #40                    ; skip RH edge
    strlt r1, [r11]
    add r11, r11, #Screen_Stride
    .endr

    .else
    ; Row loop.
    mov r6, #8

    .2:
    ldr r0, [r9], #4

    mov r1, r0, lsr r8              ; second glyph word shifted.
    mov r0, r0, lsl r7              ; first glyph word shifted.

    cmp r0, #0                      ; if first glyph is empty?
    beq .3                          ; skip.

    ; display first glyph word in prev screen word.
    cmp r10, #0
    beq .3                          ; skip if left hand edge of screen.

    ldr r2, [r11, #-4]              ; load prev screen word.
    bic r2, r2, r0
    orr r2, r2, r0                  ; mask in first glyph word.
    str r2, [r11, #-4]              ; store prev screen word.

    ; drop shadow?
    .if TipsyScroller_DropShadow
    ldr r2, [r11, #Screen_Stride-4] ; load prev screen word.
    bic r2, r2, r0
    str r2, [r11, #Screen_Stride-4] ; store prev screen word.
    .endif

    ; display second glyph word in current screen word.
    .3:
    cmp r10, #40
    bge .4                          ; skip if right hand edge of screen.

    .if TipsyScroller_MaskPlot
    ldr r2, [r11]                   ; load current screen word.
    bic r2, r2, r1
    orr r2, r2, r1                  ; mask in second glyph word.
    str r2, [r11]                   ; store prev screen word.
    .else
    str r1, [r11]
    .endif

    ; drop shadow?
    .if TipsyScroller_DropShadow
    ldr r2, [r11, #Screen_Stride]   ; load prev screen word.
    bic r2, r2, r1
    str r2, [r11, #Screen_Stride]   ; store prev screen word.
    .endif

    .4:
    add r11, r11, #Screen_Stride
    subs r6, r6, #1
    bne .2                          ; next row.
    .endif

    sub r11, r11, #8*Screen_Stride
    add r11, r11, #4                ; next screen word.

    add r10, r10, #1                ; next screen column.
    cmp r10, #41                    ; one extra column for scroll!
    bne .1

    ldr pc, [sp], #4

; font word = 0xabcdefgh
; scroll by 1 pixel = 0x0abcdefg - shift right by 4 for second word.
; scroll by 1 pixel = 0xi0000000 - shift left by 28 for first word.

; ============================================================================

tipsy_scroller_message_no_adr:
; At 1 pixel/frame = 6.4s to traverse the screen.
; Speed = 40 chars/6.4s = 6.25 chars/s
; 16 patterns at 6 ticks/row = 122.88s
; So in 122.88s 122.88s * 6.25 chars/s = 768 chars.
;                                                                                                             1
;                   1         2         3         4         5         6         7         8         9         0
;          1........0.........0.........0.........0.........0.........0.........0.........0.........0.........0
    .byte "  Is it a terrible twister?  No... this is the fir"
    .byte "st ever tipsy cube intro for the Acorn Archimedes!  Brought to you by Bitshifters & Slipstream for t"
    .byte "he FieldFX 2022 New Year's demostream.  Inspired by the Gerp 2014 rubber vector challenge, just rock"
    .byte 0
    .p2align 2

; ============================================================================
