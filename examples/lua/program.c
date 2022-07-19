// program.c
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

#include <io.h>
#include <fs.h>

#include <stdio.h>
#include <string.h>

#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"

#include "editor.h"

int poke(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    unsigned int value = luaL_checkinteger(L, 2);
    MEM_WRITE(addr, value);
    return 0;
}

int peek(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    unsigned int value = MEM_READ(addr);
    lua_pushinteger(L, value);
    return 1;
}

int call(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    void (*fun_ptr)(void) = (void (*)(void))addr;
    (*fun_ptr)();
    return 0;
}

int callr(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    int (*fun_ptr)(void) = (int (*)(void))addr;
    int ret = (*fun_ptr)();
    lua_pushinteger(L, ret);
    return 1;
}

int callp1(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    int p0 = luaL_checkinteger(L, 2);
    void (*fun_ptr)(int) = (void (*)(int))addr;
    (*fun_ptr)(p0);
    return 0;
}


int callp1r(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    int p0 = luaL_checkinteger(L, 2);
    int (*fun_ptr)(int) = (int (*)(int))addr;
    int ret = (*fun_ptr)(p0);
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

    lua_pushcfunction(L, poke);
    lua_setglobal(L, "poke");

    lua_pushcfunction(L, peek);
    lua_setglobal(L, "peek");

    lua_pushcfunction(L, call);
    lua_setglobal(L, "call");

    lua_pushcfunction(L, callp1);
    lua_setglobal(L, "callp1");

    lua_pushcfunction(L, callr);
    lua_setglobal(L, "callr");

    lua_pushcfunction(L, callp1r);
    lua_setglobal(L, "callp1r");

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
