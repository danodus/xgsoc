// program.c
// Copyright (c) 2023-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

#include <stdint.h>
#include <graphite.h>
#include <cube.h>
#include <teapot.h>
#include <stdlib.h>
#include <stdio.h>
#include <io.h>

#define BASE_VIDEO 0x1000000

#define TEXTURE_WIDTH 32
#define TEXTURE_HEIGHT 32

#define OP_SET_V0_X 0
#define OP_SET_V0_Y 1
#define OP_SET_V1_X 2
#define OP_SET_V1_Y 3
#define OP_SET_V2_X 4
#define OP_SET_V2_Y 5
#define OP_SET_START_W_INV 6
#define OP_SET_START_S 7
#define OP_SET_START_T 8
#define OP_SET_START_R 9
#define OP_SET_START_G 10
#define OP_SET_START_B 11
#define OP_SET_DW_DX 12
#define OP_SET_DW_DY 13
#define OP_SET_DS_DX 14
#define OP_SET_DS_DY 15
#define OP_SET_DT_DX 16
#define OP_SET_DT_DY 17
#define OP_SET_DR_DX 18
#define OP_SET_DR_DY 19
#define OP_SET_DG_DX 20
#define OP_SET_DG_DY 21
#define OP_SET_DB_DX 22
#define OP_SET_DB_DY 23
#define OP_CLEAR 24
#define OP_DRAW 25
#define OP_SWAP 26
#define OP_SET_TEX_ADDR 27
#define OP_SET_FB_ADDR 28
#define OP_SET_START_Q 29
#define OP_SET_DQ_DX 30
#define OP_SET_DQ_DY 31

uint16_t shadow_fb[320 * 240 * 3] __attribute__((aligned(4)));

#define MEM_WRITE(_addr_, _value_) (*((volatile unsigned int *)(_addr_)) = _value_)
#define MEM_READ(_addr_) *((volatile unsigned int *)(_addr_))

#define PARAM(x) (x)

struct Command {
    uint32_t opcode : 8;
    uint32_t param : 24;
};

typedef int32_t fixed16;
#define TO_FIXED(x)          ((fixed16)std::round((x) * 65536.0f))
#define INT_TO_FIXED(x)      ((fixed16)((x) << 16))
#define FIXED_TO_INT(x)      ((int32_t)((x) >> 16))
#define FIXED_MUL(a, b)      MUL(a, b)
#define FIXED_DIV(a, b)      ((fixed16)(((int64_t)(a) << 16) / (b)))
#define FIXED_CEIL_HALF(x)   (((x) + 0x7FFF) >> 16)

typedef struct {
    int16_t x, y; // 12.4 fixed-point format
    fx32 w; 
    fx32 s, t, q;
    fx32 r, g, b; 
} Vertex2;

static inline int16_t min3(int16_t a, int16_t b, int16_t c) {
    int16_t m = a; if (b < m) m = b; if (c < m) m = c; return m;
}

static inline int16_t max3(int16_t a, int16_t b, int16_t c) {
    int16_t m = a; if (b > m) m = b; if (c > m) m = c; return m;
}

int fb_width, fb_height;

extern uint16_t tex32x32[];
extern uint16_t tex64x64[];

int nb_triangles;
bool rasterizer_ena = true;

uint32_t t_tri_setup, t_tri_raster;

void send_command(struct Command *cmd)
{
    while (!MEM_READ(GRAPHITE));
    MEM_WRITE(GRAPHITE, (cmd->opcode << 24) | cmd->param);
}

static void push_16(uint32_t op, int32_t val) {
    struct Command cmd;
    cmd.opcode = op;
    cmd.param = val & 0xFFFF;
    send_command(&cmd);
}

static void push_32(uint32_t op, int32_t val) {
    struct Command cmd;
    cmd.opcode = op;
    cmd.param = val & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | ((val >> 16) & 0xFFFF);
    send_command(&cmd);
}

#define FAST_MUL32(a_16, b) MUL((a_16) << 16, b)

static inline int64_t mul_32x16_64(int32_t a, int32_t b_16) {
    int32_t mid = MUL(a, b_16);
    int32_t low = MUL(a, b_16 << 16);
    return ((int64_t)mid << 16) | (low & 0xFFFF);
}

static inline int64_t mul_shr4(int32_t a_16, int64_t b) {
    if (b < 2147483648LL && b >= -2147483648LL) {
        int64_t prod = mul_32x16_64((int32_t)b, a_16);
        return prod >> 4;
    }
    return (int64_t)a_16 * (b >> 4) + (((int64_t)a_16 * (b & 15)) >> 4);
}

static inline int64_t solve_gradient_fast(int64_t det, int32_t inv_det_23, int shift, int32_t termA, int32_t factorA, int32_t termB, int32_t factorB) {
    int64_t num = mul_32x16_64(termA, factorA) - mul_32x16_64(termB, factorB); 
    int64_t num_abs = num < 0 ? -num : num;

    // Tier 1: Fast path using 64-bit multiplication (0 divisions)
    // 23-bit reciprocal guarantees perfectly safe 64-bit multiplication up to 40-bit num.
    if (num_abs < (1LL << 40)) {
        int64_t prod_64 = num * inv_det_23;
        return prod_64 >> (33 - shift);
    }
    
    // Tier 2: Single 64-bit division
    if (num_abs < (1LL << 43)) {
        return (num << 20) / det;
    }

    // Tier 3: Safe fallback to prevent overflow
    return (num / det) * 1048576LL + ((num % det) * 1048576LL) / det;
}

bool enable_shadow_map = false;

void xd_draw_triangle(vec3d p[3], vec2d t[3], vec3d c[3], fx32 q[3], texture_t* tex, bool clamp_s, bool clamp_t, int texture_scale_x, int texture_scale_y,
                      bool depth_test, bool perspective_correct)                      
{
    nb_triangles++;
    if (!rasterizer_ena)
        return;

    uint32_t t1_tri_setup = MEM_READ(TIMER);

    uint32_t texture_width = 32 << texture_scale_x;
    uint32_t texture_height = 32 << texture_scale_y;

    Vertex2 v0, v1, v2;
    v0.x = p[0].x >> 12; v0.y = p[0].y >> 12; v0.w = t[0].w; v0.s = MUL(t[0].u, FXI(texture_width)); v0.t = MUL(t[0].v, FXI(texture_height)); v0.q = q[0]; v0.r = MUL(c[0].x, FXI(255)); v0.g = MUL(c[0].y, FXI(255)); v0.b = MUL(c[0].z, FXI(255));
    v1.x = p[1].x >> 12; v1.y = p[1].y >> 12; v1.w = t[1].w; v1.s = MUL(t[1].u, FXI(texture_width)); v1.t = MUL(t[1].v, FXI(texture_height)); v1.q = q[1]; v1.r = MUL(c[1].x, FXI(255)); v1.g = MUL(c[1].y, FXI(255)); v1.b = MUL(c[1].z, FXI(255));
    v2.x = p[2].x >> 12; v2.y = p[2].y >> 12; v2.w = t[2].w; v2.s = MUL(t[2].u, FXI(texture_width)); v2.t = MUL(t[2].v, FXI(texture_height)); v2.q = q[2]; v2.r = MUL(c[2].x, FXI(255)); v2.g = MUL(c[2].y, FXI(255)); v2.b = MUL(c[2].z, FXI(255));

    // Sort vertices by Y coordinate
    if (v0.y > v1.y) { Vertex2 t = v0; v0 = v1; v1 = t; }
    if (v0.y > v2.y) { Vertex2 t = v0; v0 = v2; v2 = t; }
    if (v1.y > v2.y) { Vertex2 t = v1; v1 = v2; v2 = t; }

    int32_t dx1 = v1.x - v0.x; int32_t dy1 = v1.y - v0.y;
    int32_t dx2 = v2.x - v0.x; int32_t dy2 = v2.y - v0.y;
    int64_t det = mul_32x16_64(dx1, dy2) - mul_32x16_64(dy1, dx2); // 24.8 format
    if (det == 0) return; 

    // Compute fast reciprocal for gradients
    int32_t det32 = (int32_t)det;
    int32_t abs_det = det32 < 0 ? -det32 : det32;
    int lz = __builtin_clz(abs_det);
    int shift = lz - 1; 
    uint32_t norm_det = abs_det << shift;
    int32_t inv_det_23 = (int32_t)((1LL << 53) / norm_det);
    if (det32 < 0) inv_det_23 = -inv_det_23;

    // SOLVE HIGH-PRECISION GRADIENTS

    fx32 w0_inv = DIV(FX(1.0f), v0.w);
    fx32 w1_inv = DIV(FX(1.0f), v1.w);
    fx32 w2_inv = DIV(FX(1.0f), v2.w);

    fx32 s0_w = FIXED_MUL(v0.s, w0_inv); fx32 s1_w = FIXED_MUL(v1.s, w1_inv); fx32 s2_w = FIXED_MUL(v2.s, w2_inv);
    fx32 t0_w = FIXED_MUL(v0.t, w0_inv); fx32 t1_w = FIXED_MUL(v1.t, w1_inv); fx32 t2_w = FIXED_MUL(v2.t, w2_inv);
    fx32 q0_w = FIXED_MUL(v0.q, w0_inv); fx32 q1_w = FIXED_MUL(v1.q, w1_inv); fx32 q2_w = FIXED_MUL(v2.q, w2_inv);
    fx32 r0_w = FIXED_MUL(v0.r, w0_inv); fx32 r1_w = FIXED_MUL(v1.r, w1_inv); fx32 r2_w = FIXED_MUL(v2.r, w2_inv);
    fx32 g0_w = FIXED_MUL(v0.g, w0_inv); fx32 g1_w = FIXED_MUL(v1.g, w1_inv); fx32 g2_w = FIXED_MUL(v2.g, w2_inv);
    fx32 b0_w = FIXED_MUL(v0.b, w0_inv); fx32 b1_w = FIXED_MUL(v1.b, w1_inv); fx32 b2_w = FIXED_MUL(v2.b, w2_inv);

    fx32 dw_inv1 = w1_inv - w0_inv; fx32 dw_inv2 = w2_inv - w0_inv;
    fx32 ds1 = s1_w - s0_w;         fx32 ds2 = s2_w - s0_w;
    fx32 dt1 = t1_w - t0_w;         fx32 dt2 = t2_w - t0_w;
    fx32 dq1 = q1_w - q0_w;         fx32 dq2 = q2_w - q0_w;
    fx32 dr1 = r1_w - r0_w;         fx32 dr2 = r2_w - r0_w;
    fx32 dg1 = g1_w - g0_w;         fx32 dg2 = g2_w - g0_w;
    fx32 db1 = b1_w - b0_w;         fx32 db2 = b2_w - b0_w;

    int64_t raw_dw_dx = solve_gradient_fast(det, inv_det_23, shift, dw_inv1, dy2, dw_inv2, dy1);
    int64_t raw_du_dx = solve_gradient_fast(det, inv_det_23, shift, ds1,     dy2, ds2,     dy1);
    int64_t raw_dv_dx = solve_gradient_fast(det, inv_det_23, shift, dt1,     dy2, dt2,     dy1);
    int64_t raw_dq_dx = solve_gradient_fast(det, inv_det_23, shift, dq1,     dy2, dq2,     dy1);
    int64_t raw_dr_dx = solve_gradient_fast(det, inv_det_23, shift, dr1,     dy2, dr2,     dy1);
    int64_t raw_dg_dx = solve_gradient_fast(det, inv_det_23, shift, dg1,     dy2, dg2,     dy1);
    int64_t raw_db_dx = solve_gradient_fast(det, inv_det_23, shift, db1,     dy2, db2,     dy1);

    int64_t raw_dw_dy = solve_gradient_fast(det, inv_det_23, shift, dw_inv2, dx1, dw_inv1, dx2);
    int64_t raw_ds_dy = solve_gradient_fast(det, inv_det_23, shift, ds2,     dx1, ds1,     dx2);
    int64_t raw_dt_dy = solve_gradient_fast(det, inv_det_23, shift, dt2,     dx1, dt1,     dx2);
    int64_t raw_dq_dy = solve_gradient_fast(det, inv_det_23, shift, dq2,     dx1, dq1,     dx2);
    int64_t raw_dr_dy = solve_gradient_fast(det, inv_det_23, shift, dr2,     dx1, dr1,     dx2);
    int64_t raw_dg_dy = solve_gradient_fast(det, inv_det_23, shift, dg2,     dx1, dg1,     dx2);
    int64_t raw_db_dy = solve_gradient_fast(det, inv_det_23, shift, db2,     dx1, db1,     dx2);

    int64_t raw_start_w = ((int64_t)w0_inv << 16) - mul_shr4(v0.x, raw_dw_dx) - mul_shr4(v0.y, raw_dw_dy);
    int64_t raw_start_s = ((int64_t)s0_w   << 16) - mul_shr4(v0.x, raw_du_dx) - mul_shr4(v0.y, raw_ds_dy);
    int64_t raw_start_t = ((int64_t)t0_w   << 16) - mul_shr4(v0.x, raw_dv_dx) - mul_shr4(v0.y, raw_dt_dy);
    int64_t raw_start_q = ((int64_t)q0_w   << 16) - mul_shr4(v0.x, raw_dq_dx) - mul_shr4(v0.y, raw_dq_dy);
    int64_t raw_start_r = ((int64_t)r0_w   << 16) - mul_shr4(v0.x, raw_dr_dx) - mul_shr4(v0.y, raw_dr_dy);
    int64_t raw_start_g = ((int64_t)g0_w   << 16) - mul_shr4(v0.x, raw_dg_dx) - mul_shr4(v0.y, raw_dg_dy);
    int64_t raw_start_b = ((int64_t)b0_w   << 16) - mul_shr4(v0.x, raw_db_dx) - mul_shr4(v0.y, raw_db_dy);    

    int32_t start_w = (int32_t)(raw_start_w >> 2);
    int32_t dw_dx   = (int32_t)(raw_dw_dx   >> 2);
    int32_t dw_dy   = (int32_t)(raw_dw_dy   >> 2);

    int32_t start_s = (int32_t)(raw_start_s >> 14);
    int32_t du_dx   = (int32_t)(raw_du_dx   >> 14);
    int32_t du_dy   = (int32_t)(raw_ds_dy   >> 14);

    int32_t start_t = (int32_t)(raw_start_t >> 14);
    int32_t dv_dx   = (int32_t)(raw_dv_dx   >> 14);
    int32_t dv_dy   = (int32_t)(raw_dt_dy   >> 14);

    int32_t start_q = (int32_t)(raw_start_q >> 14);
    int32_t dq_dx   = (int32_t)(raw_dq_dx   >> 14);
    int32_t dq_dy   = (int32_t)(raw_dq_dy   >> 14);

    int32_t start_r = ((int32_t)(raw_start_r >> 20) << 8) >> 8;
    int32_t dr_dx   = ((int32_t)(raw_dr_dx   >> 20) << 8) >> 8;
    int32_t dr_dy   = ((int32_t)(raw_dr_dy   >> 20) << 8) >> 8;

    int32_t start_g = ((int32_t)(raw_start_g >> 20) << 8) >> 8;
    int32_t dg_dx   = ((int32_t)(raw_dg_dx   >> 20) << 8) >> 8;
    int32_t dg_dy   = ((int32_t)(raw_dg_dy   >> 20) << 8) >> 8;

    int32_t start_b = ((int32_t)(raw_start_b >> 20) << 8) >> 8;
    int32_t db_dx   = ((int32_t)(raw_db_dx   >> 20) << 8) >> 8;
    int32_t db_dy   = ((int32_t)(raw_db_dy   >> 20) << 8) >> 8;

    // Rasterizer Bounding Box & Pineda Edges setup
    bool sign_bit = det > 0;

    int start_y = v0.y >> 4;
    int min_x   = min3(v0.x, v1.x, v2.x) >> 4;
    int max_x   = max3(v0.x, v1.x, v2.x) >> 4;
    int max_y   = v2.y >> 4;

    if (min_x < 0) min_x = 0;
    if (max_x >= fb_width) max_x = fb_width - 1;
    if (max_y >= fb_height) max_y = fb_height - 1;
    if (start_y < 0) start_y = 0;    

    int curr_x = min_x;
    int curr_y = start_y;

    int32_t acc_w_inv = start_w + FAST_MUL32(curr_x, dw_dx) + FAST_MUL32(curr_y, dw_dy) + (dw_dx >> 1) + (dw_dy >> 1);
    int32_t acc_u_w   = start_s + FAST_MUL32(curr_x, du_dx) + FAST_MUL32(curr_y, du_dy) + (du_dx >> 1) + (du_dy >> 1);
    int32_t acc_v_w   = start_t + FAST_MUL32(curr_x, dv_dx) + FAST_MUL32(curr_y, dv_dy) + (dv_dx >> 1) + (dv_dy >> 1);
    int32_t acc_q_w   = start_q + FAST_MUL32(curr_x, dq_dx) + FAST_MUL32(curr_y, dq_dy) + (dq_dx >> 1) + (dq_dy >> 1);
    int32_t acc_r_w   = start_r + FAST_MUL32(curr_x, dr_dx) + FAST_MUL32(curr_y, dr_dy) + (dr_dx >> 1) + (dr_dy >> 1);
    int32_t acc_g_w   = start_g + FAST_MUL32(curr_x, dg_dx) + FAST_MUL32(curr_y, dg_dy) + (dg_dx >> 1) + (dg_dy >> 1);
    int32_t acc_b_w   = start_b + FAST_MUL32(curr_x, db_dx) + FAST_MUL32(curr_y, db_dy) + (db_dx >> 1) + (db_dy >> 1);


    uint32_t t2_tri_setup = MEM_READ(TIMER);
    t_tri_setup += t2_tri_setup - t1_tri_setup;

    uint32_t t1_tri_raster = MEM_READ(TIMER);

    push_16(OP_SET_V0_X, v0.x);
    push_16(OP_SET_V0_Y, v0.y);
    push_16(OP_SET_V1_X, v1.x);
    push_16(OP_SET_V1_Y, v1.y);
    push_16(OP_SET_V2_X, v2.x);
    push_16(OP_SET_V2_Y, v2.y);

    push_32(OP_SET_START_W_INV, acc_w_inv);
    push_32(OP_SET_START_S, acc_u_w);
    push_32(OP_SET_START_T, acc_v_w);
    push_32(OP_SET_START_R, acc_r_w);
    push_32(OP_SET_START_G, acc_g_w);
    push_32(OP_SET_START_B, acc_b_w);

    push_32(OP_SET_DW_DX, dw_dx);
    push_32(OP_SET_DW_DY, dw_dy);
    push_32(OP_SET_DS_DX, du_dx);
    push_32(OP_SET_DS_DY, du_dy);
    push_32(OP_SET_DT_DX, dv_dx);
    push_32(OP_SET_DT_DY, dv_dy);
    push_32(OP_SET_DQ_DX, dq_dx);
    push_32(OP_SET_DQ_DY, dq_dy);
    push_32(OP_SET_DR_DX, dr_dx);
    push_32(OP_SET_DR_DY, dr_dy);
    push_32(OP_SET_DG_DX, dg_dx);
    push_32(OP_SET_DG_DY, dg_dy);
    push_32(OP_SET_DB_DX, db_dx);
    push_32(OP_SET_DB_DY, db_dy);
    push_32(OP_SET_START_Q, acc_q_w);

    struct Command cmd;

    cmd.opcode = OP_DRAW;

    cmd.param = (depth_test ? 0b01000 : 0b00000) | (clamp_s ? 0b00100 : 0b00000) | (clamp_t ? 0b00010 : 0b00000) |
              ((tex != NULL) ? 0b00001 : 0b00000) | (perspective_correct ? 0b10000 : 0b00000) |
              (sign_bit ? 0b100000 : 0b000000) | (enable_shadow_map ? (1<<12) : 0);

    cmd.param |= texture_scale_x << 6;
    cmd.param |= texture_scale_y << 9;

    send_command(&cmd);

    uint32_t t2_tri_raster = MEM_READ(TIMER);
    t_tri_raster += t2_tri_raster - t1_tri_raster;
}

void clear(unsigned int color)
{
    struct Command cmd;

    // Clear framebuffer
    cmd.opcode = OP_CLEAR;
    cmd.param = color;
    send_command(&cmd);
    // Clear depth buffer
    cmd.opcode = OP_CLEAR;
    cmd.param = 0x01FFFF;
    send_command(&cmd);
}

void set_texture(int texture)
{
    uint32_t tex_addr = ((uint32_t)(texture ? &tex64x64[0] : &tex32x32[0])) >> 1;

    struct Command cmd;
    cmd.opcode = OP_SET_TEX_ADDR;
    cmd.param = tex_addr & 0xFFFF;
    send_command(&cmd);
    cmd.param = 0x10000 | (tex_addr >> 16);
    send_command(&cmd);
}

void init_graphite()
{
    MEM_WRITE(0xE0000024, 3); // enable graphite
}

void swap()
{
    struct Command cmd;

    cmd.opcode = OP_SWAP;
    cmd.param = 0x1;
    send_command(&cmd);
}

void print_help(void)
{
    printf("[h]: help, [q]: quit, [s]: stats, [SPACE]: rotation,\r\n"
        "[t]: texture, [l]: lighting, [g]: gouraud shading, [w]: wireframe, [m]: teapot/cube,\r\n"
        "[u]: clamp s, [v] clamp t, [r] rasterizer ena, [p]: perspective correct\r\n"
        "[0]: texture 32x32, [1]: texture 64x64\r\n");
}

void main(void)
{
    unsigned int res = MEM_READ(CONFIG);
    fb_width = res >> 16;
    fb_height = res & 0xffff;

    print_help();

    float theta = 0.0f;

    mat4x4 mat_proj = matrix_make_projection(fb_width, fb_height, 60.0f);


    // camera
    vec3d  vec_camera = {FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)};
    mat4x4 mat_view   = matrix_make_identity();

    model_t *cube_model = load_cube();
    model_t *teapot_model = load_teapot();

    model_t *model = teapot_model;

    bool quit = false;
    bool print_stats = true;
    bool is_rotating = false;
    bool is_textured = true;
    size_t nb_lights = 4;
    bool is_wireframe = false;
    bool clamp_s = false;
    bool clamp_t = false;
    bool perspective_correct = true;
    bool gouraud_shading = true;
    int texture = 1;

    light_t lights[5];
    lights[0].direction = (vec3d){FX(0.0f), FX(0.0f), FX(1.0f), FX(0.0f)};
    lights[0].ambient_color = (vec3d){FX(0.1f), FX(0.1f), FX(0.1f), FX(1.0f)};
    lights[0].diffuse_color = (vec3d){FX(0.5f), FX(0.5f), FX(0.5f), FX(1.0f)};
    lights[1].direction = (vec3d){FX(1.0f), FX(0.0f), FX(0.0f), FX(0.0f)};
    lights[1].ambient_color = (vec3d){FX(0.1f), FX(0.0f), FX(0.0f), FX(1.0f)};
    lights[1].diffuse_color = (vec3d){FX(0.2f), FX(0.0f), FX(0.0f), FX(1.0f)};
    lights[2].direction = (vec3d){FX(0.0f), FX(1.0f), FX(0.0f), FX(0.0f)};
    lights[2].ambient_color = (vec3d){FX(0.0f), FX(0.1f), FX(0.0f), FX(1.0f)};
    lights[2].diffuse_color = (vec3d){FX(0.0f), FX(0.2f), FX(0.0f), FX(1.0f)};
    lights[3].direction = (vec3d){FX(0.0f), FX(-1.0f), FX(0.0f), FX(0.0f)};
    lights[3].ambient_color = (vec3d){FX(0.0f), FX(0.0f), FX(0.1f), FX(1.0f)};
    lights[3].diffuse_color = (vec3d){FX(0.0f), FX(0.0f), FX(0.2f), FX(1.0f)};
    lights[4].direction = (vec3d){FX(-1.0f), FX(0.0f), FX(0.0f), FX(0.0f)};
    lights[4].ambient_color = (vec3d){FX(0.1f), FX(0.1f), FX(0.0f), FX(1.0f)};
    lights[4].diffuse_color = (vec3d){FX(0.2f), FX(0.2f), FX(0.0f), FX(1.0f)};      

    clear(0x31A6);

    uint32_t counter = 0;
    while(!quit) {
        MEM_WRITE(LED, counter >> 2);
        counter++;

        if (chr_avail()) {
            char c = get_chr();
            if (c == 'h') {
                print_help();
            } else if (c == 'q') {
                quit = true;
            } else if (c == 's') {
                print_stats = !print_stats;
            } else if (c == ' ') {
                is_rotating = !is_rotating;
            } else if (c == 't') {
                is_textured = !is_textured;
            } else if (c == 'l') {
                nb_lights = (nb_lights + 1) % 6;
            } else if (c == 'w') {
                is_wireframe = !is_wireframe;
            } else if (c == 'm') {
                if (model == cube_model) {
                    model = teapot_model;
                } else {
                    model = cube_model;
                }
            } else if (c == 'u') {
                clamp_s = !clamp_s;
            } else if (c == 'v') {
                clamp_t = !clamp_t;
            } else if (c == 'r') {
                rasterizer_ena = !rasterizer_ena;
            } else if (c == 'p') {
                perspective_correct = !perspective_correct;
            } else if (c == 'g') {
                gouraud_shading = !gouraud_shading;
            } else if (c == '0') {
                texture = 0;
            } else if (c == '1') {
                texture = 1;
            }
        }

        uint32_t t1 = MEM_READ(TIMER);

        uint32_t t1_clear = MEM_READ(TIMER);
        if (rasterizer_ena)
            clear(0x31A6);
        uint32_t t2_clear = MEM_READ(TIMER);

        uint32_t t1_xform = MEM_READ(TIMER);

        // world
        mat4x4 mat_rot_z = matrix_make_rotation_z(theta);
        mat4x4 mat_rot_x = matrix_make_rotation_x(theta);

        mat4x4 mat_trans = matrix_make_translation(FX(0.0f), FX(0.0f), FX(5.0f));
        mat4x4 mat_world, mat_normal;
        mat_world = matrix_make_identity();
        mat_world = mat_normal = matrix_multiply_matrix(&mat_rot_z, &mat_rot_x);
        mat_world = matrix_multiply_matrix(&mat_world, &mat_trans);
        uint32_t t2_xform = MEM_READ(TIMER);

        uint32_t t1_draw = MEM_READ(TIMER);

        // Pass 1: Render shadow map
        enable_shadow_map = false;
        
        // Light view/proj
        mat4x4 mat_light_proj = matrix_make_projection(64, 64, 60.0f);
        vec3d light_pos = vector_mul(&lights[0].direction, FX(-10.0f));
        vec3d target = {FX(0), FX(0), FX(0)};
        vec3d up = {FX(0), FX(1), FX(0)};
        mat4x4 mat_light_view = matrix_point_at(&light_pos, &target, &up);
        mat_light_view = matrix_quick_inverse(&mat_light_view);
        mat4x4 mat_light_view_proj = matrix_multiply_matrix(&mat_light_proj, &mat_light_view);
        
        // Set FB to our dedicated shadow FB buffer
        uint32_t pass1_fb_addr = ((uint32_t)(&shadow_fb[0])) >> 1;
        uint32_t tex_addr = pass1_fb_addr;
        
        struct Command cmd;
        cmd.opcode = OP_SET_FB_ADDR;
        cmd.param = tex_addr & 0xFFFF;
        send_command(&cmd);
        cmd.param = 0x10000 | (tex_addr >> 16);
        send_command(&cmd);
/*        
        // Clear shadow map texture (which is now FB)
        cmd.opcode = OP_CLEAR;
        cmd.param = 0xFFFF; // Max depth
        send_command(&cmd);
        
        nb_triangles = 0;
        t_tri_setup = 0;
        t_tri_raster = 0;
        
        draw_model_ext(64, 64, &light_pos, model, &mat_world, gouraud_shading ? &mat_normal : NULL, &mat_light_proj, &mat_light_view, lights, nb_lights, is_wireframe, NULL, false, false, 0, 0, perspective_correct, NULL, true);

        // Pass 2: Render scene
        enable_shadow_map = true;
        
        // Restore FB ADDR (0x01000000 bytes -> 0x00800000 words)
        cmd.opcode = OP_SET_FB_ADDR;
        cmd.param = 0x0000; // Low 16 bits
        send_command(&cmd);
        cmd.param = 0x10000 | 0x0080; // High 16 bits
        send_command(&cmd);

        
        // Pass 2 Texture address is the Z-buffer from Pass 1
        uint32_t pass2_tex_addr = pass1_fb_addr + 2 * 320 * 240;
        cmd.opcode = OP_SET_TEX_ADDR;
        cmd.param = pass2_tex_addr & 0xFFFF;
        send_command(&cmd);
        cmd.param = 0x10000 | (pass2_tex_addr >> 16);
        send_command(&cmd);
        
        set_texture(texture);
        texture_t dummy_texture;
        draw_model_ext(fb_width, fb_height, &vec_camera, model, &mat_world, gouraud_shading ? &mat_normal : NULL, &mat_proj, &mat_view, lights, nb_lights, is_wireframe, is_textured ? &dummy_texture : NULL, clamp_s, clamp_t, texture > 0 ? 1 : 0, texture > 0 ? 1 : 0, perspective_correct, &mat_light_view_proj, false);
        */
        uint32_t t2_draw = MEM_READ(TIMER);

        swap();

        if (is_rotating) {
            theta += 0.1f;
            if (theta > 6.28f)
                theta = 0.0f;
        }

        uint32_t t2 = MEM_READ(TIMER);

        printf(".");
        if (print_stats)
            printf("xform: %d ms, clear: %d ms, tri_setup: %d ms, tri_raster: %d ms, draw: %d ms, total: %d ms, nb triangles: %d, tri/sec: %d\r\n", t2_xform - t1_xform, t2_clear - t1_clear, t_tri_setup, t_tri_raster, t2_draw - t1_draw, t2 - t1, nb_triangles, nb_triangles * 1000 / (t2 - t1));
    }
}
