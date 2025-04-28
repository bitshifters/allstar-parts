; ============================================================================
; The actual sequence for the demo.
; NB. First tick of the script happens at init before music is started etc.
; ============================================================================

; TODO: Put these in separate sequence files?

; ============================================================================

.if _DEMO_PART==_PART_DONUT
seq_donut_part:

    ; Init FX modules.
    call_0      scene3d_init
    ;                               RingRadius          CircleRadius       RingSegments   CircleSegments   MeshPtr              Flat inner face?
    call_6      mesh_make_torus,    32.0*MATHS_CONST_1, 16.0*MATHS_CONST_1, 12,            8,              mesh_header_torus,   1

    write_vec3  torus_entity+Entity_Pos,    0.0, 0.0, 0.0

    ; Show donut.
    call_1      palette_set_block,  seq_palette_red_additive

    call_3      fx_set_layer_fns,   0, scene3d_rotate_entity,         screen_cls_from_line
;    call_3      fx_set_layer_fns,   1, scene3d_move_entity_to_target, 0
    call_3      fx_set_layer_fns,   3, scene3d_transform_entity,      scene3d_draw_entity_as_solid_quads
    .if !TipsyScrollerOnVsync
    ; TODO: Remove scroller for now.
    ;call_3      fx_set_layer_fns,   2, tipsy_scroller_tick,        tipsy_scroller_draw
    .endif

;    write_vec3  object_rot_speed,           0.5, 1.3, 2.9
    write_vec3  object_rot_speed,           1.0, 0.0, 2.0

;    write_vec3  torus_entity+Entity_Pos,    0.0, 0.0, -26.0
;    math_make_var torus_entity+Entity_PosX, 0.0, 32.0, math_cos, 0.0, 0.006
;    math_make_var torus_entity+Entity_PosY, 0.0, 32.0, math_sin, 0.0, 0.004

    ; Update a VECTOR3 using three math_funcs.
    ;math_make_vec3 torus_entity+Entity_Pos, my_func_for_x, my_func_for_y, my_func_for_z

    math_make_vec3 light_direction, light_func_x, light_func_y, light_func_z

    end_script

my_func_for_x:
    math_func   0.0,    40.0,      math_sin,   0.0,    1.0/(MATHS_2PI*40.0)

my_func_for_y:
    math_func   0.0,    40.0,      math_cos,   0.0,    1.0/(MATHS_2PI*30.0)

my_func_for_z:
    math_func   0.0,    26.0,      math_cos,   0.0,    1.0/(MATHS_2PI*90.0)

light_func_x:
    math_func   0.0,    1.0,       math_sin,   0.0,    1.0/(MATHS_2PI*20.0)

light_func_y:
    math_func   0.0,    1.0,       math_cos,   0.0,    1.0/(MATHS_2PI*20.0)

light_func_z:
    math_const  0.0
.endif

; ============================================================================

.if _DEMO_PART==_PART_SPACE
seq_space_part:

    ; Init FX modules.
    call_0      rotate_init

    ; UV tunnel aka UV table fx.
    call_3      fx_set_layer_fns,   0, uv_table_tick              uv_table_draw
    call_3      fx_set_layer_fns,   1, 0,                          0
    
    ; Robot. TODO: New texture map.
    call_1      uv_texture_set_data,  uv_bgtest_texture_no_adr
    write_addr  uv_table_map_p,       uv_paul1_map_no_adr
    call_0      uv_table_init
    call_1      palette_set_block,    uv_bgtest_pal_no_adr
    write_byte  uv_table_offset_du,   0
    write_byte  uv_table_offset_dv,   1

    wait_secs   10.0

    ; Ship w/ ext data.
    call_1      uv_texture_set_data,  uv_ship_sparse_texture_no_adr
    write_addr  uv_table_map_p,       uv_paul2_map_no_adr
    call_0      uv_table_init_paul
    call_3      palette_set_gradient, 0, 0, paul_ship_gradient
    write_byte  uv_table_offset_u,    0
    write_byte  uv_table_offset_v,    0
    write_byte  uv_table_offset_du,   0
    write_byte  uv_table_offset_dv,   1

    wait_secs   10.0

    ; Inside twisty torus
    call_1      uv_texture_set_data,  uv_fire_texture_no_adr
    write_addr  uv_table_map_p,       uv_paul3_map_no_adr
    call_0      uv_table_init
    call_1      palette_set_block,    seq_palette_red_additive
    write_byte  uv_table_offset_u,    0
    write_byte  uv_table_offset_v,    0
    write_byte  uv_table_offset_du,   0
    write_byte  uv_table_offset_dv,   1

    wait_secs   10.0

    ; Planet.
    call_1      uv_texture_set_data,  uv_ship_sparse_texture_no_adr
    write_addr  uv_table_map_p,       uv_paul4_map_no_adr
    call_0      uv_table_init_paul
    call_3      palette_set_gradient, 0, 0, paul_ship_gradient
    write_byte  uv_table_offset_u,    64
    write_byte  uv_table_offset_v,    0
    write_byte  uv_table_offset_du,   0
    write_byte  uv_table_offset_dv,   1

    wait_secs   10.0

    ; Tunnel.
    call_1      uv_texture_set_data,  uv_cloud_sparse_texture_no_adr
    write_addr  uv_table_map_p,       uv_paul5_map_no_adr
    call_0      uv_table_init_paul
    call_1      palette_set_block,    seq_palette_blue_cyan_ramp
    write_byte  uv_table_offset_u,    0
    write_byte  uv_table_offset_v,    0
    write_byte  uv_table_offset_du,   0
    write_byte  uv_table_offset_dv,   1

    wait_secs   10.0

    ; Rotate & scale.
    call_1      palette_set_block,      rotate_pal_no_adr
    call_1      uv_texture_set_data,    rotate_texture_no_adr
    call_3      fx_set_layer_fns, 0,    rotate_tick,                rotate_draw

    wait_secs 10.0

    ; Inside out.
    call_1      uv_texture_set_data,  uv_phong_texture_no_adr
    write_addr  uv_table_map_p,       uv_tunnel2_map_no_adr
    call_0      uv_table_init

    call_1      palette_set_block,    uv_phong_pal_no_adr
    call_3      fx_set_layer_fns,     0, uv_table_tick              uv_table_draw
    write_byte  uv_table_offset_du,  -1
    write_byte  uv_table_offset_dv,   1

    wait_secs 10.0

    yield       seq_space_part  ; yield = wait 1; goto <label>
    end_script
.endif

; ============================================================================

.if _DEMO_PART==_PART_TEST
seq_test_part:

    ; Init FX modules.
    call_0      sine_scroller_init

    ; Screen setup.
    ; NB. Use write_addr palette_array_p, seq_palette_red_additive if setting per frame.

    ; Sine scroller.
    .if AppConfig_UseRasterMan
    call_3      fx_set_layer_fns,   0, rasters_tick,               screen_cls
    .else
    call_3      fx_set_layer_fns,   0, 0,                          screen_cls
    .endif
    call_3      fx_set_layer_fns,   2, sine_scroller_tick,         sine_scroller_draw

    end_script
.endif

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
    call_3              palette_init_fade, 0, 1, seq_palette_red_additive

seq_test_fade_down_loop:
    call_0              palette_update_fade_to_black
    end_script_if_zero  palette_interp
    yield               seq_test_fade_down_loop

seq_test_fade_up:
    call_3              palette_init_fade, 0, 1, seq_palette_red_additive

seq_test_fade_up_loop:
    call_0              palette_update_fade_from_black
    end_script_if_zero  palette_interp
    yield               seq_test_fade_up_loop
.endif

; ============================================================================
; Sequence specific data.
; ============================================================================

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

.if 0
seq_palette_single_white:
    .rept 15
    .long 0x00000000
    .endr
    .long 0x00ffffff

seq_palette_all_black:
    .rept 16
    .long 0x00000000
    .endr

seq_palette_all_white:
    .rept 16
    .long 0x00ffffff
    .endr
.endif

; ============================================================================
; Or use https://gradient-blaster.grahambates.com/ by Gigabates to generate nice palettes!
; ============================================================================

gradient_pal:
.long	0xff0,0xff3,0xfd5,0xec6,0xec7,0xeb8,0xda9,0xc9a,0xc8b,0xb7b,0xa6c,0x95d,0x84d,0x73e,0x52f,0x00f

paul_ship_gradient:
.long 	0x000,0x000,0x000,0x011,0x022,0x123,0x134,0x246,0x357,0x469,0x47a,0x58c,0x7ad,0xace,0xdef,0xfff    

paul_other_gradient:
.long 	0x000,0x100,0x110,0x310,0x421,0x530,0x740,0x950,0xa61,0xb84,0xc86,0xda8,0xdb9,0xedb,0xfee,0xfff


; ============================================================================
; Palette blending - required if using palette_lerp_over_secs macro.
; ============================================================================

.if 0
seq_unlink_palette_lerp:
    math_kill_var seq_palette_blend
    math_kill_var seq_palette_id
    end_script

seq_palette_lerped:
    .skip 15*4
    .long 0x00ffffff

seq_palette_copy:
    .skip 16*6

seq_rgb_blend:
    .long 0

seq_palette_blend:
    .long 0

seq_palette_id:
    .long 0
.endif

; ============================================================================
; Sequence specific bss.
; ============================================================================

; ============================================================================
