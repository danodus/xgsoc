#include <custom_ops.S>

    .section .text
    .global _start
    .global sysinit
    .global main
    .global counter
    .global irq1_handler
    .global ecall_handler
    .global ebreak_handler

_start:
    j start

.balign 16
irq0_vec:
    j irq0

irq1_vec:
    j irq1

ecall_vec:
    j ecall

ebreak_vec:
    j ebreak

irq0:
    addi sp,sp,-8
    sw a5,4(sp)
    sw a4,0(sp)

    lui a5,%hi(counter)
    addi a5,a5,%lo(counter)

    lw a4,0(a5)
    addi a4,a4,1
    sw a4,0(a5)

    lw a4,0(sp)
    lw a5,4(sp)
    addi sp,sp,8
    mret

irq1:
    addi sp,sp,-12
    sw a5,8(sp)
    sw a4,4(sp)
    sw ra,0(sp)

    lui a5,%hi(irq1_handler)
    addi a5,a5,%lo(irq1_handler)

    lw a4,0(a5)
    beq a4,zero,irq1_0;
    jalr ra,0(a4)
irq1_0:
    lw ra,0(sp)
    lw a4,4(sp)
    lw a5,8(sp)
    addi sp,sp,12
    mret

ecall:
    addi sp,sp,-4
    sw ra,0(sp)

    lui t0,%hi(ecall_handler)
    addi t0,t0,%lo(ecall_handler)

    lw t1,0(t0)
    beq t1,zero,ecall_0;
    jalr ra,0(t1)
ecall_0:
    lw ra,0(sp)
    addi sp,sp,4
    sret

ebreak:
    addi sp,sp,-12
    sw a5,8(sp)
    sw a4,4(sp)
    sw ra,0(sp)

    lui a5,%hi(ebreak_handler)
    addi a5,a5,%lo(ebreak_handler)

    lw a4,0(a5)
    beq a4,zero,ebreak_0;
    jalr ra,0(a4)
ebreak_0:
    lw ra,0(sp)
    lw a4,4(sp)
    lw a5,8(sp)
    addi sp,sp,12
    sret

counter:
    .word 0x00000000
irq1_handler:
    .word 0x00000000
ecall_handler:
    .word 0x00000000
ebreak_handler:
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
    jal ra,main

    lui a0,0
    jalr zero,a0,0
