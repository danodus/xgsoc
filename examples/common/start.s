    .section .text
    .global _start
    .global main

_start:

    add x1,x0,x0
    add x2,x0,x0
    add x3,x0,x0
    add x4,x0,x0
    add x5,x0,x0
    add x6,x0,x0
    add x7,x0,x0
    add x8,x0,x0
    add x9,x0,x0
    add x10,x0,x0
    add x11,x0,x0
    add x12,x0,x0
    add x13,x0,x0
    add x14,x0,x0
    add x15,x0,x0
    
    lui sp, %hi(__stacktop);
    addi sp, sp, %lo(__stacktop);

    jal ra,main
loop:
    lui a0,0
    addi a0,x0,0
    jalr x0,a0,0
