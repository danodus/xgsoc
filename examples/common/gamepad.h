#ifndef GAMEPAD_H
#define GAMEPAD_H

#define BUTTON_A_MASK              0x00000001
#define BUTTON_B_MASK              0x00000002
#define BUTTON_X_MASK              0x00000004
#define BUTTON_Y_MASK              0x00000008
#define BUTTON_UP_MASK             0x00000010
#define BUTTON_DOWN_MASK           0x00000020
#define BUTTON_LEFT_MASK           0x00000040
#define BUTTON_RIGHT_MASK          0x00000080
#define BUTTON_SHOULDER_LEFT_MASK  0x00000100
#define BUTTON_SHOULDER_RIGHT_MASK 0x00000200
#define BUTTON_SELECT_MASK         0x00000400
#define BUTTON_START_MASK          0x00000800

void read_gamepad(unsigned int *report_msw, unsigned int *report_lsw);
unsigned int get_buttons_kiwitata(unsigned int report_msw, unsigned int report_lsw);

#endif // GAMEPAD_H

