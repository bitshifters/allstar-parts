; ============================================================================
; App standard code.
; Hack as necessary per prod.
; ============================================================================

.equ TipsyScrollerOnVsync,      0
.equ RasterSplitLine,           56+90			; 56 lines from vsync to screen start

; ============================================================================

.if AppConfig_UseQtmEmbedded
QtmEmbedded_Init:
    .long QtmEmbedded_Base + 52

QtmEmbedded_Swi:
    .long QtmEmbedded_Base + 56

QtmEmbedded_Service:
    .long QtmEmbedded_Base + 60

QtmEmbedded_Exit:
    .long QtmEmbedded_Base + 64
.endif

; ============================================================================
; App debug code.
; ============================================================================

.if _DEBUG
app_init_debug:
    str lr, [sp, #-4]!

    bl debug_init

    DEBUG_REGISTER_VAR_EX debug_frame_rate, debug_plot_addr_as_dec4
    ; DEBUG_REGISTER_VAR_EX vsync_delta, debug_plot_addr_as_dec4
    DEBUG_REGISTER_VAR frame_counter
    .if _DEMO_PART==_PART_DONUT
    DEBUG_REGISTER_VAR scene3d_stats_quads_plotted
    .endif
;    DEBUG_REGISTER_VAR music_pos

    DEBUG_REGISTER_KEY          RMKey_Space,      debug_toggle_main_loop_pause,  0
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_A,          debug_set_byte_true,           debug_restart_flag
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_S,          debug_set_byte_true,           debug_main_loop_step
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_D,          debug_toggle_byte,             debug_show_info
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_R,          debug_toggle_byte,             debug_show_rasters
    DEBUG_REGISTER_KEY          RMKey_ArrowRight, debug_skip_to_next_pattern,    0

;    DEBUG_REGISTER_VAR math_var_active_count
    ldr pc, [sp], #4
.endif

; ============================================================================
; App video code.
; ============================================================================

vdu_screen_disable_cursor:
.byte 22, VideoConfig_VduMode, 23,1,0,0,0,0,0,0,0,0,17,7
.p2align 2

app_init_video:
    str lr, [sp, #-4]!

	; Set screen MODE & disable cursor
	adr r0, vdu_screen_disable_cursor
	mov r1, #14
	swi OS_WriteN

	; Set screen size for number of buffers
	MOV r0, #DynArea_Screen
	SWI OS_ReadDynamicArea
	MOV r0, #DynArea_Screen
	MOV r2, #Mode_Bytes * VideoConfig_ScreenBanks
	SUBS r1, r2, r1
	SWI OS_ChangeDynamicArea
	MOV r0, #DynArea_Screen
	SWI OS_ReadDynamicArea
	CMP r1, r2
	ADRCC r0, error_noscreenmem
	SWICC OS_GenerateError

	; Clear all screen buffers
	mov r1, #1
.1:
	str r1, write_bank

	; CLS bank N
	mov r0, #OSByte_WriteVDUBank
	swi OS_Byte
	SWI OS_WriteI + 12		; cls

	add r1, r1, #1
	cmp r1, #VideoConfig_ScreenBanks
	ble .1

    ; Display prev bank.
    subs r1, r1, #1
    movle r1, #VideoConfig_ScreenBanks
    mov r0, #OSByte_WriteDisplayBank
    swi OS_Byte
    str r1, displayed_bank

    ; Get address of the displayed bank.
    bl get_screen_addr
    ldr r12, screen_addr
    str r12, init_screen_addr

    ; No flashing colours (FFS).
    mov r0, #9
    mov r1, #0
    swi OS_Byte

.if AppConfig_UseQtmEmbedded
    mov lr, pc
    ldr pc, QtmEmbedded_Init
.endif
    ldr pc, [sp], #4

; TODO: Junk this for non_DEBUG?
error_noscreenmem:
	.long 0
	.byte "Cannot allocate screen memory!"
	.p2align 2
	.long 0


; ============================================================================
; App audio code.
; ============================================================================

.if AppConfig_LoadModFromFile
music_filename:
	.byte "<Demo$Dir>.Music",0
	.p2align 2
.else
music_mod_p:
	.long music_mod_no_adr		; 14
.endif

music_sample_speed:
    .long 0

; R12=top of RAM used.
app_init_audio:
    .if AppConfig_UseRasterMan
   	; Required to make QTM play nicely with RasterMan.
	mov r0, #4
	mov r1, #-1
	mov r2, #-1
	swi QTM_SoundControl
    .endif

.if AppConfig_DynamicSampleSpeed
	; Count how long the init takes as a very rough estimate of CPU speed.
	ldr r1, vsync_count
	cmp r1, #AudioConfig_SampleSpeed_CPUThreshold
	movge r0, #AudioConfig_SampleSpeed_SlowCPU
	movlt r0, #AudioConfig_SampleSpeed_FastCPU
.else
    mov r0, #AudioConfig_SampleSpeed_Default
.endif
    str r0, music_sample_speed      ; to query on real hw because I paranoid.

	; Setup QTM for our needs.
	QTMSWI QTM_SetSampleSpeed

    .if 0
    mov r0, #AudioConfig_VuBars_Effect
    mov r1, #AudioConfig_VuBars_Gravity
    QTMSWI QTM_VUBarControl
    .endif

    mov r0, #1
    mov r1, #AudioConfig_StereoPos_Ch1
    QTMSWI QTM_Stereo

    mov r0, #2
    mov r1, #AudioConfig_StereoPos_Ch2
    QTMSWI QTM_Stereo

    mov r0, #3
    mov r1, #AudioConfig_StereoPos_Ch3
    QTMSWI QTM_Stereo

    mov r0, #4
    mov r1, #AudioConfig_StereoPos_Ch4
    QTMSWI QTM_Stereo

    mov r0, #0b0010
    .if SeqConfig_EnableLoop
    mov r1, #0b0000
    .else
    mov r1, #0b0010
    .endif
    QTMSWI QTM_MusicOptions

	; Load the music.
    .if AppConfig_LoadModFromFile
    adr r0, music_filename
    mov r1, r12             ; HIMEM.
    .else
	mov r0, #0              ; load from address, don't copy to RMA.
    ldr r1, music_mod_p
    .endif
	QTMSWI QTM_Load

    mov pc, lr


; ============================================================================
; App late initialisation for things that require access to the screen.
; ============================================================================

; R12=screen addr.
app_late_init:
    str lr, [sp, #-4]!

.if AppConfig_UseRasterMan
    bl rasters_init
.endif

    ; Copy the logo to all of our screen buffers.
    .if _DEMO_PART==_PART_DONUT
    adr r0, app_logo_p
    ldmia r0, {r0-r2}
    bl app_copy_to_screen

    bl get_next_bank_for_writing

    adr r0, app_logo_p
    ldmia r0, {r0-r2}
    bl app_copy_to_screen

    bl get_next_bank_for_writing

    adr r0, app_logo_p
    ldmia r0, {r0-r2}
    bl app_copy_to_screen
    .endif

    mov r0, #1
    str r0, app_ready

    ;ldr r10, init_screen_addr
    ;bl text_pool_init

    ldr pc, [sp], #4
; TODO: Make this more generic or include in sequence?

.if _DEMO_PART==_PART_DONUT
app_logo_p:
    .long temp_logo_no_adr  ; src ptr
    .long 0                 ; offset
    .long 48*Screen_Stride  ; length
.endif

app_ready:
    .long 0

; ============================================================================
; App main loop.
; ============================================================================

; Always called, regardless of tick status.
app_pre_tick_frame:
    mov pc, lr

; ============================================================================
; Interrupt handling.
; ============================================================================

.if AppConfig_InstallIrqHandler
oldirqhandler:
	.long 0

oldirqjumper:
	.long 0

vsyncstartdelay:
	.long 127*RasterSplitLine  ;2000000/50.08

install_irq_handler:
	mov r1, #0x18					; IRQ vector.
	
	; Remember previous IRQ branch call.
	ldr r0, [r1]					; old IRQ handler.
	str r0, oldirqjumper

	; Calculate old IRQ handler address from branch opcode.
	bic r0, r0, #0xff000000
	mov r0, r0, lsl #2
	add r0, r0, #32
	str r0, oldirqhandler

	; Set Timer 1.
	SWI		OS_EnterOS
	MOV     R12,#0x3200000           ;IOC address

	TEQP    PC,#0b11<<26 | 0b11  ;jam all interrupts!

	LDR     R0,vsyncstartdelay
	STRB    R0,[R12,#0x50]
	MOV     R0,R0,LSR#8
	STRB    R0,[R12,#0x54]           ;prepare timer 1 for waiting until screen start
									;don't start timer1, done on next Vs...
	TEQP    PC,#0
	MOV     R0,R0

	; Install our IRQ handler.
	swi OS_IntOff
	adr r0, irq_handler
	sub r0, r0, #32
	mov r0, r0, lsr #2
	add r0, r0, #0xea000000			; B irq_handler.
	str r0, [r1]
	swi OS_IntOn

	mov pc, lr

uninstall_irq_handler:
	mov r1, #0x18					; IRQ vector.
	
	; Restore previous IRQ branch call.
	ldr r0, oldirqjumper
	str r0, [r1]

	mov pc, lr

irq_handler:
	STMFD   R13!,{R0-R1,R11-R12}
	MOV     R12,#0x3200000           ;IOC address
	LDRB    R0,[R12,#0x14+0]
	TST     R0,#1<<6 | (1<<3)
	BEQ     nottimer1orVs           ;not T1 or Vs, back to RISCOS

	TEQP    PC,#0b11<<26 | 0b11
	MOV     R0,R0

	MOV     R11,#VIDC_Write
	TST     R0,#1<<3
	BNE     handle_vsync                   ;...Vs higher priority than T1

timer1:
	mov r0, #0
	str r0, vsync_bodge

	; WRITE VIDC REGS HERE!

	LDRB    R0,[R12,#0x18]
	BIC     R0,R0,#1<<6
	STRB    R0,[R12,#0x18]           ;stop T1 irq...

exittimer1:
	TEQP    PC,#0b10<<26 | 0b10
	MOV     R0,R0
	LDMFD   R13!,{R0-R1,R11-R12}
	SUBS    PC,R14,#4

handle_vsync:
	ldr r0, vsync_bodge
	cmp r0, #0
	beq .3
	b exitVs
.3:
	mov r0, #1
	str r0, vsync_bodge

	STRB    R0,[R12,#0x58]           ;T1 GO (latch already set up)
	LDRB    R0,[R12,#0x18]
	ORR     R0,R0,#1<<6
	STRB    R0,[R12,#0x18]           ;enable T1 irq...
	MOV     R0,#1<<6
	STRB    R0,[R12,#0x14]           ;clear any pending T1 irq

    b app_vsync_code

exitVs:
	TEQP    PC,#0b10<<26 | 0b10
	MOV     R0,R0

nottimer1orVs:
	LDMFD   R13!,{R0-R1,R11-R12}
	ldr pc, oldirqhandler

vsync_bodge:
	.long 0
.endif

; ============================================================================
; Code run at vsync.
; ============================================================================

.if !AppConfig_UseRasterMan
app_vsync_code:
	; Update the vsync counter.
	ldr r0, vsync_count
	add r0, r0, #1
	str r0, vsync_count

    .if TipsyScrollerOnVsync
    ; Do scrolltext?!
    ldr r0, app_ready
    cmp r0, #0
    beq .3
    stmfd sp!, {r2-r10}
    bl tipsy_scroller_tick
    ldr r12, screen_addr    ; write to screen to be displayed.
    bl tipsy_scroller_draw
    ldmfd sp!, {r2-r10}
    .3:
    .endif

	; Pending bank will now be displayed.
	ldr r1, pending_bank
	cmp r1, #0
	.if _CHECK_FRAME_DROP
	streq r0, last_dropped_frame
	.endif
	beq exitVs
    str r1, displayed_bank

    ldr r12, pending_screen_addr
    str r12, displayed_screen_addr

    ; Set palette for pending bank.
	mov r11, #VIDC_Write
    ldr r12, vidc_buffers_p
    add r12, r12, r1, lsl #6        ; 64 bytes per bank.
    mov r1, #16
.1:
    ldr r0, [r12], #4
    cmp r0, #-1
    beq .2
    str r0, [r11]                   ; VIDC_Write
    subs r1, r1, #1
    bne .1
.2:

	; Clear pending bank.
	mov r0, #0
	str r0, pending_bank
    b exitVs
.endif

; R0=src ptr
; R1=dst offset
; R2=bytes
app_copy_to_screen:
    ldr r3, screen_addr
    add r1, r3, r1
    mov r2, r2, lsr #2          ; #words
    b mem_copy_words

; ============================================================================
; FX code modules.
; ============================================================================

.if _DEMO_PART==_PART_TEST
.include "src/fx/sine-scroller.asm"
.endif
.if _DEMO_PART==_PART_DONUT
.include "src/fx/scene-3d.asm"
.include "src/fx/tipsy-scroller.asm"
.endif
.if _DEMO_PART==_PART_SPACE
.include "src/fx/rotate.asm"
.include "src/fx/uv-table.asm"
.endif
.if AppConfig_UseRasterMan
.include "src/rasters.asm"
.endif

; ============================================================================
; Additional library code modules used by the FX sequence.
; ============================================================================

.if _DEBUG || _CHECK_FRAME_DROP || 1
.include "lib/palette.asm"
.endif
.include "lib/screen.asm"
.if _DEMO_PART==_PART_DONUT
.include "lib/mesh.asm"
.endif

; ============================================================================
; ArchieKlang generated code.
; ============================================================================

.if AppConfig_UseArchieKlang
.include "lib/archieklang.asm"
.endif
