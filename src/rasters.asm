; ============================================================================
; Rasters via RasterMan.
; ============================================================================

rasters_init:
    ; Configure RasterMan for future compatibility.
    mov r0, #4              ; number of VIDC reg writes
    mov r1, #0              ; number of MEMC reg writes
    mov r2, #256            ; number of hsync interrupts
    mov r3, #55             ; start of hsyncs (from vsync pos)
    mov r4, #1              ; lines between hsyncs
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
	stmia r1!, {r6-r9}		; 4x VIDC commands per line.
	stmia r2!, {r6-r9}		; 4x VIDC commands per line.
	stmia r2!, {r6-r9}		; 4x VIDC commands per line.
	str r4, [r3], #4
	str r4, [r3], #4
	subs r5, r5, #1
	bne .1

	ldmfd sp, {r0-r3}
	swi RasterMan_SetTables
	ldmfd sp!, {r0-r3}

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

raster_list:
    ;    Repeat    Reg,        Start       Delta
    .long 48,       VIDC_Col1,  0x0000ff,     0x000500
    .long 48,       VIDC_Col1,  0x00ffff,   0xfffffffb
    .long 32,       VIDC_Col1,  0x00ff00,     0x080000  ; make green shorter
    .long 32,       VIDC_Col1,  0xffff00,   0xfffff800  ; make green shorter
    .long 48,       VIDC_Col1,  0xff0000,     0x000005
    .long 48,       VIDC_Col1,  0xff00ff,   0xfffb0000
    .long -1

raster_table_p:
    .long vidc_table_1_no_adr

raster_table_top_p:
    .long vidc_table_1_no_adr+256*4*4

rasters_tick:
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
    mov pc, lr

.if 0
    ; Add some actual rasters. Use a table, dummy.
    mov r3, #0
    adr r2, raster_list
.2:
    ldmia r2!, {r5-r9}
    cmp r5, #-1
    moveq pc, lr

    movs r4, r5, lsr #8     ; strip out repeat.
    moveq r4, #1            ; zero repeat means just 1.
    and r5, r5, #0xff       ; raster line.
    add r1, r0, r5, lsl #4  ; find line entry in VIDC table 1.

.3:
    stmia r1!, {r6-r9}      ; blat VIDC registers for line.
    subs r4, r4, #1
    bne .3

    str r3, [r1]            ; always reset bg colour to black.

    b .2

; Number repeats << 8 | Rasterline, VIDC registers x 4.
; 0xffffffff to end list.
raster_list:
    .long 0,   VIDC_Col8 | 0x222, VIDC_Col0 | 0x000, VIDC_Col0 | 0x000, VIDC_Col0 | 0x000
    .long 1,   VIDC_Border | 0x222, VIDC_Col0 | 0x000, VIDC_Col0 | 0x000, VIDC_Col0 | 0x000
    .long 170, VIDC_Border | 0x444, VIDC_Col0 | 0x000, VIDC_Col0 | 0x000, VIDC_Col0 | 0x000
    .long 171, VIDC_Col8 | 0x444, VIDC_Col0 | 0x000, VIDC_Col0 | 0x000, VIDC_Col0 | 0x000
    .long 254, VIDC_Border | 0x222, VIDC_Col0 | 0x000, VIDC_Col0 | 0x000, VIDC_Col0 | 0x000
    .long 255, VIDC_Col8 | 0x222, VIDC_Col0 | 0x000, VIDC_Col0 | 0x000, VIDC_Col0 | 0x000

    ; End.
    .long 0xffffffff
.endif

raster_tables:
	.long vidc_table_1_no_adr
	.long vidc_table_2_no_adr
	.long vidc_table_3_no_adr
	.long memc_table_no_adr

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
