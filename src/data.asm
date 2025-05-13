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
.incbin "build/RocketIndex.bin"

rotate_pal_no_adr:
.incbin "build/itmpal.bin"

; fx/uv-tunnel.asm
; MODE 9 texture, 4 bpp x 2
uv_phong_texture_no_adr:
.incbin "build/phong128.bin"

uv_phong_pal_no_adr:
.incbin "data/raw/phong.pal.bin"

uv_cloud_texture_no_adr:
.incbin "build/CloudIndex.bin"

uv_disk_texture_no_adr:
.incbin "build/DiskIndex.bin"

uv_space_texture_no_adr:
.incbin "build/SpaceIndex.bin"

.if 0
uv_fire_texture_no_adr:
.incbin "build/Fire2.bin"

uv_flame_texture_no_adr:
.incbin "build/FlameIndex.bin"

uv_bgtest_texture_no_adr:
.incbin "build/bgtest4.bin"

uv_bgtest_pal_no_adr:
.incbin "build/bgtest4.pal.bin"
.endif

; Stored as sparse bytes for extended data lookup UV FX.
uv_ship_texture_no_adr:
.incbin "build/ShipIndex.bin"           ; 8K
.incbin "build/ShipIndex.bin"           ; 8K

; (u,v) coordinates interleaved, 1 byte each
; 1 word = 2 pixels worth
;uv_paul1_map_no_adr:
;.incbin "build/paul1_uv.lz4"             ; robot just blue mask?

uv_ship_map_no_adr:
.incbin "build/paul2_uv.lz4"          ; ship w/ shader

;uv_paul3_map_no_adr:
;.incbin "build/paul3_uv.lz4"             ; inside twisty torus

uv_planet_map_no_adr:
.incbin "build/paul4_uv.lz4"          ; planet w/ shader

uv_tunnel_map_no_adr:
.incbin "build/paul5_uv.lz4"          ; tunnel w/ shader

uv_black_hole_map_no_adr:
.incbin "build/paul6_uv.lz4"          ; black hole w/ shader

uv_reactor_panic_map_no_adr:
.incbin "build/paul7_uv.lz4"          ; reactor panic w/ shader

uv_reactor_ok_map_no_adr:
.incbin "build/paul8_uv.lz4"          ; reactor core w/ shader

uv_monolith_map_no_adr:
.incbin "build/paul9_uv.lz4"          ; monolith w/ shader

uv_sun_map_no_adr:
.incbin "build/paul10_uv.lz4"          ; sun w/ shader

;uv_tunnel1_map_no_adr:
;.incbin "build/tunnel_uv.lz4"           ; regular tunnel

uv_inside_out_map_no_adr:
.incbin "build/tunnel2_uv.lz4"          ; inside out tunnel
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
