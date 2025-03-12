; ============================================================================
; Sequence helper macros.
; ============================================================================

.macro on_pattern pattern_no, do_thing
    fork_and_wait_secs SeqConfig_PatternLength_Secs*\pattern_no, \do_thing
.endm

.macro wait_patterns pats
    wait_secs SeqConfig_PatternLength_Secs*\pats
.endm

.macro palette_lerp_over_secs palette_A, palette_B, secs
    math_make_var seq_palette_blend, 0.0, 1.0, math_clamp, 0.0, 1.0/(\secs*50.0)  ; seconds.
    math_make_palette seq_palette_id, \palette_A, \palette_B, seq_palette_blend, seq_palette_lerped
    write_addr palette_array_p, seq_palette_lerped
    fork_and_wait \secs*50.0-1, seq_unlink_palette_lerp
    ; NB. Subtract a frame to avoid race condition.
.endm

.macro rgb_lerp_over_secs rgb_addr, from_rgb, to_rgb, secs
    math_make_var seq_rgb_blend, 0.0, 1.0, math_clamp, 0.0, 1.0/(\secs*50.0)  ; 5 seconds.
    math_make_rgb \rgb_addr, \from_rgb, \to_rgb, seq_rgb_blend
.endm

.macro palette_copy palette_src, palette_dst
    call_3 mem_copy_words, \palette_src, \palette_dst, 16
.endm

.macro palette_lerp_from_existing palette_B, secs
    palette_copy seq_palette_lerped, seq_palette_copy
    palette_lerp_over_secs seq_palette_copy, \palette_B, \secs
.endm


; ============================================================================
; The actual sequence for the demo.
; ============================================================================

    ; Init FX modules.
    call_0 sine_scroller_init
    call_0 scene3d_init
    ;                       RingRadius          CircleRadius       RingSegments   CircleSegments   MeshPtr              Flat inner face?
    call_6 mesh_make_torus, 32.0*MATHS_CONST_1, 8.0*MATHS_CONST_1, 4,             4,               mesh_header_torus,   1

    ; Screen setup.
;    write_addr palette_array_p, seq_palette_red_additive
    call_3 palette_set_block, 0, 0, seq_palette_standard

	; Setup layers of FX.
    .if AppConfig_UseRasterMan
    call_3 fx_set_layer_fns, 0, rasters_tick,               screen_cls
    .else
    call_3 fx_set_layer_fns, 0, 0,                          screen_cls
    .endif
    call_3 fx_set_layer_fns, 1, scene3d_rotate_entity,      scene3d_draw_entity_as_solid_quads
    ;call_3 fx_set_layer_fns, 2, sine_scroller_tick,         sine_scroller_draw

    write_vec3 object_rot_speed, 0.5, 1.25, 2.75

    ; FX params.
;    write_fp scroll_text_y_pos, 4.0 ; NB. Must match mode9-screen.asm defines. :\
;    write_addr scroller_speed, 2
;    write_fp scope_yscale 0.5
    end_script

; ============================================================================
; Support functions.
; ============================================================================

seq_unlink_palette_lerp:
    math_kill_var seq_palette_blend
    math_kill_var seq_palette_id
    end_script

; ============================================================================
; Sequence tasks can be forked and self-terminate on completion.
; Rather than have a task management system it just uses the existing script
; system and therefore supports any arbitrary sequence of fn calls.
;
;  Use 'yield <label>' to continue the script on the next frame from a given label.
;  Use 'end_script_if_zero <var>' to terminate a script conditionally.
;
; (Yes I know this is starting to head into 'real language' territory.)
;
; ==> NB. This example is now better done by using palette_lerp macros above.
; ============================================================================

.if 0
seq_test_fade_down:
    call_3 palette_init_fade, 0, 1, seq_palette_red_additive

seq_test_fade_down_loop:
    call_0 palette_update_fade_to_black
    end_script_if_zero palette_interp
    yield seq_test_fade_down_loop

seq_test_fade_up:
    call_3 palette_init_fade, 0, 1, seq_palette_red_additive

seq_test_fade_up_loop:
    call_0 palette_update_fade_from_black
    end_script_if_zero palette_interp
    yield seq_test_fade_up_loop
.endif

; ============================================================================
; Text.
; ============================================================================

; Font def, points size, point size height, text string, null terminated.
text_pool_defs_no_adr:
.if 0
    TextDef homerton_bold_italic,   76, 76*1.2, 0x1, "BITSHIFTERS",     text_nums_no_adr+0  ; 0
    TextDef corpus_bold,            90, 90*1.2, 0x1, "ALCATRAZ",        text_nums_no_adr+4  ; 1
    TextDef trinity_bold,           80, 80*1.2, 0x1, "TORMENT",         text_nums_no_adr+8  ; 2
    TextDef homerton_bold,          64, 64*1.1, 0x1, "present",         text_nums_no_adr+12 ; 3
    TextDef homerton_bold,          76, 76*1.2, 0x1, "ArchieKlang",     text_nums_no_adr+16 ; 4
    TextDef homerton_bold,          40, 48*1.1, 0x1, "code by kieran",  text_nums_no_adr+20 ; 5
    TextDef homerton_bold,          40, 48*1.1, 0x1, "samples & synth by Virgill", text_nums_no_adr+28 ; 7
    TextDef homerton_bold,          40, 48*1.1, 0x1, "music by Rhino & Virgill", text_nums_no_adr+40 ; 10
.endif
.long -1

; ============================================================================
; Sequence specific data.
; ============================================================================

.if 0
math_emitter_config_1:
    math_const 50.0/80                                                  ; emission rate=80 particles per second fixed.
    math_func  0.0,    100.0,  math_sin,  0.0,   1.0/(MATHS_2PI*60.0)   ; emitter.pos.x = 100.0 * math.sin(f/60)
    math_func  128.0,  60.0,   math_cos,  0.0,   1.0/(MATHS_2PI*80.0)   ; emitter.pos.y = 128.0 + 60.0 * math.cos(f/80)
    math_func  0.0,    2.0,    math_sin,  0.0,   1.0/(MATHS_2PI*100.0)  ; emitter.dir.x = 2.0 * math.sin(f/100)
    math_func  1.0,    5.0,    math_rand, 0.0,   0.0                    ; emitter.dir.y = 1.0 + 5.0 * math.random()
    math_const 255                                                      ; emitter.life
    math_func  0.0,    1.0,    math_and15,0.0,   1.0                    ; emitter.colour = (emitter.colour + 1) & 15
    math_func  8.0,    6.0,    math_sin,  0.0,   1.0/(MATHS_2PI*10.0)   ; emitter.radius = 8.0 + 6 * math.sin(f/10)

math_emitter_config_2:
    math_const 50.0/80                                                  ; emission rate=80 particles per second fixed.
    math_const 0.0                                                      ; emitter.pos.x = 0
    math_const 0.0                                                      ; emitter.pos.y = 192.0
    math_func -1.0,    2.0,    math_rand,  0.0,  0.0                    ; emitter.dir.x = 4.0 + 3.0 * math.random()
    math_func  1.0,    3.0,    math_rand,  0.0,  0.0                    ; emitter.dir.y = 1.0 + 5.0 * math.random()
    math_const 512                                                      ; emitter.life
    math_func  0.0,    1.0,    math_and15, 0.0,  1.0                    ; emitter.colour = (emitter.colour + 1) & 15
    math_const 8.0                                                      ; emitter.radius = 8.0
.endif

; ============================================================================
; Colour palettes.
; ============================================================================

seq_palette_standard:
    .long 0x00000000                    ; 00 = 0000 = black
    .long 0x000000f0                    ; 01 = 0001 =
    .long 0x0000f000                    ; 02 = 0010 =
    .long 0x0000f0f0                    ; 03 = 0011 =
    .long 0x00f00000                    ; 04 = 0100 =
    .long 0x00f000f0                    ; 05 = 0101 =
    .long 0x00f0f000                    ; 06 = 0110 =
    .long 0x00f0f0f0                    ; 07 = 0111 = white
    .long 0x00000080                    ; 08 = 1000 =
    .long 0x00008000                    ; 09 = 1001 =
    .long 0x00008080                    ; 10 = 1010 =
    .long 0x00800000                    ; 11 = 1011 =
    .long 0x00800080                    ; 12 = 1100 =
    .long 0x00808000                    ; 13 = 1101 =
    .long 0x00808080                    ; 14 = 1110 = dark grey
    .long 0x00c0c0c0                    ; 15 = 1111 = light grey

seq_palette_red_additive:
    .long 0x00000000                    ; 00 = 0000 = black
    .long 0x00000020                    ; 01 = 0001 =
    .long 0x00000040                    ; 02 = 0010 =
    .long 0x00000060                    ; 03 = 0011 =
    .long 0x00000080                    ; 04 = 0100 =
    .long 0x000000a0                    ; 05 = 0101 =
    .long 0x000000c0                    ; 06 = 0110 =
    .long 0x000020e0                    ; 07 = 0111 = reds
    .long 0x000040e0                    ; 08 = 1000 =
    .long 0x000060e0                    ; 09 = 1001 =
    .long 0x000080e0                    ; 10 = 1010 =
    .long 0x0000a0e0                    ; 11 = 1011 =
    .long 0x0000c0e0                    ; 12 = 1100 =
    .long 0x0000d0e0                    ; 13 = 1101 =
    .long 0x00c0e0e0                    ; 14 = 1110 = oranges
    .long 0x00f0f0f0                    ; 15 = 1111 = white

.if 1
seq_palette_grey:
    .long 0x00000000                    ; 00 = 0000 = black
    .long 0x00101010                    ; 01 = 0001 =
    .long 0x00202020                    ; 02 = 0010 =
    .long 0x00303030                    ; 03 = 0011 =
    .long 0x00404040                    ; 04 = 0100 =
    .long 0x00505050                    ; 05 = 0101 =
    .long 0x00606060                    ; 06 = 0110 =
    .long 0x00707070                    ; 07 = 0111 = reds
    .long 0x00808080                    ; 08 = 1000 =
    .long 0x00909090                    ; 09 = 1001 =
    .long 0x00a0a0a0                    ; 10 = 1010 =
    .long 0x00b0b0b0                    ; 11 = 1011 =
    .long 0x00c0c0c0                    ; 12 = 1100 =
    .long 0x00d0d0d0                    ; 13 = 1101 =
    .long 0x00e0e0e0                    ; 14 = 1110 = oranges
    .long 0x00f0f0f0                    ; 15 = 1111 = white

seq_palette_single_white:
    .rept 15
    .long 0x00000000
    .endr
    .long 0x00ffffff

seq_palette_red_yellow:
    .long 0x00000000                    ; 00 = 0000 = black
    .long 0x00001080                    ; 01 = 0001 =
    .long 0x00002080                    ; 02 = 0010 =
    .long 0x00003080                    ; 03 = 0011 =
    .long 0x00004080                    ; 04 = 0100 =
    .long 0x00005080                    ; 05 = 0101 =
    .long 0x00006080                    ; 06 = 0110 =
    .long 0x00007080                    ; 07 = 0111 = reds
    .long 0x000080a0                    ; 08 = 1000 =
    .long 0x000090b0                    ; 09 = 1001 =
    .long 0x0000a0c0                    ; 10 = 1010 =
    .long 0x0000b0d0                    ; 11 = 1011 =
    .long 0x0000c0e0                    ; 12 = 1100 =
    .long 0x0000d0f0                    ; 13 = 1101 =
    .long 0x0000e0f0                    ; 14 = 1110 = oranges
    .long 0x00f0f0f0                    ; 15 = 1111 = white

seq_palette_green_white_ramp:
    .long 0x00000000                    ; 00 = 0000 = black
    .long 0x00008000                    ; 01 = 0001 =
    .long 0x00108010                    ; 02 = 0010 =
    .long 0x00208020                    ; 03 = 0011 =
    .long 0x00308030                    ; 04 = 0100 =
    .long 0x00408040                    ; 05 = 0101 =
    .long 0x00509050                    ; 06 = 0110 =
    .long 0x0060a060                    ; 07 = 0111 = reds
    .long 0x0070b070                    ; 08 = 1000 =
    .long 0x0080c080                    ; 09 = 1001 =
    .long 0x0090d090                    ; 10 = 1010 =
    .long 0x00a0e0a0                    ; 11 = 1011 =
    .long 0x00b0e0b0                    ; 12 = 1100 =
    .long 0x00c0e0c0                    ; 13 = 1101 =
    .long 0x00d0e0d0                    ; 14 = 1110 = oranges
    .long 0x00f0f0f0                    ; 15 = 1111 = white

seq_palette_red_magenta_ramp:
    .long 0x00000000                    ; 00 = 0000 = black
    .long 0x00000080                    ; 01 = 0001 =
    .long 0x00100080                    ; 02 = 0010 =
    .long 0x00200080                    ; 03 = 0011 =
    .long 0x00300080                    ; 04 = 0100 =
    .long 0x00400080                    ; 05 = 0101 =
    .long 0x00500080                    ; 06 = 0110 =
    .long 0x00600080                    ; 07 = 0111 = reds
    .long 0x00700080                    ; 08 = 1000 =
    .long 0x00800080                    ; 09 = 1001 =
    .long 0x00900090                    ; 10 = 1010 =
    .long 0x008040a0                    ; 11 = 1011 =
    .long 0x007050b0                    ; 12 = 1100 =
    .long 0x006060c0                    ; 13 = 1101 =
    .long 0x005070d0                    ; 14 = 1110 = oranges
    .long 0x00f0f0f0                    ; 15 = 1111 = white

seq_palette_blue_cyan_ramp:
    .long 0x00000000                    ; 00 = 0000 = black
    .long 0x00a03000                    ; 01 = 0001 =
    .long 0x00a04000                    ; 02 = 0010 =
    .long 0x00a05000                    ; 03 = 0011 =
    .long 0x00a06000                    ; 04 = 0100 =
    .long 0x00b07000                    ; 05 = 0101 =
    .long 0x00b08000                    ; 06 = 0110 =
    .long 0x00c09000                    ; 07 = 0111 = reds
    .long 0x00c0a000                    ; 08 = 1000 =
    .long 0x00d0b020                    ; 09 = 1001 =
    .long 0x00d0c040                    ; 10 = 1010 =
    .long 0x00e0d060                    ; 11 = 1011 =
    .long 0x00e0e080                    ; 12 = 1100 =
    .long 0x00f0f0a0                    ; 13 = 1101 =
    .long 0x00f0f0c0                    ; 14 = 1110 = oranges
    .long 0x00f0f0f0                    ; 15 = 1111 = white

seq_palette_all_black:
    .rept 16
    .long 0x00000000
    .endr

seq_palette_all_white:
    .rept 16
    .long 0x00ffffff
    .endr
.endif

seq_palette_lerped:
    .skip 15*4
    .long 0x00ffffff

seq_palette_copy:
    .skip 16*6

; ============================================================================
; Sequence specific bss.
; ============================================================================

seq_rgb_blend:
    .long 0

seq_palette_blend:
    .long 0

seq_palette_id:
    .long 0

text_nums_no_adr:
    .skip 4*11

; ============================================================================
