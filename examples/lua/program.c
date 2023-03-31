// program.c
// Copyright (c) 2022-2023 Daniel Cliche
// SPDX-License-Identifier: MIT

#include <io.h>
#include <sys.h>
#include <xga.h>

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"
#include "luamem.h"

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

int setttymode(lua_State *L) {
    unsigned int mode = luaL_checknumber(L, 1);
    sys_set_tty_mode(mode);
    return 0;
}

int fsdir(lua_State *L) {
    lua_newtable(L);
    uint16_t nb_files = sys_fs_get_nb_files();
    for (uint16_t i = 0; i < nb_files; ++i) {
        fs_file_info_t file_info;
        if (sys_fs_get_file_info(i, &file_info)) {
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

    if (!sys_fs_delete(filename)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    lua_pushboolean(L, 1);
    return 1;
}

int fsrename(lua_State *L) {
    const char *filename = luaL_checkstring(L, 1);
    const char *new_filename = luaL_checkstring(L, 2);

    if (!sys_fs_rename(filename, new_filename)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    lua_pushboolean(L, 1);
    return 1;
}

int fsformat(lua_State *L) {
    luaL_checkany(L, 1);
    bool quick = lua_toboolean(L, 1) ? true : false;

    if (!sys_fs_format(quick)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    lua_pushboolean(L, 1);
    return 1;
}

int fsunmount(lua_State *L) {
    if (!sys_fs_unmount()) {
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
    printf("\e[20h");
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

    lua_pushcfunction(L, setttymode);
    lua_setglobal(L, "setttymode");

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
