; ============================================================================
; Sequence helper macros.
; TODO: Nice detailed descriptions of how to use each MACRO.
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

.macro gradient_fade_up_over_secs palette_A, palette_B, secs
    ; Create a variable: offset = -15.0 + 15.0 * clamp(i/2.0*50.0) ; lerp over 2.0 secs
    math_make_var seq_palette_blend,    -15.0, 15.0, math_clamp, 0.0,  1.0/(\secs*50.0)
    ; RGB[d][i] = RGB[a][i+c]
    call_7      math_var_register_ex, seq_palette_id, \palette_B, 0, seq_palette_blend, seq_palette_lerped, 0, math_evaluate_palette_offset    
    write_addr palette_array_p, seq_palette_lerped
    ;fork_and_wait \secs*50.0-1, seq_unlink_palette_lerp
    ; NB. Subtract a frame to avoid race condition.
.endm

.macro gradient_fade_down_over_secs palette_A, palette_B, secs
    ; Create a variable: offset = -15.0 + 15.0 * clamp(i/2.0*50.0) ; lerp over 2.0 secs
    math_make_var seq_palette_blend,    0.0, -15.0, math_clamp, 0.0,  1.0/(\secs*50.0)
    ; RGB[d][i] = RGB[a][i+c]
    call_7      math_var_register_ex, seq_palette_id, \palette_A, 0, seq_palette_blend, seq_palette_lerped, 0, math_evaluate_palette_offset    
    write_addr palette_array_p, seq_palette_lerped
    ;fork_and_wait \secs*50.0-1, seq_unlink_palette_lerp
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

; Converts 8 values in 0x0RGB format (e.g. from Gradient Blaster) to 
; VIDC format = index << 26 | 0xBGR
.macro grad_to_vidc col0, col1, col2, col3, col4, col5, col6, col7
    .long 0<<26 | (\col0&0x00f)<<8 | (\col0&0x0f0) | (\col0&0xf00)>>8
    .long 1<<26 | (\col1&0x00f)<<8 | (\col1&0x0f0) | (\col1&0xf00)>>8
    .long 2<<26 | (\col2&0x00f)<<8 | (\col2&0x0f0) | (\col2&0xf00)>>8
    .long 3<<26 | (\col3&0x00f)<<8 | (\col3&0x0f0) | (\col3&0xf00)>>8
    .long 4<<26 | (\col4&0x00f)<<8 | (\col4&0x0f0) | (\col4&0xf00)>>8
    .long 5<<26 | (\col5&0x00f)<<8 | (\col5&0x0f0) | (\col5&0xf00)>>8
    .long 6<<26 | (\col6&0x00f)<<8 | (\col6&0x0f0) | (\col6&0xf00)>>8
    .long 7<<26 | (\col7&0x00f)<<8 | (\col7&0x0f0) | (\col7&0xf00)>>8
.endm
