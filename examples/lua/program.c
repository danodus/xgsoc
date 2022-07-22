// program.c
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

#include <io.h>
#include <fs.h>
#include <xga.h>
#include <graphite.h>

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"
#include "luamem.h"

#include "editor.h"


LUAMEMMOD_API int luaopen_memory (lua_State *L);

int poke(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    if (addr % 4)
        luaL_error(L, "Unaligned address");
    unsigned int value = luaL_checkinteger(L, 2);
    MEM_WRITE(addr, value);
    return 0;
}

int pokes(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    if (addr % 2)
        luaL_error(L, "Unaligned address");
    unsigned short int value = luaL_checkinteger(L, 2);
    *((volatile unsigned short int *)(addr)) = value;
    return 0;
}

int pokeb(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    unsigned char value = luaL_checkinteger(L, 2);
    *((volatile unsigned char *)(addr)) = value;
    return 0;
}

int peek(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    if (addr % 4)
        luaL_error(L, "Unaligned address");
    unsigned int value = MEM_READ(addr);
    lua_pushinteger(L, value);
    return 1;
}

int peeks(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    if (addr % 2)
        luaL_error(L, "Unaligned address");
    unsigned short int value = *((volatile unsigned short int *)(addr));
    lua_pushinteger(L, value);
    return 1;
}

int peekb(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    unsigned char value = *((volatile unsigned char *)(addr));
    lua_pushinteger(L, value);
    return 1;
}

int call(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    if (addr % 4)
        luaL_error(L, "Unaligned address");
    int nb_args = lua_gettop(L) - 1;
    if (nb_args > 8)
        nb_args = 8;
    int ret;
    switch(nb_args) {
        case 0: {
            int (*fun_ptr)(void) = (int (*)(void))addr;
            ret = (*fun_ptr)();
            break;
        }
        case 1: {
            int p0 = luaL_checkinteger(L, 2);
            int (*fun_ptr)(int) = (int (*)(int))addr;
            ret = (*fun_ptr)(p0);
            break;
        }
        case 2: {
            int p0 = luaL_checkinteger(L, 2);
            int p1 = luaL_checkinteger(L, 3);
            int (*fun_ptr)(int, int) = (int (*)(int, int))addr;
            ret = (*fun_ptr)(p0, p1);
            break;
        }
        case 3: {
            int p0 = luaL_checkinteger(L, 2);
            int p1 = luaL_checkinteger(L, 3);
            int p2 = luaL_checkinteger(L, 4);
            int (*fun_ptr)(int, int, int) = (int (*)(int, int, int))addr;
            ret = (*fun_ptr)(p0, p1, p2);
            break;
        }
        case 4: {
            int p0 = luaL_checkinteger(L, 2);
            int p1 = luaL_checkinteger(L, 3);
            int p2 = luaL_checkinteger(L, 4);
            int p3 = luaL_checkinteger(L, 5);
            int (*fun_ptr)(int, int, int, int) = (int (*)(int, int, int, int))addr;
            ret = (*fun_ptr)(p0, p1, p2, p3);
            break;
        }
        case 5: {
            int p0 = luaL_checkinteger(L, 2);
            int p1 = luaL_checkinteger(L, 3);
            int p2 = luaL_checkinteger(L, 4);
            int p3 = luaL_checkinteger(L, 5);
            int p4 = luaL_checkinteger(L, 6);
            int (*fun_ptr)(int, int, int, int, int) = (int (*)(int, int, int, int, int))addr;
            ret = (*fun_ptr)(p0, p1, p2, p3, p4);
            break;
        }
        case 6: {
            int p0 = luaL_checkinteger(L, 2);
            int p1 = luaL_checkinteger(L, 3);
            int p2 = luaL_checkinteger(L, 4);
            int p3 = luaL_checkinteger(L, 5);
            int p4 = luaL_checkinteger(L, 6);
            int p5 = luaL_checkinteger(L, 7);
            int (*fun_ptr)(int, int, int, int, int, int) = (int (*)(int, int, int, int, int, int))addr;
            ret = (*fun_ptr)(p0, p1, p2, p3, p4, p5);
            break;
        }
        case 7: {
            int p0 = luaL_checkinteger(L, 2);
            int p1 = luaL_checkinteger(L, 3);
            int p2 = luaL_checkinteger(L, 4);
            int p3 = luaL_checkinteger(L, 5);
            int p4 = luaL_checkinteger(L, 6);
            int p5 = luaL_checkinteger(L, 7);
            int p6 = luaL_checkinteger(L, 8);
            int (*fun_ptr)(int, int, int, int, int, int, int) = (int (*)(int, int, int, int, int, int, int))addr;
            ret = (*fun_ptr)(p0, p1, p2, p3, p4, p5, p6);
            break;
        }
        case 8: {
            int p0 = luaL_checkinteger(L, 2);
            int p1 = luaL_checkinteger(L, 3);
            int p2 = luaL_checkinteger(L, 4);
            int p3 = luaL_checkinteger(L, 5);
            int p4 = luaL_checkinteger(L, 6);
            int p5 = luaL_checkinteger(L, 7);
            int p6 = luaL_checkinteger(L, 8);
            int p7 = luaL_checkinteger(L, 9);
            int (*fun_ptr)(int, int, int, int, int, int, int, int) = (int (*)(int, int, int, int, int, int, int, int))addr;
            ret = (*fun_ptr)(p0, p1, p2, p3, p4, p5, p6, p7);
            break;
        }
    }
    lua_pushinteger(L, ret);
    return 1;
}

int edit(lua_State *L) {
    const char *filename = luaL_checkstring(L, 1);
    start_editor(filename);
    return 0;
}

int fsdir(lua_State *L) {
    sd_context_t sd_ctx;
    if (!sd_init(&sd_ctx)) {
        lua_pushnil(L);
        return 1;
    }
    fs_context_t fs_ctx;
    if (!fs_init(&sd_ctx, &fs_ctx)) {
        lua_pushnil(L);
        return 1;
    }
    lua_newtable(L);
    uint16_t nb_files = fs_get_nb_files(&fs_ctx);
    for (uint16_t i = 0; i < nb_files; ++i) {
        fs_file_info_t file_info;
        if (fs_get_file_info(&fs_ctx, i, &file_info)) {
            lua_pushstring(L, file_info.name);
            lua_newtable(L);

            lua_pushstring(L, "size");
            lua_pushinteger(L, file_info.size);
            lua_settable(L, -3);

            lua_pushstring(L, "fblock");
            lua_pushinteger(L, file_info.first_block_table_index);
            lua_settable(L, -3);

            lua_settable(L, -3);
        }
    }

    return 1;
}

int fsdelete(lua_State *L) {
    const char *filename = luaL_checkstring(L, 1);

    sd_context_t sd_ctx;
    if (!sd_init(&sd_ctx)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    fs_context_t fs_ctx;
    if (!fs_init(&sd_ctx, &fs_ctx)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    if (!fs_delete(&fs_ctx, filename)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    lua_pushboolean(L, 1);
    return 1;
}

int fsrename(lua_State *L) {
    const char *filename = luaL_checkstring(L, 1);
    const char *new_filename = luaL_checkstring(L, 2);

    sd_context_t sd_ctx;
    if (!sd_init(&sd_ctx)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    fs_context_t fs_ctx;
    if (!fs_init(&sd_ctx, &fs_ctx)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    if (!fs_rename(&fs_ctx, filename, new_filename)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    lua_pushboolean(L, 1);
    return 1;
}

int fsformat(lua_State *L) {
    luaL_checkany(L, 1);
    bool quick = lua_toboolean(L, 1) ? true : false;

    sd_context_t sd_ctx;
    if (!sd_init(&sd_ctx)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    if (!fs_format(&sd_ctx, quick)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    lua_pushboolean(L, 1);
    return 1;
}

// ------------------------------------------------------------------------
// Graphite
//

#define PARAM(x) (x)

struct Command {
    uint32_t opcode : 8;
    uint32_t param : 24;
};

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

int gr_enable(lua_State *L) {
    // enable Graphite
    MEM_WRITE(XGA_CONTROL, 0x1);
    return 0;
}

int gr_disable(lua_State *L) {
    // disable Graphite
    MEM_WRITE(XGA_CONTROL, 0x0);
    return 0;
}

int gr_clear(lua_State *L) {
    unsigned int color = luaL_checkinteger(L, 1);

    struct Command cmd;

    // Clear framebuffer
    cmd.opcode = OP_CLEAR;
    cmd.param = color;
    send_command(&cmd);
    // Clear depth buffer
    cmd.opcode = OP_CLEAR;
    cmd.param = 0x010000;
    send_command(&cmd);

    return 0;
}

int gr_set_texture_addr(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    uint32_t tex_addr = 3 * 640 * 480 + addr;
    struct Command c;
    c.opcode = OP_SET_TEX_ADDR;
    c.param = tex_addr & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (tex_addr >> 16);
    send_command(&c);
    return 0;
}

int gr_write_texture(lua_State *L) {

    uint16_t *p = (uint16_t *)luamem_checkmemory(L, 1, NULL);
 
    struct Command c;
    c.opcode = OP_WRITE_TEX;
    for (int t = 0; t < 32; ++t)
        for (int s = 0; s < 32; ++s) {
            c.param = *p;
            send_command(&c);
            p++;
        }
    return 0;
}

int gr_swap(lua_State *L) {
    struct Command cmd;

    cmd.opcode = OP_SWAP;
    cmd.param = 0x1;
    send_command(&cmd);

    return 0;
}

int gr_matrix_make_identity(lua_State *L) {
    mat4x4 mat_ident = matrix_make_identity();
    char *m = luamem_newalloc(L, sizeof(mat4x4));
    memcpy(m, &mat_ident, sizeof(mat_ident));
    return 1;
}

int gr_matrix_make_projection(lua_State *L) {
    int viewport_width = luaL_checkinteger(L, 1);
    int viewport_height = luaL_checkinteger(L, 2);
    float fov = luaL_checknumber(L, 3);
    mat4x4 mat_proj = matrix_make_projection(viewport_width, viewport_height, fov);
    char *m = luamem_newalloc(L, sizeof(mat4x4));
    memcpy(m, &mat_proj, sizeof(mat_proj));

    return 1;
}

int gr_matrix_make_translation(lua_State *L) {
    int x = luaL_checkinteger(L, 1);
    int y = luaL_checkinteger(L, 2);
    int z = luaL_checkinteger(L, 3);

    mat4x4 mat = matrix_make_translation(x, y, z);
    char *m = luamem_newalloc(L, sizeof(mat4x4));
    memcpy(m, &mat, sizeof(mat));

    return 1;
}

int gr_matrix_multiply_matrix(lua_State *L) {

    mat4x4 *m1 = (mat4x4 *)luamem_checkmemory(L, 1, NULL);
    mat4x4 *m2 = (mat4x4 *)luamem_checkmemory(L, 2, NULL);

    mat4x4 mat = matrix_multiply_matrix(m1, m2);
    char *m = luamem_newalloc(L, sizeof(mat4x4));
    memcpy(m, &mat, sizeof(mat));

    return 1;
}

int gr_matrix_make_rotation_x(lua_State *L) {
    
    float theta = luaL_checknumber(L, 1);

    mat4x4 mat = matrix_make_rotation_x(theta);
    char *m = luamem_newalloc(L, sizeof(mat4x4));
    memcpy(m, &mat, sizeof(mat));

    return 1;
}

int gr_matrix_make_rotation_y(lua_State *L) {
    
    float theta = luaL_checknumber(L, 1);

    mat4x4 mat = matrix_make_rotation_y(theta);
    char *m = luamem_newalloc(L, sizeof(mat4x4));
    memcpy(m, &mat, sizeof(mat));

    return 1;
}

int gr_matrix_make_rotation_z(lua_State *L) {
    
    float theta = luaL_checknumber(L, 1);

    mat4x4 mat = matrix_make_rotation_z(theta);
    char *m = luamem_newalloc(L, sizeof(mat4x4));
    memcpy(m, &mat, sizeof(mat));

    return 1;
}

inline mesh_t get_mesh(lua_State *L, int index) {
    mesh_t mesh;
    size_t len;

    lua_pushstring(L, "vertices");
    lua_gettable(L, index);
    mesh.vertices = (vec3d *)luamem_checkmemory(L, -1, &len);
    mesh.nb_vertices = len / sizeof(vec3d);
    lua_pop(L, 1);

    lua_pushstring(L, "texcoords");
    lua_gettable(L, index);
    mesh.texcoords = (vec2d *)luamem_checkmemory(L, -1, &len);
    mesh.nb_texcoords = len / sizeof(vec2d);
    lua_pop(L, 1);

    lua_pushstring(L, "colors");
    lua_gettable(L, index);
    mesh.colors = (vec3d *)luamem_checkmemory(L, -1, &len);
    mesh.nb_colors = len / sizeof(vec3d);
    lua_pop(L, 1);

    lua_pushstring(L, "faces");
    lua_gettable(L, index);
    mesh.faces = (face_t *)luamem_checkmemory(L, -1, &len);
    mesh.nb_faces = len / sizeof(face_t);
    lua_pop(L, 1);

    return mesh;
}

int gr_draw_model(lua_State *L) {
    model_t model;

    int viewport_width = luaL_checkinteger(L, 1);
    int viewport_height = luaL_checkinteger(L, 2);

    vec3d *vec_camera = (vec3d *)luamem_checkmemory(L, 3, NULL);

    lua_pushstring(L, "mesh");
    lua_gettable(L, 4);
    if (!lua_istable(L, -1))
        luaL_error(L, "Invalid mesh");

    model.mesh = get_mesh(L, -2);
    lua_pop(L, 1);

    mat4x4 *mat_world = (mat4x4 *)luamem_checkmemory(L, 5, NULL);
    mat4x4 *mat_proj = (mat4x4 *)luamem_checkmemory(L, 6, NULL);
    mat4x4 *mat_view = (mat4x4 *)luamem_checkmemory(L, 7, NULL);

    luaL_checkany(L, 8);
    bool is_lighting_ena = lua_toboolean(L, 8);
    luaL_checkany(L, 9);
    bool is_wireframe = lua_toboolean(L, 9);
    luaL_checkany(L, 10);
    bool is_texture_ena = lua_toboolean(L, 10);
    luaL_checkany(L, 11);
    bool clamp_s = lua_toboolean(L, 11);
    luaL_checkany(L, 12);
    bool clamp_t = lua_toboolean(L, 12);

    model.triangles_to_raster = (triangle_t *)malloc(model.mesh.nb_faces * sizeof(triangle_t));
    texture_t dummy_texture;
    draw_model(viewport_width, viewport_height, vec_camera, &model, mat_world, mat_proj, mat_view, is_lighting_ena, is_wireframe, is_texture_ena ? &dummy_texture : NULL, clamp_s, clamp_t);
    free(model.triangles_to_raster);

    return 0;
}

int handle_lua_error(lua_State *L) {
    const char * msg = lua_tostring(L, -1);
    luaL_traceback(L, L, msg, 2);
    lua_remove(L, -2); // remove error/"msg" from stack
    return 1; // traceback is returned
}

void main(void) {
    printf("%s\n", LUA_RELEASE);

    char buff[256];
    int error;

    lua_State *L = luaL_newstate();
    if (L == NULL) {
        printf("Unable to create Lua state\n");
        for (;;);
    }
    luaL_openlibs(L);

    luaopen_memory(L);
    lua_setglobal(L, "memory");

    lua_pushcfunction(L, poke);
    lua_setglobal(L, "poke");

    lua_pushcfunction(L, pokes);
    lua_setglobal(L, "pokes");

    lua_pushcfunction(L, pokeb);
    lua_setglobal(L, "pokeb");

    lua_pushcfunction(L, peek);
    lua_setglobal(L, "peek");

    lua_pushcfunction(L, peeks);
    lua_setglobal(L, "peeks");

    lua_pushcfunction(L, peekb);
    lua_setglobal(L, "peekb");

    lua_pushcfunction(L, call);
    lua_setglobal(L, "call");

    lua_pushcfunction(L, edit);
    lua_setglobal(L, "edit");

    lua_pushcfunction(L, fsdir);
    lua_setglobal(L, "fsdir");

    lua_pushcfunction(L, fsdelete);
    lua_setglobal(L, "fsdelete");  

    lua_pushcfunction(L, fsrename);
    lua_setglobal(L, "fsrename");

    lua_pushcfunction(L, fsformat);
    lua_setglobal(L, "fsformat");

    lua_pushcfunction(L, gr_enable);
    lua_setglobal(L, "gr_enable");

    lua_pushcfunction(L, gr_disable);
    lua_setglobal(L, "gr_disable");

    lua_pushcfunction(L, gr_clear);
    lua_setglobal(L, "gr_clear");

    lua_pushcfunction(L, gr_set_texture_addr);
    lua_setglobal(L, "gr_set_texture_addr");

    lua_pushcfunction(L, gr_write_texture);
    lua_setglobal(L, "gr_write_texture");

    lua_pushcfunction(L, gr_swap);
    lua_setglobal(L, "gr_swap");

    lua_pushcfunction(L, gr_matrix_make_identity);
    lua_setglobal(L, "gr_matrix_make_identity");
    
    lua_pushcfunction(L, gr_matrix_make_projection);
    lua_setglobal(L, "gr_matrix_make_projection");

    lua_pushcfunction(L, gr_matrix_make_translation);
    lua_setglobal(L, "gr_matrix_make_translation");

    lua_pushcfunction(L, gr_matrix_multiply_matrix);
    lua_setglobal(L, "gr_matrix_multiply_matrix");

    lua_pushcfunction(L, gr_matrix_make_rotation_x);
    lua_setglobal(L, "gr_matrix_make_rotation_x");

    lua_pushcfunction(L, gr_matrix_make_rotation_y);
    lua_setglobal(L, "gr_matrix_make_rotation_y");

    lua_pushcfunction(L, gr_matrix_make_rotation_z);
    lua_setglobal(L, "gr_matrix_make_rotation_z");

    lua_pushcfunction(L, gr_draw_model);
    lua_setglobal(L, "gr_draw_model");

    printf("Ready\n");

    for(;;) {
        printf(">");
        fflush(stdout);
        if (fgets(buff, 256, stdin)) {
            lua_pushcfunction(L, handle_lua_error);
            error = luaL_loadbuffer(L, buff, strlen(buff), "line") || lua_pcall(L, 0, 0, -2);
            if (error) {
                printf("%s\n", lua_tostring(L, -1));
                lua_pop(L, 1);
            }
            lua_pop(L, 1); // pop handle_lua_error
        }
    }

    lua_close(L);
}
