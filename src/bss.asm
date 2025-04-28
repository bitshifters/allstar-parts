; ============================================================================
; BSS Segment (Uninitialised data, not stored in the exe.)
; ============================================================================

.bss

; ============================================================================

.if _DEMO_PART==_PART_TEST
; fx/sine-scroller.asm
sine_wave_table_no_adr:
    .skip SineScroller_TableSize*4
.endif

; ============================================================================

.if _DEMO_PART==_PART_DONUT

; fx/scene-3d.asm
mesh_torus_verts_no_adr:
    .skip MeshTorus_NumVerts * VECTOR3_SIZE

; NB. Must follow verts!
mesh_torus_normals_no_adr:
    .skip MeshTorus_NumFaces * VECTOR3_SIZE

mesh_torus_faces_no_adr:
    .skip MeshTorus_NumFaces * 4

mesh_torus_colours_no_adr:
    .skip MeshTorus_NumFaces
.p2align 2

transformed_verts_no_adr:
    .skip OBJ_MAX_VERTS * VECTOR3_SIZE

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

;transformed_normals:       ; this is dynamic depending on num_verts.
    .skip OBJ_MAX_FACES * VECTOR3_SIZE

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

projected_verts_no_adr:
    .skip OBJ_MAX_VERTS * VECTOR2_SIZE

.endif

; ============================================================================

.if _DEMO_PART==_PART_SPACE
uv_tunnel_unrolled_code_no_adr:
    .skip UV_Tunnel_CodeSize
.endif

; ============================================================================

.if AppConfig_UseArchieKlang
Generated_Samples_no_adr:
.skip AK_SMP_LEN
.p2align 2

AK_Temp_Buffer_no_adr:
.skip AK_TempBufferSize
.endif

; ============================================================================

.p2align 2
stack_no_adr:
    .skip AppConfig_StackSize
stack_base_no_adr:

; ============================================================================
; Palette buffers.
; ============================================================================

; TODO: Check if we need VIDC buffer?
vidc_buffers_no_adr:
    .skip VideoConfig_ScreenBanks * 16 * 4

; ============================================================================
; Per FX BSS.
; ============================================================================

.if AppConfig_UseRasterMan
.p2align 2
vidc_table_1_no_adr:
	.skip 256*4*4 * 2

; TODO: Can we get rid of these?
vidc_table_2_no_adr:
	.skip 256*4*4

vidc_table_3_no_adr:
	.skip 256*8*4

memc_table_no_adr:
	.skip 256*2*4
.endif

; ============================================================================
; Library BSS (must come last)
; ============================================================================

.include "lib/lib_bss.asm"

; ============================================================================
