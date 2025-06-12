; ============================================================================
; Fine (8x8) scroller with 1 pixel scroll speed.
; Used in: Tipsy Cube.
; By default is masked on top of the screen.
; ============================================================================

.equ TipsyScroller_MaxGlyphs,   96
.equ TipsyScroller_Y_Pos,       0   ; in own buffer now.

.equ TipsyScroller_DropShadow,  0
.equ TipsyScroller_MaskPlot,    0
.equ TipsyScroller_UnrollPlot,  1   ; NB. Broke the loop version. :)

; ============================================================================

tipsy_scroller_text_p:
    .long tipsy_scroller_message_no_adr

tipsy_scroller_base_p:
    .long tipsy_scroller_message_no_adr

tipsy_scroller_speed:
    .long 2

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
    ; Character loop.
    .11:
    ldrb r1, [r12], #1
    cmp r1, #0
    ldreq r12, tipsy_scroller_base_p
    beq .11
    str r12, tipsy_scroller_text_p

    ; Copy glyph column into a shift buffer.
    cmp r1, #0x60
    bicgt r1, r1, #0x20             ; force upper case
    sub r1, r1, #32                 ; ascii space

    ldr r11, tipsy_scroller_font_p
    add r11, r11, r1, lsl #5        ; assumes 32 bytes per glyph.

    adr r10, tipsy_scroller_column_buffer
    ldmia r11, {r2-r9}
    stmia r10, {r2-r9}

.1:
    str r0, tipsy_scroller_column
    ldr pc, [sp], #4

; ============================================================================
; SLOW VERSION.
; ============================================================================

.if 0
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
    mov r10, #40                    ; screen column

    ldr r9, tipsy_scroller_font_p

    ; Character loop.
    .1:
    ldrb r0, [r12], #1
    cmp r0, #0
    ldreq r12, tipsy_scroller_base_p
    beq .1

    cmp r0, #0x60
    bicgt r0, r0, #0x20             ; force upper case
    sub r0, r0, #32                 ; ascii space
    add r14, r9, r0, lsl #5         ; assumes 32 bytes per glyph.

    .if TipsyScroller_UnrollPlot
    ; R14=temp
    ; R12=text p
    ; R11=screen p
    ; R10=screen column count
    ; R9=font p
    ; R8=shift
    ; R0-R7=font words

    ldmia r14!, {r0-r7}              ; 8 words
    ; 3+1.25*8=13c - save 3c to read 8 registers...

    cmp r10, #0
    addeq r11, r11, #8*Screen_Stride
    beq .10                          ; skip RHS

    ; RHS
    mov r14, r0, lsr r8              ; second glyph word shifted.
    str r14, [r11], #Screen_Stride
    mov r14, r1, lsr r8              ; second glyph word shifted.
    str r14, [r11], #Screen_Stride
    mov r14, r2, lsr r8              ; second glyph word shifted.
    str r14, [r11], #Screen_Stride
    mov r14, r3, lsr r8              ; second glyph word shifted.
    str r14, [r11], #Screen_Stride
    mov r14, r4, lsr r8              ; second glyph word shifted.
    str r14, [r11], #Screen_Stride
    mov r14, r5, lsr r8              ; second glyph word shifted.
    str r14, [r11], #Screen_Stride
    mov r14, r6, lsr r8              ; second glyph word shifted.
    str r14, [r11], #Screen_Stride
    mov r14, r7, lsr r8              ; second glyph word shifted.
    str r14, [r11], #Screen_Stride

    .10:
    cmp r10, #40
    beq .11                          ; skip LHS

    ; LHS
    sub r11, r11, #Screen_Stride*8+4; top of prev column
    rsb r8, r8, #32                 ; flip shift

    movs r0, r0, lsl r8             ; first glyph word shifted.
    ldrne r14, [r11]                ; load prev screen word.
    orrne r14, r14, r0              ; mask in first glyph word.
    strne r14, [r11]                ; store prev screen word.
    add r11, r11, #Screen_Stride

    movs r1, r1, lsl r8             ; first glyph word shifted.
    ldrne r14, [r11]                ; load prev screen word.
    orrne r14, r14, r1              ; mask in first glyph word.
    strne r14, [r11]                ; store prev screen word.
    add r11, r11, #Screen_Stride

    movs r2, r2, lsl r8             ; first glyph word shifted.
    ldrne r14, [r11]                ; load prev screen word.
    orrne r14, r14, r2              ; mask in first glyph word.
    strne r14, [r11]                ; store prev screen word.
    add r11, r11, #Screen_Stride

    movs r3, r3, lsl r8             ; first glyph word shifted.
    ldrne r14, [r11]                ; load prev screen word.
    orrne r14, r14, r3              ; mask in first glyph word.
    strne r14, [r11]                ; store prev screen word.
    add r11, r11, #Screen_Stride

    movs r4, r4, lsl r8             ; first glyph word shifted.
    ldrne r14, [r11]                ; load prev screen word.
    orrne r14, r14, r4              ; mask in first glyph word.
    strne r14, [r11]                ; store prev screen word.
    add r11, r11, #Screen_Stride

    movs r5, r5, lsl r8             ; first glyph word shifted.
    ldrne r14, [r11]                ; load prev screen word.
    orrne r14, r14, r5              ; mask in first glyph word.
    strne r14, [r11]                ; store prev screen word.
    add r11, r11, #Screen_Stride

    movs r6, r6, lsl r8             ; first glyph word shifted.
    ldrne r14, [r11]                ; load prev screen word.
    orrne r14, r14, r6              ; mask in first glyph word.
    strne r14, [r11]                ; store prev screen word.
    add r11, r11, #Screen_Stride

    movs r7, r7, lsl r8             ; first glyph word shifted.
    ldrne r14, [r11]                ; load prev screen word.
    orrne r14, r14, r7              ; mask in first glyph word.
    strne r14, [r11]                ; store prev screen word.
    add r11, r11, #Screen_Stride+4
    
    rsb r8, r8, #32                 ; flip shift
    .11:

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
    cmp r10, #40
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
    cmp r10, #0
    beq .4                          ; skip if right hand edge of screen.

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

    sub r11, r11, #8*Screen_Stride-4    ; next screen word.

    subs r10, r10, #1               ; next screen column.
    bpl .1                          ; 41 columns!

    ldr pc, [sp], #4
.endif

; font word = 0xabcdefgh
; scroll by 1 pixel = 0x0abcdefg - shift right by 4 for second word.
; scroll by 1 pixel = 0xi0000000 - shift left by 28 for first word.

; ============================================================================
; FAST VERSION.
; ============================================================================

.macro scroller_shift_left_by_pixels
	; shift word right 4 bits to clear left most pixel
	mov r0, r0, lsr r12
	; mask in right most pixel from next word
	orr r0, r0, r1, lsl r14
    ; etc.
	mov r1, r1, lsr r12
	orr r1, r1, r2, lsl r14
	mov r2, r2, lsr r12
	orr r2, r2, r3, lsl r14
	mov r3, r3, lsr r12
	orr r3, r3, r4, lsl r14
	mov r4, r4, lsr r12
	orr r4, r4, r5, lsl r14
	mov r5, r5, lsr r12
	orr r5, r5, r6, lsl r14
	mov r6, r6, lsr r12
	orr r6, r6, r7, lsl r14
	mov r7, r7, lsr r12
	orr r7, r7, r8, lsl r14
.endm

; R9=dst line address
; R10=src line address
; R11=right hand word ptr
; R12=pixel shift
tipsy_scroller_scroll_line:
	str lr, [sp, #-4]!
    rsb r14, r12, #32       ; reverse pixel shift (lsl #32-4*n)

    .rept (Screen_Width/64)-1
	ldmia r10, {r0-r8}		; read 9 words = 36 bytes = 72 pixels
    add r10, r10, #4*8      ; move 8 words
    scroller_shift_left_by_pixels
	stmia r9!, {r0-r7}		; write 8 words = 32 bytes = 64 pixels
    .endr

    ; Last block!
	ldmia r10!, {r0-r7}		; read 8 words = 32 bytes = 64 pixels
    ldr r8, [r11]
    scroller_shift_left_by_pixels
	stmia r9!, {r0-r7}		; write 8 words = 32 bytes = 64 pixels

	mov r8, r8, lsr r12	    ; rotate new data word
	str r8, [r11], #4      ; scroller_glyph_column_buffer[r11]=r10
	ldr pc, [sp], #4

; R12=screen addr
tipsy_scroller_draw_fast:
	str lr, [sp, #-4]!

    ; R9=dst line address
    ldr r0, tipsy_scroller_y_pos
    add r9, r12, r0, lsl #7
    add r9, r9, r0, lsl #5          ; assume stride is 160.

    ; R10=src line address
    mov r10, r9                     ; not double buffered.

    ; R11=right hand word ptr
    adr r11, tipsy_scroller_column_buffer

    ; R12=pixel shift
    ldr r12, tipsy_scroller_speed
    mov r12, r12, lsl #2    ; pixel shift (lsr #4*n)

	.rept 8
	bl tipsy_scroller_scroll_line
    .endr

	ldr pc, [sp], #4

; ============================================================================

tipsy_scroller_column_buffer:
    .skip 8*4

; ============================================================================
