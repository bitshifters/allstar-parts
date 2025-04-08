; ============================================================================
; Standard script macros.
; TODO: Nice detailed descriptions of how to use each MACRO.
; ============================================================================

.macro call_0 function
    .long \function
.endm

.macro call_1 function, param1
    .long script_call_1, \function, \param1
.endm

.macro call_2 function, param1, param2
    .long script_call_2, \function, \param1, \param2
.endm

.macro call_3 function, param1, param2, param3
    .long script_call_3, \function, \param1, \param2, \param3
.endm

.macro call_4 function, param1, param2, param3, param4
    .long script_call_4, \function, \param1, \param2, \param3, \param4
.endm

.macro call_5 function, param1, param2, param3, param4, param5
    .long script_call_5, \function, \param1, \param2, \param3, \param4, \param5
.endm

.macro call_6 function, param1, param2, param3, param4, param5, param6
    .long script_call_6, \function, \param1, \param2, \param3, \param4, \param5, \param6
.endm

.macro call_7 function, param1, param2, param3, param4, param5, param6, param7
    .long script_call_7, \function, \param1, \param2, \param3, \param4, \param5, \param6, \param7
.endm

.macro call_1f function, param1
    .long script_call_1, \function, MATHS_CONST_1*\param1
.endm

.macro call_2f function, param1, param2
    .long script_call_2, \function, MATHS_CONST_1*\param1, MATHS_CONST_1*\param2
.endm

.macro call_3f function, param1, param2, param3
    .long script_call_3, \function, MATHS_CONST_1*\param1, MATHS_CONST_1*\param2, MATHS_CONST_1*\param3
.endm

.macro call_4f function, param1, param2, param3, param4
    .long script_call_4, \function, MATHS_CONST_1*\param1, MATHS_CONST_1*\param2, MATHS_CONST_1*\param3, MATHS_CONST_1*\param4
.endm

.macro call_5f function, param1, param2, param3, param4, param5
    .long script_call_5, \function, MATHS_CONST_1*\param1, MATHS_CONST_1*\param2, MATHS_CONST_1*\param3, MATHS_CONST_1*\param4, MATHS_CONST_1*\param5
.endm

.macro wait frames
    .long script_wait, \frames
.endm

; TODO: wait_secs doesn't actually wait for seconds! (Resolve frames vs vsyncs.)
.macro wait_secs secs
    .long script_wait, \secs*50
.endm

.macro end_script
    .long script_return
.endm

.macro end_script_if_zero address
    .long script_return_if_zero, \address
.endm

.macro write_addr address, value
    .long script_write_addr, \address, \value
.endm

.macro write_fp address, fp_value
    write_addr \address, MATHS_CONST_1*\fp_value
.endm

.macro write_vec3 address, x, y, z
    write_addr 0+\address, MATHS_CONST_1*\x
    write_addr 4+\address, MATHS_CONST_1*\y
    write_addr 8+\address, MATHS_CONST_1*\z
.endm


; NOTE: Forked program not guaranteed to be executed on this frame as the PC
;       is inserted into the first free slot in the program list. If this is
;       before the currently running program then it won't get around until
;       next tick. This could be solved by using a linked-list of programs
;       inserted into a frame array, similar to Rose.
.macro fork program
    .long script_fork, \program
.endm

; Call subroutine (for model setup etc.) that is guaranteed to be executed
; immediately. Can only be nested one call deep as uses a Link Register;
; would need a stack to support more than this.
.macro gosub routine
    .long script_gosub, \routine
.endm

.macro fork_and_wait frames, program
    .long script_fork_and_wait, \program, \frames
.endm

.macro fork_and_wait_secs secs, program
    .long script_fork_and_wait, \program, \secs*50.0
.endm

.macro goto cont
    .long script_goto, \cont
.endm

.macro yield cont
    .long script_goto_and_wait, \cont, 1
.endm

.macro call_swi swi_no, reg0, reg1
    .long script_call_swi, \swi_no, \reg0, \reg1
.endm
