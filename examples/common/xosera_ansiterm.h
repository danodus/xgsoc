/*
 * vim: set et ts=4 sw=4
 *------------------------------------------------------------
 *                                  ___ ___ _
 *  ___ ___ ___ ___ ___       _____|  _| . | |_
 * |  _| . |_ -|  _| . |     |     | . | . | '_|
 * |_| |___|___|___|___|_____|_|_|_|___|___|_,_|
 *                     |_____|
 *  __ __
 * |  |  |___ ___ ___ ___ ___
 * |-   -| . |_ -| -_|  _| .'|
 * |__|__|___|___|___|_| |__,|
 *
 * ------------------------------------------------------------
 * Copyright (c) 2021 Xark & contributors
 * MIT License
 *
 * rosco_m68k + Xosera VT100/ANSI terminal driver
 * Based on info from:
 *  https://vt100.net/docs/vt100-ug/chapter3.html#S3.3.6.1
 *  https://misc.flogisoft.com/bash/tip_colors_and_formatting
 *  (and various other sources)
 * ------------------------------------------------------------
 */

#ifndef XOSERA_ANSITERM_H
#define XOSERA_ANSITERM_H

#include <stdbool.h>

#define XANSI_TERMINAL_REVISION 0        // increment when XANSI feature/bugfix applied

// external terminal functions
bool         xansiterm_INIT(void);                       // initialize xansiterm (called from XANSI_CON_INIT)
void         xansiterm_PRINTCHAR(char c);                // EFP output char routine
void         xansiterm_CLRSCR(void);                     // EFP clear screen
void         xansiterm_SETCURSOR(bool enable);           // EFP enable/disable cursor
void         xansiterm_UPDATECURSOR(void);
char         xansiterm_RECVQUERY(void);

#endif // XOSERA_ANSITERM.H
