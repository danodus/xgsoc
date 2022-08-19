#include <io.h>
#include <unistd.h>
#include <graphite.h>
#include <teapot.h>
#include <xga.h>

#define WIDTH 640
#define NB_COLS (WIDTH / 8)

#define BLACK           0x0
#define BLUE            0x1
#define GREEN           0x2
#define CYAN            0x3
#define RED             0x4
#define MAGENTA         0x5
#define BROWN           0x6
#define WHITE           0x7
#define GRAY            0x8
#define LIGHT_BLUE      0x9
#define LIGHT_GREEN     0xA
#define LIGHT_CYAN      0xB
#define LIGHT_RED       0xC
#define LIGHT_MAGENTA   0xD
#define YELLOW          0xE
#define BRIGHT_WHITE    0xF

#define PARAM(x) (x)

struct Command {
    uint32_t opcode : 8;
    uint32_t param : 24;
};

const uint16_t img[] = {
    64373, 64373, 64373, 64373, 64373, 64373, 62770, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373,
    64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64972, 64972, 64972, 64972, 64169, 64169, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64169, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64169, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    63060, 63060, 63060, 63060, 63060, 63060, 62770, 64373, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060,
    63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060,
    62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770,
    62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770,
    64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373,
    64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 64373, 62770, 64373, 64373, 64373, 64373, 64373,
    64972, 64169, 64169, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64972, 64972, 64972,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64972, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64169, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64169, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118,
    64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 64118, 63060, 62770, 64373, 64118, 64118, 64118, 64118,
    63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060,
    63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 63060, 62770, 64373, 63060, 63060, 63060, 63060,
    62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770,
    62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770, 62770};


void send_command(struct Command *cmd)
{
    while (!MEM_READ(GRAPHITE));
    MEM_WRITE(GRAPHITE, (cmd->opcode << 24) | cmd->param);
}

void xd_draw_triangle(fx32 x0, fx32 y0, fx32 z0, fx32 u0, fx32 v0, fx32 r0, fx32 g0, fx32 b0, fx32 a0, fx32 x1, fx32 y1,
                      fx32 z1, fx32 u1, fx32 v1, fx32 r1, fx32 g1, fx32 b1, fx32 a1, fx32 x2, fx32 y2, fx32 z2, fx32 u2,
                      fx32 v2, fx32 r2, fx32 g2, fx32 b2, fx32 a2, texture_t* tex, bool clamp_s, bool clamp_t,
                      bool depth_test)
{
    struct Command c;

    c.opcode = OP_SET_X0;
    c.param = PARAM(x0) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(x0) >> 16);
    send_command(&c);

    c.opcode = OP_SET_Y0;
    c.param = PARAM(y0) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(y0) >> 16);
    send_command(&c);

    c.opcode = OP_SET_Z0;
    c.param = PARAM(z0) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(z0) >> 16);
    send_command(&c);

    c.opcode = OP_SET_X1;
    c.param = PARAM(x1) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(x1) >> 16);
    send_command(&c);

    c.opcode = OP_SET_Y1;
    c.param = PARAM(y1) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(y1) >> 16);
    send_command(&c);

    c.opcode = OP_SET_Z1;
    c.param = PARAM(z1) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(z1) >> 16);
    send_command(&c);

    c.opcode = OP_SET_X2;
    c.param = PARAM(x2) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(x2) >> 16);
    send_command(&c);

    c.opcode = OP_SET_Y2;
    c.param = PARAM(y2) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(y2) >> 16);
    send_command(&c);

    c.opcode = OP_SET_Z2;
    c.param = PARAM(z2) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(z2) >> 16);
    send_command(&c);

    c.opcode = OP_SET_S0;
    c.param = PARAM(u0) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(u0) >> 16);
    send_command(&c);

    c.opcode = OP_SET_T0;
    c.param = PARAM(v0) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(v0) >> 16);
    send_command(&c);

    c.opcode = OP_SET_S1;
    c.param = PARAM(u1) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(u1) >> 16);
    send_command(&c);

    c.opcode = OP_SET_T1;
    c.param = PARAM(v1) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(v1) >> 16);
    send_command(&c);

    c.opcode = OP_SET_S2;
    c.param = PARAM(u2) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(u2) >> 16);
    send_command(&c);

    c.opcode = OP_SET_T2;
    c.param = PARAM(v2) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(v2) >> 16);
    send_command(&c);

    c.opcode = OP_SET_R0;
    c.param = PARAM(r0) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(r0) >> 16);
    send_command(&c);

    c.opcode = OP_SET_G0;
    c.param = PARAM(g0) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(g0) >> 16);
    send_command(&c);

    c.opcode = OP_SET_B0;
    c.param = PARAM(b0) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(b0) >> 16);
    send_command(&c);

    c.opcode = OP_SET_R1;
    c.param = PARAM(r1) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(r1) >> 16);
    send_command(&c);

    c.opcode = OP_SET_G1;
    c.param = PARAM(g1) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(g1) >> 16);
    send_command(&c);

    c.opcode = OP_SET_B1;
    c.param = PARAM(b1) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(b1) >> 16);
    send_command(&c);

    c.opcode = OP_SET_R2;
    c.param = PARAM(r2) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(r2) >> 16);
    send_command(&c);

    c.opcode = OP_SET_G2;
    c.param = PARAM(g2) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(g2) >> 16);
    send_command(&c);

    c.opcode = OP_SET_B2;
    c.param = PARAM(b2) & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (PARAM(b2) >> 16);
    send_command(&c);

    c.opcode = OP_DRAW;
    c.param = (depth_test ? 0b1000 : 0b0000) | (clamp_s ? 0b0100 : 0b0000) | (clamp_t ? 0b0010 : 0b0000) |
              ((tex != NULL) ? 0b0001 : 0b0000);
    send_command(&c);
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
    cmd.param = 0x010000;
    send_command(&cmd);
}

void write_texture() {
    uint32_t tex_addr = 3 * 320 * 240;

    struct Command c;
    c.opcode = OP_SET_TEX_ADDR;
    c.param = tex_addr & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (tex_addr >> 16);
    send_command(&c);

    c.opcode = OP_WRITE_TEX;
    const uint16_t* p = img;
    for (int t = 0; t < 32; ++t)
        for (int s = 0; s < 32; ++s) {
            c.param = *p;
             send_command(&c);
            p++;
        }
}

void swap()
{
    struct Command cmd;

    cmd.opcode = OP_SWAP;
    cmd.param = 0x1;
    send_command(&cmd);
}

void draw_line(vec3d v0, vec3d v1, vec3d c0, vec3d c1, fx32 thickness);

void xclear()
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, 0);
    for (int i = 0; i < NB_COLS*30; ++i)
        xm_setw(DATA, 0x0F00 | ' ');
}

void xprint(unsigned int x, unsigned int y, const char *s, unsigned char color)
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, y * NB_COLS + x);
    unsigned int w = (unsigned int)color << 8;
    for (; *s; ++s) {
        xm_setw(DATA, w | *s);
    }
}

void main(void)
{
    // enable Graphite
    MEM_WRITE(XGA_CONTROL, 0x1);

    xreg_setw(PA_GFX_CTRL, 0x0000);
    xclear();
    xprint(0, 0, "Draw Teapot", BRIGHT_WHITE);

    float theta = 0.5f;

    mat4x4 mat_proj = matrix_make_projection(320, 240, 60.0f);

    // camera
    vec3d  vec_camera = {FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)};
    mat4x4 mat_view   = matrix_make_identity();

    model_t *teapot_model = load_teapot();

    write_texture();

    for (;;) {

        uint16_t t1 = xm_getw(TIMER);

        clear(0x00F333);

        // world
        mat4x4 mat_rot_z = matrix_make_rotation_z(theta);
        mat4x4 mat_rot_x = matrix_make_rotation_x(theta);

        mat4x4 mat_trans = matrix_make_translation(FX(0.0f), FX(0.0f), FX(5.0f));
        mat4x4 mat_world;
        mat_world = matrix_make_identity();
        mat_world = matrix_multiply_matrix(&mat_rot_z, &mat_rot_x);
        mat_world = matrix_multiply_matrix(&mat_world, &mat_trans);

        texture_t dummy_texture;
        draw_model(320, 240, &vec_camera, teapot_model, &mat_world, &mat_proj, &mat_view, true, false, &dummy_texture, false, false);

        swap();

        theta += 0.1f;
        if (theta > 6.28f)
            theta = 0.0f;


        uint16_t t2 = xm_getw(TIMER);

        uint16_t dt;

        if (t2 >= t1)
        {
            dt = t2 - t1;
        }
        else
        {
            dt = 65535 - t1 + t2;
        }

        float freq = 1.0f / ((float)dt / 10000.0f);
        
        //char s[32];
        //itoa((int)freq, s, 10);
        //xprint(0, 29, "    FPS", WHITE);
        //xprint(0, 29, s, WHITE);        

    }

    // disable Graphite
    MEM_WRITE(XGA_CONTROL, 0x0);
}
