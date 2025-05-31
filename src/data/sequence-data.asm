; ============================================================================
; The actual sequence for the demo.
; NB. First tick of the script happens at init before music is started etc.
; ============================================================================

; TODO: Put these in separate sequence files?

; ============================================================================

.if _DEMO_PART==_PART_DONUT
.macro donut_lerp_over_secs palette_A, palette_B, secs
    math_make_var seq_palette_blend, 0.0, 1.0, math_clamp, 0.0, 1.0/(\secs*50.0)  ; seconds.
    math_make_palette seq_palette_id, \palette_A, \palette_B, seq_palette_blend, seq_palette_lerped
    write_addr raster_donut_osword_p, seq_palette_lerped
    fork_and_wait \secs*50.0-1, seq_unlink_palette_lerp
    ; NB. Subtract a frame to avoid race condition.
.endm

seq_donut_part:

    ; Init FX modules.
    call_0      scene3d_init
    call_0      rasters_donut_init
    ;                               RingRadius          CircleRadius        RingSegments   CircleSegments  MeshPtr                      Flags
    call_6      mesh_make_torus,    32.0*MATHS_CONST_1, 16.0*MATHS_CONST_1, 12,            8,              mesh_header_torus,           0x0 ; not flat inner
    call_6      mesh_make_torus,    32.0*MATHS_CONST_1, 16.0*MATHS_CONST_1, 12,            8,              mesh_header_torus_flipped,   0x2 ; flipped

    ; Reset logo palette in Vsync.
    write_addr  palette_array_p,    three_logo_pal_no_adr

    ; Show donut.
    call_3      fx_set_layer_fns,   0, scene3d_rotate_entity,         screen_cls_from_line
;    call_3      fx_set_layer_fns,   1, scene3d_move_entity_to_target, 0
    call_3      fx_set_layer_fns,   1, rasters_tick,                  0
    call_3      fx_set_layer_fns,   2, scene3d_bodge_torus_draw_order,0                 ; Must come before transform.
    call_3      fx_set_layer_fns,   3, scene3d_transform_entity,      scene3d_draw_entity_as_solid_quads

    write_vec3  torus_entity+Entity_Pos,    0.0, 0.0, 0.0
    write_vec3  object_rot_speed,           1.0, 0.0, 2.0

    ; Update a VECTOR3 using three math_funcs.
    ;math_make_vec3 torus_entity+Entity_Pos, my_func_for_x, my_func_for_y, my_func_for_z

    ; Don't move light for now.
    ;math_make_vec3 light_direction, light_func_x, light_func_y, light_func_z

    write_vec3 light_direction, 0.577, 0.577, -0.577

    wait_secs 5.0
    donut_lerp_over_secs seq_palette_red_additive, seq_palette_green_white_ramp, 5.0

    wait_secs 5.0
    write_addr raster_donut_osword_p, 0

    wait_secs 5.0
    donut_lerp_over_secs seq_palette_blue_cyan_ramp, seq_palette_green_white_ramp, 5.0

    wait_secs 5.0
    write_addr raster_donut_osword_p, 0

    wait_secs 5.0
    donut_lerp_over_secs seq_palette_green_white_ramp, seq_palette_red_magenta_ramp, 5.0

    wait_secs 5.0
    write_addr raster_donut_osword_p, 0

    wait_secs 5.0
    donut_lerp_over_secs seq_palette_red_magenta_ramp, seq_palette_red_additive, 5.0

    wait_secs 5.0
    write_addr raster_donut_osword_p, 0

    end_script

my_func_for_x:
    math_func   0.0,    40.0,      math_sin,   0.0,    1.0/(MATHS_2PI*40.0)

my_func_for_y:
    math_func   0.0,    40.0,      math_cos,   0.0,    1.0/(MATHS_2PI*30.0)

my_func_for_z:
    math_func   0.0,    26.0,      math_cos,   0.0,    1.0/(MATHS_2PI*900.0)

light_func_x:
    math_func   0.0,    1.0,       math_sin,   0.0,    1.0/(MATHS_2PI*200.0)

light_func_y:
    math_func   0.0,    1.0,       math_cos,   0.0,    1.0/(MATHS_2PI*200.0)

light_func_z:
    math_const  0.0

.endif

; ============================================================================

.if _DEMO_PART==_PART_SPACE
seq_space_part:

    ; Init FX modules.
    call_0      rotate_init

    ; UV tunnel aka UV table fx.
    call_3      fx_set_layer_fns,     0, uv_table_tick          uv_table_draw

    .if _DEBUG
    ;goto seq_space_greets
    .endif
  
    ; ================================
    ; Apollo
    ; ================================
    call_2      palette_from_gradient,gradient_grey,            seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,   1.0

    ; NB. Could just make this a table...
    call_2      uv_texture_unlz4,     uv_apollo_texture_no_adr, 16384
    call_2      unlz4,                uv_apollo_map_no_adr,     uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128

    write_fp    uv_table_fp_u,        0.0
    write_fp    uv_table_fp_v,        64.0

    wait_secs   1.0
    write_addr  palette_array_p,      seq_palette_gradient
    wait_secs   4.0

    math_make_var uv_table_fp_v,      64.0, 64.0, math_clamp, 0.0, 1.0/(4.0*50)    ; v=i/200
;    math_link_vars uv_table_fp_v,     1.0, 1.0, uv_table_fp_v   ; v'=1.0+1.0*v

    wait_secs   4.0
    palette_lerp_over_secs            seq_palette_gradient,     seq_palette_all_black,  1.0
    wait_secs   1.0
    math_kill_var uv_table_fp_v
    ; ================================

    ; ================================
    ; Ship over surface.
    ; ================================
    call_2      palette_from_gradient,gradient_ship,            seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,     1.0

    call_2      uv_texture_unlz4,     uv_ship_texture_no_adr,   8192
    call_2      unlz4,                uv_ship_map_no_adr,       uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_64

    write_fp    uv_table_fp_u,        0.0
    math_make_var seq_dv, 0.0, 1.0, math_clamp, 0.0, 1.0/(4.0*50.0)
    math_add_vars uv_table_fp_v, seq_dv, 1.0, uv_table_fp_v       ; v'=1.0+1.0*v

    wait_secs   1.0
    write_addr  palette_array_p,      seq_palette_gradient

    wait_secs   2.0
    math_make_var seq_dv, 1.0, 3.0, math_clamp, 0.0, 1.0/(4.0*50.0)
    wait_secs   6.0

    palette_lerp_over_secs            seq_palette_gradient,     seq_palette_all_black,  1.0
    wait_secs   1.0
    math_kill_var uv_table_fp_v
    math_kill_var seq_dv
    ; ================================

    ; ================================
    ; Planet, flying away from.
    ; ================================
    call_2      palette_from_gradient,gradient_space,     seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,   1.0

    call_2      uv_texture_unlz4,     uv_ship_texture_no_adr,   8192
    call_2      unlz4,                uv_planet_map_no_adr,     uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_64

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     1.0, 1.0, uv_table_fp_v   ; v'=1.0+1.0*v

    wait_secs   1.0
    write_addr  palette_array_p,      seq_palette_gradient
    wait_secs   8.0
    palette_lerp_over_secs            seq_palette_gradient,     seq_palette_all_black,  1.0
    wait_secs   1.0
    math_kill_var uv_table_fp_v
    ; ================================

    ; ================================
    ; Warp.
    ; ================================
    call_2      palette_from_gradient,gradient_sun,             seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,   1.0

    call_2      uv_texture_unlz4,     uv_warp_texture_no_adr,   2048
    call_2      unlz4,                uv_warp_map_no_adr,       uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_8_256

    write_fp    uv_table_fp_u,        0.0
    write_fp    seq_dv,               1.0
    math_add_vars uv_table_fp_v, seq_dv, 1.0, uv_table_fp_v       ; v'=1.0+1.0*v

    wait_secs   1.0
    write_addr  palette_array_p,      seq_palette_gradient

    ; Gets faster over time.
    math_make_var seq_dv, 1.0, 9.0, math_clamp, 0.0, 1.0/(8.0*50.0)
    wait_secs   8.0

    palette_lerp_over_secs            seq_palette_gradient,     seq_palette_all_black,  1.0
    wait_secs   1.0
    math_kill_var uv_table_fp_v
    math_kill_var seq_dv
    ; ================================

    ; ================================
    ; Black hole.
    ; ================================
    call_2      palette_from_gradient,gradient_black_hole,      seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,   1.0

    call_2      uv_texture_unlz4,     uv_disk_texture_no_adr,   16384
    call_2      unlz4,                uv_black_hole_map_no_adr, uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     1.0, 1.0, uv_table_fp_v   ; v'=1.0+1.0*v

    wait_secs   1.0
    write_addr  palette_array_p,      seq_palette_gradient
    wait_secs   8.0
    palette_lerp_over_secs            seq_palette_gradient,     seq_palette_all_black,  1.0
    wait_secs   1.0
    math_kill_var uv_table_fp_v
    ; ================================

    ; ================================
    ; Wormhole.
    ; ================================
    call_2      palette_from_gradient,gradient_default,         seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,   1.0

    call_2      uv_texture_unlz4,     uv_space_texture_no_adr,  16384
    call_2      unlz4,                uv_wormhole_map_no_adr,   uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     1.0, 1.0, uv_table_fp_v   ; v'=1.0+1.0*v

    wait_secs   1.0
    write_addr  palette_array_p,      seq_palette_gradient
    wait_secs   8.0
    palette_lerp_over_secs            seq_palette_gradient,     seq_palette_all_black,  1.0
    wait_secs   1.0
    math_kill_var uv_table_fp_v
    ; ================================

    ; ================================
    ; Tunnel.
    ; ================================
    call_2      palette_from_gradient,gradient_tunnel,          seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,   1.0

    call_2      uv_texture_unlz4,     uv_space_texture_no_adr,  16384
    call_2      unlz4,                uv_tunnel_map_no_adr,     uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     1.0, 1.0, uv_table_fp_v   ; v'=1.0+1.0*v

    wait_secs   1.0
    write_addr  palette_array_p,      seq_palette_gradient
    wait_secs   8.0
    palette_lerp_over_secs            seq_palette_gradient,     seq_palette_all_black,  1.0
    wait_secs   1.0
    math_kill_var uv_table_fp_v
    ; ================================

    ; ================================
    ; Trippy.
    ; ================================
    call_2      palette_from_gradient,gradient_tunnel,          seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,    1.0
    
    call_2      uv_texture_unlz4,     uv_space_texture_no_adr,  16384
    call_2      unlz4,                uv_fractal_map_no_adr,    uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    ;call_1      uv_table_init_shader, UV_Table_TexDim_128_128  ; <== inherits shader data from previous!
    call_0      uv_table_init

    call_3      fx_set_layer_fns,     0, uv_table_tick          uv_table_draw

    math_make_var uv_table_fp_u,      0.0, 1.0, 0, 0.0, -1.0
    math_make_var uv_table_fp_v,      0.0, 1.0, 0, 0.0, 1.0

    wait_secs   1.0
    call_1      palette_set_block,    seq_palette_gradient
    wait_secs   8.0
    palette_lerp_over_secs            seq_palette_gradient,      seq_palette_all_black,  1.0
    wait_secs   1.0
    math_kill_var uv_table_fp_u
    math_kill_var uv_table_fp_v
    ; ================================

    ; ================================
    ; TODO: New: More trippy effects,
    ; ================================

    ; ================================
    ; Rotate & scale.
    ; ================================
    call_2      palette_from_gradient,gradient_red_alert,       seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,   1.0

    call_2      uv_texture_unlz4,     rotate_texture_no_adr,    16384
    call_3      fx_set_layer_fns, 0,  rotate_tick,              rotate_draw

    math_make_var rotate_angle,       0.0,   1.0, 0,            0.0,    1.0    ; speed 1.0 brad / frame
    math_make_var rotate_scale,       0.1,   4.6, math_clamp,   0.0,    1.0/(50.0*9.0) ; zoom out
    
    wait_secs   1.0
    write_addr  palette_array_p,      seq_palette_gradient
    wait_secs   8.0
    ; Spinning
    palette_lerp_over_secs            seq_palette_gradient,     seq_palette_all_black,  1.0
    wait_secs   1.0

    math_kill_var rotate_scale
    math_kill_var rotate_angle

    ; Back to LUT FX
    call_3      fx_set_layer_fns,     0, uv_table_tick          uv_table_draw
    ; ================================

    ; ================================
    ; Spinning ship.
    ; ================================
    call_2      palette_from_gradient,gradient_tunnel,          seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,   1.0

    call_2      uv_texture_unlz4,     uv_space_texture_no_adr,  16384
    call_2      unlz4,                uv_spin_map_no_adr,       uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     1.0, 1.0, uv_table_fp_v   ; v'=1.0+1.0*v

    wait_secs   1.0
    write_addr  palette_array_p,      seq_palette_gradient
    wait_secs   8.0
    palette_lerp_over_secs            seq_palette_gradient,     seq_palette_all_black,  1.0
    wait_secs   1.0
    math_kill_var uv_table_fp_v
    ; ================================

    ; ================================
    ; Reactor panic.
    ; Includes palette offset.
    ; ================================

    call_2      palette_from_gradient,gradient_red_alert,       seq_palette_gradient

    ; Create a variable: offset = 3.0 + 3.0 * sin (i/50)
    math_make_var seq_panic_offset,   -4.0, 3.0, math_sin, 0.0,  1.0/50.0
    ; Link these palettes palette_copy[i]=palette_gradient[i+offset]
    call_7      math_var_register_ex, seq_panic_handle, seq_palette_gradient, 0, seq_panic_offset, seq_palette_copy, 0, math_evaluate_palette_offset
    ; Fade up from all black palette to palette_copy over seconds.
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_copy,       5.0

    call_2      uv_texture_unlz4,     uv_disk_texture_no_adr,   16384
    call_2      unlz4,                uv_reactor_panic_map_no_adr, uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     3.0, 1.0, uv_table_fp_v   ; v'=3.0+1.0*v

    wait_secs   5.0
    write_addr  palette_array_p,      seq_palette_copy

    wait_secs   4.0
    palette_lerp_over_secs            seq_palette_copy,         seq_palette_all_black,  1.0
    wait_secs   1.0

    math_kill_var seq_panic_offset
    math_kill_var seq_panic_handle
    math_kill_var uv_table_fp_v
    ; ================================

    ; ================================
    ; Spinning to stop.
    ; ================================
    call_2      palette_from_gradient,gradient_tunnel,          seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,   1.0

    call_2      uv_texture_unlz4,     uv_space_texture_no_adr,  16384
    call_2      unlz4,                uv_spin_map_no_adr,       uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128

    write_fp    uv_table_fp_u,        0.0
    math_add_vars uv_table_fp_v, seq_dv, 1.0, uv_table_fp_v       ; v'=1.0+1.0*v
    math_make_var seq_dv, 1.0, -1.0, math_clamp, 0.0, 1.0/(8.0*50.0)

    wait_secs   1.0
    write_addr  palette_array_p,      seq_palette_gradient
    wait_secs   8.0
    palette_lerp_over_secs            seq_palette_gradient,     seq_palette_all_black,  1.0
    wait_secs   1.0
    math_kill_var uv_table_fp_v
    math_kill_var seq_dv
    ; ================================

    ; ================================
    ; Reactor core.
    ; ================================
    call_2      palette_from_gradient,gradient_ship,            seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,   1.0

    call_2      uv_texture_unlz4,     uv_disk_texture_no_adr,   16384
    call_2      unlz4,                uv_reactor_ok_map_no_adr, uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     2.0, 1.0, uv_table_fp_v   ; v'=2.0+1.0*v

    wait_secs   1.0
    write_addr  palette_array_p,      seq_palette_gradient
    wait_secs   8.0
    palette_lerp_over_secs            seq_palette_gradient,     seq_palette_all_black,  1.0
    wait_secs   1.0
    math_kill_var uv_table_fp_v
    ; ================================

    ; ================================
    ; New: Space Travel II - More space travel (reusue warp again or something new),
    ; Greets
    ; ================================
seq_space_greets:
    call_2      lut_scroller_init,    nasa_font_no_adr,         seq_greets_text_no_adr
    call_3      fx_set_layer_fns,     1, lut_scroller_tick,     0

    call_2      palette_from_gradient,gradient_default,         seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,   1.0

    call_2      uv_texture_unlz4,     uv_greets_texture_no_adr, 8192
    call_2      unlz4,                uv_greets_map_no_adr,     uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_32_256

    write_fp    uv_table_fp_u,        0.0
    write_fp    seq_dv,               2.0
    math_add_vars uv_table_fp_v, seq_dv, 1.0, uv_table_fp_v       ; v'=1.0+1.0*v

    wait_secs   1.0
    write_addr  palette_array_p,      seq_palette_gradient
    wait_secs   5.0
    write_fp    seq_dv,               4.0
    wait_secs   32.0
    palette_lerp_over_secs            seq_palette_gradient,     seq_palette_all_black,  1.0
    wait_secs   1.0
    math_kill_var uv_table_fp_v
    math_kill_var seq_dv

    call_3      fx_set_layer_fns,     1, 0,                     0
    ; ================================

    ; ================================
    ; Monolith.
    ; ================================
    call_2      palette_from_gradient,gradient_default,         seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,   1.0

    call_2      uv_texture_unlz4,     uv_cloud_texture_no_adr,  16384
    call_2      unlz4,                uv_monolith_map_no_adr,   uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128

    write_fp    uv_table_fp_u,        0.0
    math_add_vars uv_table_fp_v, seq_dv, 1.0, uv_table_fp_v       ; v'=1.0+1.0*v
    math_make_var seq_dv, 0.5, -0.4, math_cos, 0.0, 1.0/(6.0*50.0)

    wait_secs   1.0
    write_addr  palette_array_p,      seq_palette_gradient
    wait_secs   8.0
    palette_lerp_over_secs            seq_palette_gradient,     seq_palette_all_black,  1.0
    wait_secs   1.0
    math_kill_var uv_table_fp_v
    math_kill_var seq_dv
    ; ================================

    ; ================================
    ; Sun.
    ; ================================
    call_2      palette_from_gradient,gradient_sun,             seq_palette_gradient
    palette_lerp_over_secs            seq_palette_all_black,    seq_palette_gradient,   1.0

    call_2      uv_texture_unlz4,     uv_ship_texture_no_adr,   8192
    call_2      unlz4,                uv_sun_map_no_adr,        uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_64

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     1.0, 1.0, uv_table_fp_v   ; v'=0.25+1.0*v

    wait_secs   1.0
    write_addr  palette_array_p,      seq_palette_gradient
    wait_secs   8.0
    palette_lerp_over_secs            seq_palette_gradient,     seq_palette_all_black,  1.0
    wait_secs   1.0
    math_kill_var uv_table_fp_v
    ; ================================

    ; ================================
    ; TODO: New : End somehow?,
    ; ================================

    yield       seq_space_part        ; yield = wait 1; goto <label>
    end_script

seq_dv:
    FLOAT_TO_FP 1.0

seq_panic_handle:
    .long 0

seq_panic_offset:
    FLOAT_TO_FP 0.0

seq_greets_text_no_adr:
    .byte "SPACE GREETS GO OUT TO... Alcatraz - Ate-Bit - AttentionWhore - "
    .byte "CRTC - DESiRE - Hooy Program - Inverse Phase - Logicoma - Loonies - "
    .byte "Proxima - Pulpo Corrosivo - Rabenauge - RiFT - Slipstream - YM Rockerz - "
    .byte "NOVA orgas - IRIS - Defekt - Epoch & Ivory - Bus Error Collective - "
    .byte "Evvvil (not a pity greet :) - TTE - Spreadpoint - SMFX"
    .byte "          "
    .byte 0 ; end.
.p2align 2
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
.endif

seq_palette_all_black:
    .rept 16
    .long 0x00000000
    .endr

.if 0
seq_palette_single_white:
    .rept 15
    .long 0x00000000
    .endr
    .long 0x00ffffff

seq_palette_all_white:
    .rept 16
    .long 0x00ffffff
    .endr
.endif

; ============================================================================
; Or use https://gradient-blaster.grahambates.com/ by Gigabates to generate nice palettes!
; ============================================================================

.if _DEMO_PART==_PART_SPACE
; https://gradient-blaster.grahambates.com/?points=000@0,022@4,58c@11,fff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_ship:
	.long 0x000,0x000,0x000,0x011,0x022,0x123,0x134,0x246
	.long 0x357,0x469,0x47a,0x58c,0x7ad,0xace,0xdef,0xfff

; https://gradient-blaster.grahambates.com/?points=000@0,022@4,cb5@11,fff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_space:
	.long 0x000,0x000,0x000,0x011,0x022,0x232,0x343,0x553
	.long 0x773,0x984,0xaa4,0xdb5,0xdc7,0xeeb,0xfed,0xfff

; https://gradient-blaster.grahambates.com/?points=000@0,012@1,435@4,944@5,eeb@10,eff@14,fff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_black_hole:
	.long 0x000,0x012,0x113,0x324,0x435,0x944,0xa65,0xc87
	.long 0xda8,0xdda,0xeeb,0xffd,0xefe,0xfff,0xeff,0xfff

; https://gradient-blaster.grahambates.com/?points=000@0,a61@8,fff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_default:
	.long 0x000,0x100,0x110,0x310,0x421,0x530,0x740,0x950
	.long 0xa61,0xb84,0xc86,0xda8,0xdb9,0xedb,0xfee,0xfff

; https://gradient-blaster.grahambates.com/?points=000@0,200@2,c00@7,fc5@11,fff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_red_alert:
	.long 0x000,0x100,0x200,0x400,0x600,0x800,0xa00,0xc00
	.long 0xd52,0xe83,0xfa4,0xfc5,0xfd8,0xfeb,0xffd,0xfff

; https://gradient-blaster.grahambates.com/?points=000@0,100@1,200@2,310@3,840@7,c86@9,e95@10,ec6@11,ffc@13,fff@14,dff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_sun:
	.long 0x000,0x100,0x200,0x310,0x410,0x520,0x730,0x840
	.long 0xa63,0xc86,0xe95,0xfc6,0xfe9,0xffc,0xfff,0xeff

; https://gradient-blaster.grahambates.com/?points=000@0,600@3,710@5,b58@8,c7d@10,ecf@12,cbf@13,c7f@14,fff@15&steps=16&blendMode=oklab&ditherMode=goldenRatioMono&target=amigaOcs&ditherAmount=40
gradient_tunnel:
	.long 0x000,0x100,0x300,0x600,0x610,0x700,0x833,0xa45
	.long 0xb58,0xc6b,0xc7d,0xeaf,0xecf,0xcbf,0xc7f,0xfff

; https://gradient-blaster.grahambates.com/?points=000@0,fff@15&steps=16&blendMode=linear&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_grey:
	.long 0x000,0x111,0x222,0x333,0x444,0x555,0x666,0x777
	.long 0x888,0x999,0xaaa,0xbbb,0xccc,0xddd,0xeee,0xfff
.endif

; ============================================================================
; Palette blending - required if using palette_lerp_over_secs macro.
; ============================================================================

.if _DEMO_PART==_PART_SPACE || _DEMO_PART==_PART_DONUT
seq_unlink_palette_lerp:
    math_kill_var seq_palette_blend
    math_kill_var seq_palette_id
    end_script

seq_palette_lerped:
    .skip 15*4
    .long 0x00ffffff

seq_palette_gradient:
    .skip 16*4

seq_palette_copy:
    .skip 16*4

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
