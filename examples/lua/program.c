#include <io.h>
#include <xio.h>

#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"

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

void main(void) {
    xinit();

    xprint(LUA_RELEASE);
    xprint("\n");

    char buff[256];
    int error;

    lua_State *L = luaL_newstate();
    if (L == NULL) {
        xprint("Unable to create Lua state\n");
        for (;;);
    }
    luaL_openlibs(L);

    lua_pushcfunction(L, poke);
    lua_setglobal(L, "poke");

    lua_pushcfunction(L, peek);
    lua_setglobal(L, "peek");

    xprint("Ready\n");

    for(;;) {
        size_t nb_chars = xreadline(buff, 256);
        error = luaL_loadbuffer(L, buff, nb_chars, "line") || lua_pcall(L, 0, 0, 0);
        if (error) {
            xprint(lua_tostring(L, -1));
            xprint("\n");
            lua_pop(L, 1);
        }
    }

    lua_close(L);
}
