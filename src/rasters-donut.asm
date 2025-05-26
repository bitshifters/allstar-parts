; ============================================================================
; Rasters via RasterMan.
; ============================================================================

raster_table_p:
    .long vidc_table_1_no_adr

raster_table_top_p:
    .long vidc_table_1_no_adr+256*4*4

raster_tables:
	.long vidc_table_1_no_adr
	.long -1
	.long -1
	.long -1

; ============================================================================

rasters_init:
    ; Configure RasterMan for future compatibility.
    mov r0, #4              ; number of VIDC reg writes
    mov r1, #0              ; number of MEMC reg writes
    mov r2, #1              ; number of scanlines between H-interrupts
    swi RasterMan_Configure

	; Init tables.
	adr r5, raster_tables
	ldmia r5, {r0-r3}
	stmfd sp!, {r0-r3}

	mov r4, #0
	mov r6, #VIDC_Border | 0x000
	mov r7, r6
	mov r8, r6
	mov r9, r6
	mov r5, #256
.1:
	stmia r0!, {r6-r9}		; 4x VIDC commands per line.
	stmia r0!, {r6-r9}		; Double up as we're scrolling through the first buffer.
    ; NB. No longer need to fill redundant buffers.
	subs r5, r5, #1
	bne .1

	ldmfd sp!, {r0-r3}
	swi RasterMan_SetTables
    mov pc, lr

.if 0
rasters_set_table_from_list:
	adr r5, raster_tables
	ldmia r5, {r0-r3}

    ; Make a raster table.
    ldr r1, raster_table_top_p  ; dupe
    mov r3, #0
    adr r2, raster_list
.2:
    ldmia r2!, {r5-r8}      ; R5=repeat, R6=reg, R7=start, R8=delta
    cmp r5, #-1
    moveq pc, lr

.3:
    ; Construct VIDC reg
    mov r9, r7, lsr #4
    and r9, r9, #0xf        ; red
    mov r4, r7, lsr #12
    and r4, r4, #0xf        ; green
    orr r9, r9, r4, lsl #4  ; GR
    mov r4, r7, lsr #20
    and r4, r4, #0xf        ; blue
    orr r9, r9, r4, lsl #8  ; BGR
    orr r9, r9, r6          ; VIDC_reg | BGR

    ; Store reg.
    str r9, [r0], #16
    str r9, [r1], #16

    add r7, r7, r8
    subs r5, r5, #1
    bne .3

    b .2
.endif

rasters_donut_init:
    ; Copy bg fade to vidc1.
	adr r0, raster_tables
    ldr r0, [r0, #0]            ; vidc1

    add r0, r0, #56*16

    adr r1, raster_donut_bg
    ldmia r1!, {r2-r9}           ; 8 words
    stmia r0!, {r2-r9}
    ldmia r1!, {r2-r9}           ; 8 words
    stmia r0!, {r2-r9}

    add r0, r0, #188*16

    adr r1, raster_scroller_bg
    ldmia r1, {r2-r9}           ; 8 words
    str r2, [r0], #16
    str r3, [r0], #16
    str r4, [r0], #16
    str r5, [r0], #16
    str r6, [r0], #16
    str r7, [r0], #16
    str r8, [r0], #16
    str r9, [r0], #16

    mov pc, lr

rasters_tick:
.if 0
	adr r5, raster_tables
	ldmia r5, {r0-r3}

    ldr r4, raster_table_p
    ldr r6, raster_table_top_p
    add r4, r4, #16             ; step 4 writes = one line
    cmp r4, r6
    movge r4, r0                ; reset to base
    str r4, raster_table_p
    mov r0, r4

    ; Update table pointers.
	swi RasterMan_SetTables
.endif
    mov pc, lr

; ============================================================================

.if 0   ; if need to double-buffer raster table.
rasters_copy_table:
    adr r9, vidc_table_1
    adr r10, vidc_table_2
    adr r11, vidc_table_3

.1:
    ldmia r10!, {r0-r7}
    stmia r9!, {r0-r7}
    cmp r10, r11
    blt .1

    mov pc, lr
.endif

; ============================================================================

; First 56 lines for the logo are fixed palette - set in vsync?
; Next 192 lines are the donut - ?
; Last 8 lines are the scroller - set bg blend?

raster_list:
    ;    Repeat    Reg,        Start       Delta
    .long 48,       VIDC_Col15,  0x0000ff,     0x000500
    .long 48,       VIDC_Col15,  0x00ffff,   0xfffffffb
    .long 32,       VIDC_Col15,  0x00ff00,     0x080000  ; make green shorter
    .long 32,       VIDC_Col15,  0xffff00,   0xfffff800  ; make green shorter
    .long 48,       VIDC_Col15,  0xff0000,     0x000005
    .long 48,       VIDC_Col15,  0xff00ff,   0xfffb0000
    .long -1

raster_donut_bg:
    .long           VIDC_Col0 | 0x000
    .long           VIDC_Col1 | 0x002
    .long           VIDC_Col2 | 0x004
    .long           VIDC_Col3 | 0x006
    .long           VIDC_Col4 | 0x008
    .long           VIDC_Col5 | 0x00a
    .long           VIDC_Col6 | 0x00c
    .long           VIDC_Col7 | 0x02e
    .long           VIDC_Col8 | 0x04e
    .long           VIDC_Col9 | 0x06e
    .long           VIDC_Col10 | 0x08e
    .long           VIDC_Col11 | 0x0ae
    .long           VIDC_Col12 | 0x0ce
    .long           VIDC_Col13 | 0x0de
    .long           VIDC_Col14 | 0xcee
    .long           VIDC_Col15 | 0xfff

raster_scroller_bg:
    .long           VIDC_Col0 | 0x100
    .long           VIDC_Col0 | 0x300
    .long           VIDC_Col0 | 0x500
    .long           VIDC_Col0 | 0x700
    .long           VIDC_Col0 | 0x900
    .long           VIDC_Col0 | 0xb00
    .long           VIDC_Col0 | 0xd00
    .long           VIDC_Col0 | 0xf00

; ============================================================================
