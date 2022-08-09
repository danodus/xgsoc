#include "../lib/custom_ops.S"

    .section .text
    .global _start
    .global sysinit
    .global main
    .global counter

_start:
    j start

.balign 16
irq:
    addi sp,sp,-8
    sw a5,0(sp)
    sw a4,4(sp)

    lui a5,%hi(counter)
    addi a5,a5,%lo(counter)

    lw a4,0(a5)
    addi a4,a4,1
    sw a4,0(a5)

    lw a5,0(sp)
    lw a4,4(sp)
    addi sp,sp,8
    ret

counter:
    .word 0x00000000

start:
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

    jal ra,sysinit

    xgsoc_maskirq_insn(zero);
    jal ra,main

    lui a0,0
    jalr zero,a0,0
