; ============================================================================
; 3D Scene.
; Note camera is fixed to view down +z axis.
; Does not support camera rotation / look at.
; Single 3D object per scene.
; Supports position, rotation & scale of the object within the scene.
; Used in: Chipo Django musicdisk, Three-Dee Demo (mikroreise)
; ============================================================================

.equ MeshHeader_NumVerts,       0
.equ MeshHeader_NumFaces,       4
.equ MeshHeader_VertsPtr,       8
.equ MeshHeader_NormalsPtr,     12
.equ MeshHeader_FaceIndices,    16
.equ MeshHeader_FaceColours,    20
.equ MeshHeader_SIZE,           24

.equ Entity_Pos,                0
.equ Entity_PosX,               0
.equ Entity_PosY,               4
.equ Entity_PosZ,               8
.equ Entity_Rot,                12
.equ Entity_RotX,               12
.equ Entity_RotY,               16
.equ Entity_RotZ,               20
.equ Entity_Scale,              24
.equ Entity_MeshPtr,            28
.equ Entity_SIZE,               32

; ============================================================================
; The camera viewport is assumed to be [-1,+1] across its widest axis.
; Therefore we multiply all projected coordinates by the screen width/2
; in order to map the viewport onto the entire screen.

; TODO: Could also speed this up by choosing a viewport scale as a shift, e.g. 128.
.equ VIEWPORT_SCALE,    (Screen_Width /2) * PRECISION_MULTIPLIER
.equ VIEWPORT_CENTRE_X, 160 * PRECISION_MULTIPLIER
.equ VIEWPORT_CENTRE_Y, 128 * PRECISION_MULTIPLIER

; ============================================================================
; Scene data.
; ============================================================================

; For simplicity, we assume that the camera has a FOV of 90 degrees, so the
; distance to the view plane is 'd' is the same as the viewport scale. All
; coordinates (x,y) lying on the view plane +d from the camera map 1:1 with
; screen coordinates.
;
;   h = viewport_scale / d.
;
; However as much of our maths in the scene is calculated as [8.16] maximum
; precision, having a camera distance of 160 only leaves 96 untis of depth
; to place objects within z=[0, 96] before potential problems occur.
;
; To solve this we use a smaller camera distance. d=80, giving h=160/80=2.
; This means that all vertex coordinates will be multiplied up by 2 when
; transformed to screen coordinates. E.g. the point (32,32,0) will map
; to (64,64) on the screen.
;
; This now gives us z=[0,176] to play with before any overflow errors are
; likely to occur. If this does happen, then we can further reduce the
; coordinate space and use d=40, h=4, etc.

camera_pos:
    VECTOR3 0.0, 0.0, -80.0

; ============================================================================
; Pointer to a single 3D object in the scene.
; ============================================================================

scene3d_entity_p:
    .long torus_entity

cube_entity:
    VECTOR3 0.0, 0.0, 16.0      ; object_pos
    VECTOR3 0.0, 0.0, 0.0       ; object_rot
    FLOAT_TO_FP 1.0             ; object_scale
    .long mesh_header_cube      ; mesh ptr

cobra_entity:
    VECTOR3 0.0, 0.0, 16.0      ; object_pos
    VECTOR3 0.0, 0.0, 0.0       ; object_rot
    FLOAT_TO_FP 2.0             ; object_scale
    .long mesh_header_cobra     ; mesh ptr

torus_entity:
    VECTOR3 0.0, 0.0, 0.0      ; object_pos
    VECTOR3 0.0, 0.0, 0.0       ; object_rot
    FLOAT_TO_FP 1.0             ; object_scale
    .long mesh_header_torus     ; mesh ptr

; ============================================================================
; Ptrs to buffers / tables.
; ============================================================================

.equ OBJ_MAX_VERTS, 128
.equ OBJ_MAX_FACES, 128

transformed_verts_p:
    .long transformed_verts_no_adr

transformed_normals_p:
    .long transformed_verts_no_adr

projected_verts_p:
    .long projected_verts_no_adr

scene3d_reciprocal_table_p:
    .long reciprocal_table_no_adr

scene3d_mesh_header_cache:
scene3d_mesh_numverts:
    .long 0
scene3d_mesh_numfaces:
    .long 0
scene3d_mesh_vertsptr:
    .long 0
scene3d_mesh_normalsptr:
    .long 0
scene3d_mesh_faceindices:
    .long 0
scene3d_mesh_facecolours:
    .long 0

; ============================================================================
; ============================================================================

.if _DEBUG
scene3d_stats_quads_plotted:
    .long 0
.endif

; ============================================================================
; ============================================================================

;    y
;    ^  z
;    |/
;    +--> x
;
; Radius of the ring = a
; Radius of the circle = b
; Number segments of the ring = c
; Number segments of the circle = d
; Ring segments rotate around y (aligned in x,z)
; Circle segments rotate the ring (perpendicular to x,z)
; Calculate N verts = num ring segments * num circle segments (8*16=128)
; Torus needs to be constructed from inside to outside to avoid sorting.
; Outer loop around the circle radius, starting from the centre.
; Inner loop around the ring.
; Same number of faces as verts.
; Calculate face normal as cross product.
; Or potentially as rotated normal in the loop.

.equ Torus_FlatInnerFace,   1

.equ Torus_RingRadius,      32.0
.equ Torus_CircleRadius,    8.0
.equ Torus_RingSegments,    4
.equ Torus_CircleSegments,  4

torus_ringradius:
    FLOAT_TO_FP Torus_RingRadius        ; a

torus_circleradius:
    FLOAT_TO_FP Torus_CircleRadius      ; b

torus_ringsegments:
    .long Torus_RingSegments            ; c

torus_circlesegments:
    .long Torus_CircleSegments          ; d

torus_circleradius_recip:
    .long 0                             ; 1/b

.equ MeshTorus_NumVerts, Torus_RingSegments*Torus_CircleSegments
.equ MeshTorus_NumFaces, Torus_RingSegments*Torus_CircleSegments

mesh_header_torus:
    .long  MeshTorus_NumVerts
    .long  MeshTorus_NumFaces
    .long  mesh_torus_verts_no_adr
    .long  mesh_torus_normals_no_adr
    .long  mesh_torus_faces_no_adr
    .long  mesh_torus_colours_no_adr

scene3d_make_torus:
    str lr, [sp, #-4]!

    ; Calculate all vertices.

    adr r12, mesh_header_torus
    ldr r11, [r12, #MeshHeader_VertsPtr]    ; ptr to verts
    ldr r3, [r12, #MeshHeader_NormalsPtr]   ; ptr to normals

    ; Calculate reciprocals.

    mov r0, #MATHS_CONST_1
    ldr r1, torus_ringsegments            ; d
    mov r1, r1, asl #16
    bl divide                               ; trashes R8-R10
    mov r7, r0                              ; dt = 1.0/d

    mov r0, #MATHS_CONST_1
    ldr r1, torus_circlesegments              ; c
    mov r1, r1, asl #16
    bl divide                               ; trashes R8-R10
    mov r6, r0                              ; dp = 1.0/c

    mov r0, #MATHS_CONST_1
    ldr r1, torus_circleradius              ; b
    bl divide                               ; trashes R8-R10
    mov r0, r0, asr #8
    str r0, torus_circleradius_recip        ; 1.0/b

    ; Outer ring.

    mov r10, #0                             ; theta
.1:
    ;theta = (2*PI/d) * stack [0, d]
    mov r0, r10, asl #8                     ; theta in brads
    bl sin_cos
    ; Keep precision as long as possible.
    mov r4, r0                              ; R4=sin(theta) [s1.16]
    mov r5, r1                              ; R5=cos(theta) [s1.16]

    ; Inner circle.
    
    mov r8, #0                              ; phi
.2:
    ;phi = (2*PI/c) * slice [0, c]
    sub r0, r8, #MATHS_CONST_HALF           ; start in the middle
    .if Torus_FlatInnerFace
    sub r0, r0, #MATHS_CONST_HALF/Torus_CircleSegments
    .endif
    mov r0, r0, asl #8                      ; phi in brads
    bl sin_cos
    ; R0=sin(phi) [s1.16]
    ; R1=cos(phi) [s1.16]

    ldr r14, torus_circleradius             ; b
    mov r14, r14, asr #8                    ; TODO: MicroOpt- preshift this.
    mul r2, r0, r14                         ; v.z = sin(phi) * b
    mov r2, r2, asr #8
    mul r14, r1, r14                        ; cos(phi) * b [s15.16]
    mov r14, r14, asr #8

    ldr r12, torus_ringradius               ; a
    add r14, r14, r12                       ; a + cos(phi) * b

    ; Calculate point on the circle.

    mov r14, r14, asr #8
    mul r0, r14, r5                         ; v.x = cos(theta) * (a + cos(phi) * b)
    mul r1, r14, r4                         ; v.y = sin(theta) * (a + cos(phi) * b)
    mov r0, r0, asr #8
    mov r1, r1, asr #8

    stmia r11!, {r0-r2}                     ; write {x,y,z}
    
    .if 0
    ; Calculate normal at this vertex.
    ; Not strictly the correct normal of the face.
    ; But it will do for now.

    mov r12, r12, asr #8
    
    ; Calculate centre of ring.
    mul r14, r5, r12                        ; r.x = cos(theta) * a
    mul r12, r4, r12                        ; r.y = sin(theta) * a
    ; r.z = 0.0

    ; Calculate vector from centre of ring to circle point.
    sub r0, r0, r14                         ; n.x = v.x - r.x
    sub r1, r1, r12                         ; n.y = v.y - r.y
    ;                                       ; n.z = v.z - 0.0

    mov r0, r0, asr #8
    mov r1, r1, asr #8
    mov r2, r2, asr #8

    ; Normalise this vector.
    ; The length must be the radius of the circle = b.
    ldr r14, torus_circleradius_recip       ; 1.0/b [s1.8]
    mul r0, r14, r0
    mul r1, r14, r1
    mul r2, r14, r2
    stmia r3!, {r0-r2}
    .endif

    ; Next vert in the circle.

    add r8, r8, r6                          ; phi+=dp
    cmp r8, #MATHS_CONST_1
    blt .2

    ; Next circle in the ring.

    add r10, r10, r7                          ; theta+=dt
    cmp r10, #MATHS_CONST_1
    blt .1

    ; Pre-sort the face order to avoid sorting at render time!
    ; NB. This isn't strictly possible with a fully symmetric torus.
    ; TODO: Two sort orders for use when the torus is face up/down.

    ; Calculate vertices per face.
    ; 'd' verts per ring repeated 'c' times.
    ; Each face will be made of verts:
    ;   n, (n+1) MOD d (around the circle), (n+d) MOD c (next segment of the ring), (n+d+1) MOD c
    adr r12, mesh_header_torus
    ldr r11, [r12, #MeshHeader_FaceIndices] ; face indices array [4 bytes]
    ldr r10, [r12, #MeshHeader_FaceColours] ; face colours array [1 byte]
    ldr r14, [r12, #MeshHeader_NumVerts]

    ldr r6, torus_circlesegments            ; d
    ldr r7, torus_ringsegments              ; c

    mov r4, #1                              ; colour.
    mov r12, #0                             ; circle index
.3:
    ; Alternate circle segments from inside to outside.

    mov r8, r12, lsr #1                     ; i DIV 2
    tst r12, #1 ; NE=bit set
    subne r8, r6, r8
    subne r8, r8, #1                        ; (N-1)-(i DIV 2)

    mov r5, #0                              ; let's say this is ring base (vb)
    mov r9, #0                              ; ring segment 
.4:
    ; v0 = vb + vi
    ; v1 = vb + (vi + 1) MOD d
    ; v2 = (vb + d) MOD cd + (vi + 1) MOD d
    ; v3 = (vb + d) MOD cd + vi

    add r1, r8, #1                          ; (vi + 1)
    cmp r1, r6                              ; v1 > d
    movge r1, #0                            ; (vi + 1) MOD d

    add r3, r5, r6                          ; (vb + d)
    cmp r3, r14                             ; v3 > (c*d)
    subge r3, r3, r14                       ; (vb + d) MOD cd

    add r0, r5, r8                          ; v0 = vb + vi

    add r2, r3, r1                          ; v2 = (vb + d) MOD cd + (vi + 1) MOD d
    cmp r2, r14                             ; v2 > (c*d)
    subge r2, r2, r14                       ; MOD (c*d)

    add r3, r3, r8                          ; v3 += vi
    add r1, r5, r1                          ; v1 += vb

    ; Store face indices.

    strb r0, [r11], #1
    strb r1, [r11], #1
    strb r2, [r11], #1
    strb r3, [r11], #1

    ; Store colour.
    strb r4, [r10], #1

    add r4, r4, #1
    cmp r4, #16
    movge r4, #1

    ; Next segment of the ring.
    add r5, r5, r6

    add r9, r9, #1
    cmp r9, r7
    blt .4

    ; Next colour.

    ; Next face in the circle.

    add r12, r12, #1
    cmp r12, r6
    blt .3

    ; Calculate normals.
    adr r12, mesh_header_torus
    bl scene3d_calc_mesh_normals

    ldr pc, [sp], #4

; ============================================================================

; R12 = ptr to mesh header.
; Compute normals from vertex array and mesh faces indices.
scene3d_calc_mesh_normals:
    str lr, [sp, #-4]!

    ldr r8, [r12, #MeshHeader_NumFaces]     ; number normals
    ldr r10, [r12, #MeshHeader_VertsPtr]    ; vertex array [3*4 bytes]
    ldr r11, [r12, #MeshHeader_FaceIndices] ; face indices array [4 bytes]
    ldr r12, [r12, #MeshHeader_NormalsPtr]  ; normals array [3*4 bytes]

    ; Assume R0-R7, R9 gets trashed!

    ; For each face.
.1:
    ; Use face indices to get vector A and B. [v1-v0], [v3-v0]
    ldrb r6, [r11, #0]                      ; i0
    add r7, r10, r6, lsl #3                 ; v0_ptr = vertex[i0]
    add r7, r7, r6, lsl #2
    ldmia r7, {r3-r5}                       ; v0

    ldrb r6, [r11, #3]                      ; i3
    add r9, r10, r6, lsl #3                 ; v3_ptr = vertex[i3]
    add r9, r9, r6, lsl #2
    ldmia r9, {r0-r2}                       ; v3

    ; Calculate A=v3-v0
    sub r0, r0, r3
    sub r1, r1, r4
    sub r2, r2, r5

    ldrb r6, [r11, #1]                      ; i1
    add r9, r10, r6, lsl #3                 ; v1_ptr = vertex[i1]
    add r9, r9, r6, lsl #2
    ldmia r9, {r6,r7,r9}                    ; v1

    ; Calculate B=v1-v0
    sub r3, r6, r3
    sub r4, r7, r4
    sub r5, r9, r5

    ; Calculate cross product vector.
    bl vector_cross_product
    ; [R0, R1, R2] = A ^ B

    ; Normalise cross product vector.
    bl vector_norm
    ; [R0, R1, R2] = A ^ B / |A ^ B|

    ; Store in normal array.
    stmia r12!, {r0-r2}

    ; Next face.
    add r11, r11, #4
    subs r8, r8, #1
    bne .1

    ldr pc, [sp], #4

; ============================================================================

scene3d_init:
    str lr, [sp, #-4]!
    bl scene3d_make_torus
    ldr pc, [sp], #4

; ============================================================================
; Transform the current object (not scene) into world space.
; ============================================================================

scene3d_transform_entity:
    str lr, [sp, #-4]!

    ldr r2, scene3d_entity_p
    ldr r12, [r2, #Entity_MeshPtr]
    ldr r14, [r12, #MeshHeader_NumVerts]
    ldr r3,  [r12, #MeshHeader_NumFaces]
    ldr r12, [r12, #MeshHeader_VertsPtr]

    ; TODO: Update transformed_normals_p at init.
    ldr r2, transformed_verts_p
    add r4, r2, r14, lsl #3
    add r4, r4, r14, lsl #2               ; transform_normals=&transformed_verts[object_num_verts]
    str r4, transformed_normals_p

    add r14, r14, r3                      ; object_num_verts + object_num_faces

    ; Load matrix.

    adr r0, normal_transform
    ldmia r0, {r0-r8}

    ; TODO: Pre-shift matrix elements.
    mov r0, r0, asr #MULTIPLICATION_SHIFT
    mov r1, r1, asr #MULTIPLICATION_SHIFT
    mov r2, r2, asr #MULTIPLICATION_SHIFT
    mov r3, r3, asr #MULTIPLICATION_SHIFT
    mov r4, r4, asr #MULTIPLICATION_SHIFT
    mov r5, r5, asr #MULTIPLICATION_SHIFT
    mov r6, r6, asr #MULTIPLICATION_SHIFT
    mov r7, r7, asr #MULTIPLICATION_SHIFT
    mov r8, r8, asr #MULTIPLICATION_SHIFT

    ; ASSUMES THAT VERTEX AND NORMAL ARRAYS ARE CONSECUTIVE!
    .1:
        LDMIA r12!, {r9, r10} ;x, y
    
        ; TODO: Pre-shift vector elements.
        mov r9, r9, asr #MULTIPLICATION_SHIFT
        mov r10, r10, asr #MULTIPLICATION_SHIFT

        ORR r12, r14, r12, LSL #11  ; count | src_ptr << 11 (free up r14)

        ;r0-r8 - matrix
        ;r9, r10 - x, y
        ;r11 - temp
        ;r12 - source ptr
        ;r14 - temp

        MUL r11, r9, r6   ;z=x*m20 + y*m21
        MLA r11, r10, r7, r11

        MUL r14, r10, r1  ;x = y*m01

        MUL r10, r4, r10     ;y = y*m11
        MLA r10, r3, r9, r10 ;y = x*m00 + y*m11

        MLA r9, r0, r9, r14 ;x = x*m00 + y*m01

        MOV r14, r12, LSR #11   ; extract src_ptr
        LDR r14, [r14]  ;z

        ; TODO: Pre-shift vector elements.
        mov r14, r14, asr #MULTIPLICATION_SHIFT

        ADD r12, r12, #4<<11    ; increment embeded src_ptr

        MLA r9, r2, r14, r9   ;x = x*m00 + y*m01 + z*m02
        MLA r10, r5, r14, r10 ;y = x*m01 + y*m11 + z*m12
        MLA r11, r8, r14, r11 ;z = x*m02 + y*m21 + z*m22        

        MOV r14, r12, LSL #(32-11)
        MOV r14, r14, LSR #(32-11)  ; extract count
        MOV r12, r12, LSR #11       ; extract src_ptr

        ; Sarah converts these to INTs but leave as s15.16 for now.
        ;MOV r9, r9, ASR #12         ; s7.12 after MUL
        ;MOV r10, r10, ASR #12
        ;MOV r11, r11, ASR #12
        STMFD sp!, {r9, r10, r11}   ; push on stack

        SUBS r14, r14, #1
    bne .1

    ; Pop these off the stack but write to correct position in the array.
    ldr r11, scene3d_entity_p

    ldr r12, [r11, #Entity_MeshPtr]
    ldr r10, [r12, #MeshHeader_NumFaces]

    ; Pop off normals into transformed_normals_p.
    ldr r9, transformed_normals_p
    sub r10, r10, #1
    add r9, r9, r10, lsl #3
    add r9, r9, r10, lsl #2             ; top of normals array

    .2:
    ldmfd sp!, {r0-r2}
    stmia r9, {r0-r2}
    sub r9, r9, #12
    subs r10, r10, #1
    bpl .2

    ; Transform rotated verts to world coordinates.
    ldmia r11, {r6-r8}                  ; pos vector

    ; Move everything relative to the camera.
    adr r0, camera_pos
    ldmia r0, {r0-r2}                   ; camera_pos

    sub r6, r6, r0
    sub r7, r7, r1
    sub r8, r8, r2

    ; Apply object scale after rotation.
    ldr r0, [r11, #Entity_Scale]        ; object_scale
    mov r0, r0, asr #MULTIPLICATION_SHIFT

    ldr r2, transformed_verts_p
    ldr r12, [r12, #MeshHeader_NumVerts]

    sub r12, r12, #1
    add r2, r2, r12, lsl #3
    add r2, r2, r12, lsl #2         ; top of verts array

    .3:
    ldmfd sp!, {r3-r5}

    ; Scale rotated verts.
    mov r3, r3, asr #MULTIPLICATION_SHIFT
    mov r4, r4, asr #MULTIPLICATION_SHIFT
    mov r5, r5, asr #MULTIPLICATION_SHIFT

    mul r3, r0, r3      ; x_scaled=x*object_scale
    mul r4, r0, r4      ; y_scaled=y*object_scale
    mul r5, r0, r5      ; z_scaled=z*object_scale

    ; Move object vertices into world space.
    add r3, r3, r6      ; x_scaled + object_pos_x - camera_pos_x
    add r4, r4, r7      ; y_scaled + object_pos_y - camera_pos_y
    add r5, r5, r8      ; z_scaled + object_pos_z - camera_pos_z

    stmia r2, {r3-r5}
    sub r2, r2, #12

    subs r12, r12, #1
    bpl .3

    ldr pc, [sp], #4


; ============================================================================
; Rotate the current object from either vars or VU bars.
; ============================================================================

object_rot_speed:
    VECTOR3 0.5, 0.0, 0.0

object_transform:           ; Inc. scale, no translate.
    MATRIX33_IDENTITY

normal_transform:           ; Rotation only.
    MATRIX33_IDENTITY

temp_matrix_1:
    MATRIX33_IDENTITY

temp_matrix_2:
    MATRIX33_IDENTITY

scene3d_rotate_entity:
    str lr, [sp, #-4]!

    ; Create rotation matrix as object transform.
    ldr r10, scene3d_entity_p

    ; TODO: Make rotation matrix directly.
    adr r2, temp_matrix_1
    ldr r0, [r10, #Entity_RotX]
    bl matrix_make_rotate_x     ; T1=rot_x

    adr r2, object_transform
    ldr r0, [r10, #Entity_RotY]
    bl matrix_make_rotate_y     ; OT=rot_y

    adr r0, temp_matrix_1
    adr r1, object_transform
    adr r2, temp_matrix_2
    bl matrix_multiply          ; T2=T1.OT

    adr r2, temp_matrix_1
    ldr r0, [r10, #Entity_RotZ]
    bl matrix_make_rotate_z     ; T1=rot_z

    adr r0, temp_matrix_2
    adr r1, temp_matrix_1
    adr r2, normal_transform    ; NT=T2.T1  <== rotation only.
    bl matrix_multiply

.if 0
    ldr r0, [r10, #Entity_Scale]
    adr r2, temp_matrix_2
    bl matrix_make_scale        ; T2=scale

    adr r0, temp_matrix_2
    adr r1, normal_transform
    adr r2, object_transform    ; OT=T2.NT
    bl matrix_multiply
.endif

    ; Transform the object into world space.
    bl scene3d_transform_entity

    ; Update any scene vars, camera, object position etc. (Rocket?)
    ldr r10, scene3d_entity_p

    ldr r1, object_rot_speed + 0 ; ROTATION_X
    ldr r0, [r10, #Entity_RotX]
    add r0, r0, r1
    bic r0, r0, #0xff000000         ; brads
    str r0, [r10, #Entity_RotX]

    ldr r1, object_rot_speed + 4 ; ROTATION_Y
    ldr r0, [r10, #Entity_RotY]
    add r0, r0, r1
    bic r0, r0, #0xff000000         ; brads
    str r0, [r10, #Entity_RotY]

    ldr r1, object_rot_speed + 8 ; ROTATION_Z
    ldr r0, [r10, #Entity_RotZ]
    add r0, r0, r1
    bic r0, r0, #0xff000000         ; brads
    str r0, [r10, #Entity_RotZ]

    ldr pc, [sp], #4

scene3d_update_entity_from_vubars:
    str lr, [sp, #-4]!

	mov r0, #0
	QTMSWI QTM_ReadVULevels

    ldr r2, scene3d_entity_p

	; R0 = word containing 1 byte per channel 1-4 VU bar heights 0-64
  	mov r10, r0, lsr #24            ; channel 4 = scale
	ands r10, r10, #0xff
    bne .1
    ldr r1, [r2, #Entity_Scale]     ; object_scale
    cmp r1, #MATHS_CONST_HALF
    subgt r1, r1, #MATHS_CONST_1*0.01
    b .2
    
    .1:
    mov r1, #MATHS_CONST_1
    add r1, r1, r10, asl #10         ; scale maps [1, 2]
    .2:
    str r1, [r2, #Entity_Scale]

    ; TODO: Make this code more compact?

  	mov r10, r0, lsr #8             ; channel 2 = inc_x
	and r10, r10, #0xff
    mov r10, r10, asl #11           ; inc_x maps [0, 2]
    ldr r1, [r2, #Entity_RotX]
    add r1, r1, r10                 ; object_rot_x += inc_x
    str r1, [r2, #Entity_RotX]

  	mov r10, r0, lsr #16            ; channel 3 = inc_y
	and r10, r10, #0xff
    mov r10, r10, asl #11           ; inc_y maps [0, 2]
    ldr r1, [r2, #Entity_RotY]
    add r1, r1, r10                 ; object_rot_y += inc_y
    str r1, [r2, #Entity_RotY]

    and r10, r0, #0xff              ; channel 1 = inc_z
    mov r10, r10, asl #11           ; inc_z maps [0, 2]
    ldr r1, [r2, #Entity_RotZ]
    add r1, r1, r10                 ; object_rot_z += inc_z
    str r1, [r2, #Entity_RotZ]

    ; Transform the object into world space.
    bl scene3d_transform_entity
    ldr pc, [sp], #4

; ============================================================================
; Project the transformed vertex array into screen space.
; ============================================================================

scene3d_project_verts:
    ; Project vertices to screen.
    ldr r2, transformed_verts_p
    ldr r9, scene3d_reciprocal_table_p

    ldr r1, scene3d_mesh_numverts       ; from cache.
    ldr r10, projected_verts_p
    .1:
    ; R2=ptr to world pos vector
    ; bl project_to_screen

    ; Load camera relative transformed verts [R3,R5,R5] = [x,y,z]
    ldmia r2!, {r3-r5}

    ; Project to screen.

    ; Put divisor in table range.
    mov r5, r5, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (b<<s)

    .if _DEBUG
    cmp r5, #0
    bgt .2
    adrle r0,errbehindcamera    ; and flag an error
    swile OS_GenerateError      ; when necessary
    .2:
    ; TODO: Probably just cull these objects?

    ; Limited precision.
    cmp r5, #1<<LibDivide_Reciprocal_t    ; Test for numerator too large
    adrge r0,divrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

    ; Lookup 1/z.
    ldr r5, [r9, r5, lsl #2]    ; [0.16]    (1<<16+s)/(b<<s) = (1<<16)/b

    ; x/z
    mov r3, r3, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (a<<s)
    mul r3, r5, r3                      ; [10.22]   (a<<s)*(1<<16)/b = (a<<16+s)/b
    mov r3, r3, asr #LibDivide_Reciprocal_s       ; [10.16]   (a<<16)/b = (a/b)<<16

    ; y/z
    mov r4, r4, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (a<<s)
    mul r4, r5, r4                      ; [10.22]   (a<<s)*(1<<16)/b = (a<<16+s)/b
    mov r4, r4, asr #LibDivide_Reciprocal_s       ; [10.16]   (a<<16)/b = (a/b)<<16

    ; screen_x = vp_centre_x + vp_scale * (x-cx) / (z-cz)
    mov r0, #VIEWPORT_SCALE>>12 ; [16.4]
    mul r3, r0, r3              ; [12.20]
    mov r3, r3, asr #4           ; [12.16]
    mov r0, #VIEWPORT_CENTRE_X  ; [16.16]
    add r3, r3, r0

    ; screen_y = vp_centre_y - vp_scale * (y-cy) / (z-cz)
    mov r0, #VIEWPORT_SCALE>>12 ; [16.4]
    mul r4, r0, r4              ; [12.20]
    mov r4, r4, asr #4           ; [12.16]
    mov r0, #VIEWPORT_CENTRE_Y  ; [16.16]
    sub r4, r0, r4              ; [16.16]

    ; R0=screen_x, R1=screen_y [16.16]
    mov r3, r3, asr #16         ; [16.0]
    mov r4, r4, asr #16         ; [16.0]

    stmia r10!, {r3, r4}
    subs r1, r1, #1
    bne .1

    mov pc, lr

; ============================================================================
; Draw the current object (not scene) using solid filled quads.
; ============================================================================

; R12=screen addr
scene3d_draw_entity_as_solid_quads:
    str lr, [sp, #-4]!

    .if _DEBUG
    mov r0, #0
    str r0, scene3d_stats_quads_plotted
    .endif

    ; Cache the screen address in the triangle plotter.

    bl triangle_prepare

    ; Cache the mesh header whilst drawing this object.

    ldr r11, scene3d_entity_p
    ldr r11, [r11, #Entity_MeshPtr]     ; scene3d_mesh_p
    adr r10, scene3d_mesh_header_cache
    ldmia r11, {r0-r5}
    stmia r10, {r0-r5}
    .if MeshHeader_SIZE!=24
    .err "Was expecting MeshHeader_SIZE == 24!"
    .endif

    ; Project world space verts to screen space.
    bl scene3d_project_verts
 
    ; Plot faces as polys.
    ldr r11, scene3d_mesh_numfaces      ; from cache.
    strb r11, .4                        ; SELF-MOD! ;sub r11, r11, #1
    mov r11, #0                         ; now plot faces in forward order.

    .2:

    ; TODO: MicroOpt- faces now in order so can just increment r9 face v0.

    ldr r9, scene3d_mesh_faceindices    ; from cache.
    ldrb r5, [r9, r11, lsl #2]          ; vertex0 of polygon N.
    
    ldr r1, transformed_verts_p
    add r1, r1, r5, lsl #3
    add r1, r1, r5, lsl #2              ; transformed_verts + index*12

    ; TODO: MicroOpt- faces now in order so can just increment r2 normal ptr.

    ldr r2, transformed_normals_p
    add r2, r2, r11, lsl #3             ; face_normal for polygon N.
    add r2, r2, r11, lsl #2             ; face_normal for polygon N.

    ; Backfacing culling test (vertex - camera_pos).face_normal
    ; Parameters:
    ;  R1=ptr to transformed vertex in camera relative space
    ;  R2=ptr to face normal vector
    ; Return:
    ;  R0=dot product of (v0-cp).n
    ; Trashes: r3-r8
    ; vector A = (v0 - camera_pos)
    ; vector B = face_normal

    ldmia r1!, {r3-r5}                  ; [tx, ty, tz]
    ldmia r2,  {r6-r8}                  ; [s15.16]

    ; TODO: MicroOpt- pre-shift all verts to be MUL ready

    mov r3, r3, asr #MULTIPLICATION_SHIFT    ; [s15.8]
    mov r4, r4, asr #MULTIPLICATION_SHIFT    ; [s15.8]
    mov r5, r5, asr #MULTIPLICATION_SHIFT    ; [s15.8]
    mov r6, r6, asr #MULTIPLICATION_SHIFT    ; [s15.8]
    mov r7, r7, asr #MULTIPLICATION_SHIFT    ; [s15.8]
    mov r8, r8, asr #MULTIPLICATION_SHIFT    ; [s15.8]

    mul r0, r3, r6                      ; r0 = a1 * b1  [s30.16] potential overflow
    mla r0, r4, r7, r0                  ;   += a2 * b2  [s30.16] potential overflow
    mlas r0, r5, r8, r0                 ;   += a3 * b3  [s30.16] potential overflow
    bpl .3                              ; normal facing away from the view direction.

    ; TODO: MicroOpt- use winding order test rather than dot product if no lighting calc.

    ; TODO: Screen space winding order test:
    ;       (y1 - y0) * (x2 - x1) - (x1 - x0) * (y2 - y1) > 0

    ; TODO: MicroOpt- avoid reading quad indices again.

    ; SOLID
    ldr r2, projected_verts_p   ; projected vertex array.
    ldr r3, [r9, r11, lsl #2]   ; quad indices.

    ; TODO: MicroOpt - avoid stashing registers?

    stmfd sp!, {r11}

    ; TODO: MicroOpt- faces now in order so can just increment r4 colour ptr.

    ; Look up colour index per face (no lighting).
    ldr r4, scene3d_mesh_facecolours    ; from cache.
    ldrb r4, [r4, r11]

    ;  R12=screen addr
    ;  R2=ptr to projected vertex array (x,y) in screen coords [16.0]
    ;  R3=4x vertex indices for quad
    ;  R4=colour index
    bl triangle_plot_quad_indexed   ; faster than polygon_plot_quad_indexed.
    ; Trashes: R0-R11.

    .if _DEBUG
    ldr r11, scene3d_stats_quads_plotted
    add r11, r11, #1
    str r11, scene3d_stats_quads_plotted
    .endif

    ldmfd sp!, {r11}

    .3:
    add r11, r11, #1
    .4:
    cmp r11, #0
    blt .2

    ldr pc, [sp], #4

; ============================================================================
; ============================================================================

; Project world position to screen coordinates.
; TODO: Try weak perspective model, i.e. a single distance for all vertices in the objects.
;       Means that we can calculate the reciprocal once (1/z) and use the same value in
;       all perspective calculations. Suspect this is what most Amiga & ST demos do...
;
; R2=ptr to camera relative transformed position
; Returns:
;  R0=screen x
;  R1=screen y
; Trashes: R3-R6,R8-R10
.if 0
project_to_screen:
    str lr, [sp, #-4]!

    ; Vertex already transformed and camera relative.
    ldmia r2, {r3-r5}           ; (x,y,z)

    ; vp_centre_x + vp_scale * (x-cx) / (z-cz)
    mov r0, r3                  ; (x-cx)
    mov r1, r5                  ; (z-cz)
    ; Trashes R8-R10!
    bl divide                   ; (x-cx)/(z-cz)
                                ; [0.16]

    mov r8, #VIEWPORT_SCALE>>12 ; [16.4]
    mul r6, r0, r8              ; [12.20]
    mov r6, r6, asr #4          ; [12.16]
    mov r8, #VIEWPORT_CENTRE_X  ; [16.16]
    add r6, r6, r8

    ; Flip Y axis as we want +ve Y to point up the screen!
    ; vp_centre_y - vp_scale * (y-cy) / (z-cz)
    mov r0, r4                  ; (y-cy)
    mov r1, r5                  ; (z-cz)
    ; Trashes R8-R10!
    bl divide                   ; (y-cy)/(z-cz)
                                ; [0.16]
    mov r8, #VIEWPORT_SCALE>>12 ; [16.4]
    mul r1, r0, r8              ; [12.20]
    mov r1, r1, asr #4          ; [12.16]
    mov r8, #VIEWPORT_CENTRE_Y  ; [16.16]
    sub r1, r8, r1              ; [16.16]

    mov r0, r6
    ldr pc, [sp], #4
.endif

; ============================================================================
; ============================================================================

.if _DEBUG
    errbehindcamera: ;The error block
    .long 0
	.byte "Vertex behind camera."
	.align 4
	.long 0
.endif

; ============================================================================
; ============================================================================

.if 0
scene3d_transform_entity:
    str lr, [sp, #-4]!

    ; TODO: Replace this guff with Sarah's 3x3 matmul routine.

    ; Skip matrix multiplication altogether.
    ; Transform (x,y,z) into (x'',y'',z'') directly.
    ; Uses 12 muls / rotation.

    ldr r2, scene3d_entity_p
    ldr r0, [r2, #Entity_RotZ]              ; object_rot+8
    bl sin_cos                              ; trashes R9
    mov r10, r0, asr #MULTIPLICATION_SHIFT  ; r10 = sin(A)
    mov r11, r1, asr #MULTIPLICATION_SHIFT  ; r11 = cos(A)

    ldr r0, [r2, #Entity_RotX]              ; object_rot+0
    bl sin_cos                              ; trashes R9
    mov r6, r0, asr #MULTIPLICATION_SHIFT  ; r6 = sin(C)
    mov r7, r1, asr #MULTIPLICATION_SHIFT  ; r7 = cos(C)

    ldr r0, [r2, #Entity_RotY]              ; object_rot+4
    bl sin_cos                              ; trashes R9
    mov r8, r0, asr #MULTIPLICATION_SHIFT  ; r8 = sin(B)
    mov r9, r1, asr #MULTIPLICATION_SHIFT  ; r9 = cos(B)

    ldr r12, [r2, #Entity_MeshPtr]
    ldr r1, [r12, #MeshHeader_VertsPtr]
    ldr r3, [r12, #MeshHeader_NumFaces]
    ldr r12, [r12, #MeshHeader_NumVerts]

    ldr r2, transformed_verts_p
    add r4, r2, r12, lsl #3
    add r4, r4, r12, lsl #2               ; transform_normals=&transformed_verts[object_num_verts]
    str r4, transformed_normals_p

    add r12, r12, r3                      ; object_num_verts + object_num_faces

    ; ASSUMES THAT VERTEX AND NORMAL ARRAYS ARE CONSECUTIVE!
    .1:
    ldmia r1!, {r3-r5}                    ; x,y,z
    mov r3, r3, asr #MULTIPLICATION_SHIFT
    mov r4, r4, asr #MULTIPLICATION_SHIFT
    mov r5, r5, asr #MULTIPLICATION_SHIFT

	; x'  = x*cos(A) + y*sin(A)
	; y'  = x*sin(A) - y*cos(A)  
    mul r0, r3, r11                     ; x*cos(A)
    mla r0, r4, r10, r0                 ; x' = y*sin(A) + x*cos(A)
    mov r0, r0, asr #MULTIPLICATION_SHIFT

    mul r14, r4, r11                    ; y*cos(A)
    rsb r14, r14, #0                    ; -y*cos(A)
    mla r4, r3, r10, r14                ; y' = x*sin(A) - y*cos(A)
    mov r4, r4, asr #MULTIPLICATION_SHIFT

	; x'' = x'*cos(B) + z*sin(B)
	; z'  = x'*sin(B) - z*cos(B)

    mul r14, r0, r9                     ; x'*cos(B)
    mla r3, r5, r8, r14                 ; x'' = z*sin(B) + x'*cos(B)

    mul r14, r5, r9                     ; z*cos(B)
    rsb r14, r14, #0                    ; -z*cos(B)
    mla r5, r0, r8, r14                 ; z' = x'*sin(B) - z*cos(B)
    mov r5, r5, asr #MULTIPLICATION_SHIFT

	; y'' = y'*cos(C) + z'*sin(C)
	; z'' = y'*sin(C) - z'*cos(C)

    mul r14, r4, r7                     ; y'*cos(C)
    mla r0, r5, r6, r14                 ; y'' = y'*cos(C) + z'*sin(C)

    mul r14, r5, r7                     ; z'*cos(C)
    rsb r14, r14, #0                    ; -z'*cos(C)
    mla r5, r4, r6, r14                 ; z'' = y'*sin(C) - z'*cos(C)

    ; x''=r3, y''=r0, z''=r5
    mov r4, r0
    stmia r2!, {r3-r5}                  ; x'',y'',z'''
    subs r12, r12, #1
    bne .1

    ; Transform to world coordinates.
    ldr r11, scene3d_entity_p
    ldmia r11, {r6-r8}                  ; pos vector

    ; NB. No longer transformed to camera relative.

    ; Apply object scale after rotation.
    ldr r0, [r11, #Entity_Scale]        ; object_scale
    mov r0, r0, asr #MULTIPLICATION_SHIFT

    ldr r2, transformed_verts_p
    ldr r12, [r11, #Entity_MeshPtr]     ; scene3d_mesh_p
    ldr r12, [r12, #MeshHeader_NumVerts]
    .2:
    ldmia r2, {r3-r5}

    ; Scale rotated verts.
    mov r3, r3, asr #MULTIPLICATION_SHIFT
    mov r4, r4, asr #MULTIPLICATION_SHIFT
    mov r5, r5, asr #MULTIPLICATION_SHIFT

    mul r3, r0, r3      ; x_scaled=x*object_scale
    mul r4, r0, r4      ; y_scaled=y*object_scale
    mul r5, r0, r5      ; z_scaled=z*object_scale

    ; TODO: Make camera relative again for speed?

    ; Move object vertices into world space.
    add r3, r3, r6      ; x_scaled + object_pos_x - camera_pos_x
    add r4, r4, r7      ; y_scaled + object_pos_y - camera_pos_y
    add r5, r5, r8      ; z_scaled + object_pos_z - camera_pos_z

    stmia r2!, {r3-r5}
    subs r12, r12, #1
    bne .2

    ldr pc, [sp], #4
.endif
