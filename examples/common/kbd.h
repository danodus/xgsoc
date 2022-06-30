#ifndef KBD_H
#define KBD_H

#include <stdint.h>

#define KBD_IS_EXTENDED(_c_) (_c_ & 0x8000)

#define KBD_UP          0x8075
#define KBD_DOWN        0x8072
#define KBD_LEFT        0x806B
#define KBD_RIGHT       0x8074

#define KBD_HOME        0x806C
#define KBD_END         0x8069

#define KBD_INSERT      0x8070
#define KBD_DELETE      0x8071

#define KBD_PAGE_DOWN   0x807A
#define KBD_PAGE_UP     0x807D

#define KBD_F1          0x8105
#define KBD_F2          0x8106
#define KBD_F3          0x8104
#define KBD_F4          0x810C
#define KBD_F5          0x8103
#define KBD_F6          0x810B
#define KBD_F7          0x8183
#define KBD_F8          0x810A
#define KBD_F9          0x8101
#define KBD_F10         0x8109
#define KBD_F11         0x8178
#define KBD_F12         0x8107

#ifdef __cplusplus
extern "C" {
#endif

uint16_t kbd_get_char();

#ifdef __cplusplus
}
#endif

#endif // KBD_H
