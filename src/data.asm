; ============================================================================
; DATA Segment.
; TODO: Only include data needed for corresponding _DEMO_PART.
; ============================================================================

.data
.p2align 6

; ===========================================================================

.if _DEMO_PART==_PART_TEST
; fx/sine-scroller.asm
razor_font_no_adr:
.incbin "build/razor-font.bin"              ; TODO: Remove if not used!
.endif

; ===========================================================================

.if _DEMO_PART==_PART_DONUT
; fx/scene-3d.asm
.include "src/data/three-dee/3d-meshes.asm" ; TODO: Remove what's not used!

temp_logo_no_adr:
.incbin "build/temp-logo.bin"

fine_font_no_adr:
.incbin "build/fine-font.bin"
.endif

; ===========================================================================

.if _DEMO_PART==_PART_SPACE
; fx/rotate.asm
; MODE 9 texture, 4 bpp x 2
.p2align 16
rotate_texture_no_adr:
.incbin "build/itm128.bin"
.incbin "build/itm128.bin"

rotate_pal_no_adr:
.incbin "build/itmpal.bin"

; fx/uv-tunnel.asm
; MODE 9 texture, 4 bpp x 2
.p2align 16
uv_phong_texture_no_adr:
.incbin "build/phong128.bin"
.incbin "build/phong128.bin"

uv_phong_pal_no_adr:
.incbin "data/raw/phong.pal.bin"

; Stored as sparse bytes for extended data lookup UV FX.
.p2align 16
uv_cloud_texture_no_adr:
.incbin "build/cloud128.bin"
.incbin "build/cloud128.bin"

.p2align 16
uv_fire_texture_no_adr:
.incbin "build/fire128.bin"
.incbin "build/fire128.bin"

.p2align 16
uv_ship_texture_no_adr:
.incbin "build/ShipIndex.bin"
.incbin "build/ShipIndex.bin"
.incbin "build/ShipIndex.bin"
.incbin "build/ShipIndex.bin"

; (u,v) coordinates interleaved, 1 byte each
; 1 word = 2 pixels worth
uv_paul1_map_no_adr:
.incbin "build/paul1_uv.bin"            ; inside torus

uv_paul2_map_no_adr:
;.incbin "build/face_uv.bin"             ; Blender test
.incbin "build/paul5_uv.bin"           ; knot hit test

uv_paul5_map_no_adr:
.incbin "build/paul7_uv.bin"            ; ship w/ ext data

uv_tunnel1_map_no_adr:
.incbin "build/tunnel_uv.bin"           ; regular tunnel

uv_tunnel2_map_no_adr:
.incbin "build/tunnel2_uv.bin"          ; inside out tunnel
.endif

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

; TODO: Move MOD to Makefile.
.if _DEMO_PART==_PART_SPACE
.incbin "data/music/unused/Revision_house_06.mod"
.endif
.if _DEMO_PART==_PART_DONUT
.incbin "data/music/ne7-hammer_on.mod"
.endif
.if _DEMO_PART==_PART_TEST
.incbin "build/music.mod"
.endif

.endif
.endif
.endif

; ============================================================================
; BSS IMMEDIATELY FOLLOWS.
; ============================================================================
