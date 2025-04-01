; ============================================================================
; DATA Segment.
; ============================================================================

.data
.p2align 6

; fx/sine-scroller.asm
razor_font_no_adr:
.incbin "build/razor-font.bin"              ; TODO: Remove if not used!

; ===========================================================================

; fx/scene-3d.asm
.include "src/data/three-dee/3d-meshes.asm" ; TODO: Remove what's not used!

; ===========================================================================

; fx/rotate.asm
; MODE 9 texture, 4 bpp x 2
.p2align 16
rotate_texture_no_adr:
.incbin "build/itm128.bin"               ; TODO: Build this from PNG.
.incbin "build/itm128.bin"

rotate_pal_no_adr:
.incbin "build/itmpal.bin"               ; TODO: Build this from PNG.

; ============================================================================

; fx/uv-tunnel.asm
; MODE 9 texture, 4 bpp x 2
.p2align 16
uv_phong_texture_no_adr:
.incbin "build/phong128.bin"
.incbin "build/phong128.bin"

.p2align 16
uv_cloud_texture_no_adr:
.incbin "build/cloud128.bin"
.incbin "build/cloud128.bin"

; (u,v) coordinates interleaved, 1 byte each
; 1 word = 2 pixels worth
uv_face_map_no_adr:
.incbin "build/face_uv.bin"
.incbin "build/face_uv.bin"

uv_phong_pal_no_adr:
.incbin "data/raw/phong.pal.bin"

uv_tunnel1_map_no_adr:
.incbin "build/tunnel_uv.bin"

uv_tunnel2_map_no_adr:
.incbin "build/tunnel2_uv.bin"

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
