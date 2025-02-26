; ============================================================================
; DATA Segment.
; ============================================================================

.data
.p2align 6

; fx/sine-scroller.asm
razor_font_no_adr:
.incbin "build/razor-font.bin"

; ============================================================================

; fx/scene-3d.asm
.include "src/data/three-dee/3d-meshes.asm"

; ============================================================================
; Library data.
; ============================================================================

.include "lib/lib_data.asm"

; ============================================================================
; QTM Embedded.
; ============================================================================

.if AppConfig_UseQtmEmbedded
.p2align 2
QtmEmbedded_Base:
.if _LOG_SAMPLES
.incbin "data/riscos/tinyQ149t2,ffa"
.else
.incbin "data/riscos/tinyQTM149,ffa"
.endif
.endif

; ============================================================================
; Sequence data (RODATA Segment - ironically).
; ============================================================================

.p2align 2
seq_main_program:
.include "src/data/sequence-data.asm"
; TODO: Reinstate dynamic load.

; ============================================================================
; Music MOD (MUST BE LAST in DATA SEGMENT).
; ============================================================================

.if AppConfig_UseArchieKlang
External_Samples_no_adr:
.incbin "data/akp/Rhino2.mod.raw"
.p2align 2

music_mod_no_adr:
.incbin "build/music.mod.trk"

.else

.if !AppConfig_LoadModFromFile

.p2align 2
music_mod_no_adr:
.if _LOG_SAMPLES
.incbin "data/music/particles_15.002"
.else

;.incbin "data/music/changing-waves.mod"
;.incbin "data/music/maze-funky-delicious.mod"
;.incbin "data/music/mikroreise.mod"    ; requires all the RAM!!
;.incbin "data/music/Revision_house_06.mod"
;.incbin "data/music/archieklang_smp_rhino2.mod"
.incbin "build/music.mod"

.endif
.endif
.endif

; ============================================================================
; BSS IMMEDIATELY FOLLOWS.
; ============================================================================
