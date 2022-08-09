#include "../lib/custom_ops.S"

    .section .text
    .global _start
    .global main

reset_vec:
    // no more than 16 bytes
    j _start

.balign 16
irq_vec:
    addi sp,sp,-8
    sw s2,4(sp)
    sw ra,0(sp)

    lui s2,0x10000
    addi s2,s2,0x10
    jalr ra,0(s2)

    lw ra,0(sp)
    lw s2,4(sp)
    addi sp,sp,8

    xgsoc_retirq_insn()

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
    j loop
