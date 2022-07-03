#include <io.h>

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
    return 1;
}

int peek(lua_State *L) {
    unsigned int addr = luaL_checkinteger(L, 1);
    unsigned int value = MEM_READ(addr);
    lua_pushinteger(L, value);
    return 1;
}

int edit(lua_State *L) {
    const char *filename = luaL_checkstring(L, 1);
    start_editor(filename);
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

    lua_pushcfunction(L, edit);
    lua_setglobal(L, "edit");

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
