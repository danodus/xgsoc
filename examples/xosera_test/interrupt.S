    .section .text
    .global xosera_irq_handler
    .global frame_counter

xosera_irq_handler:
    addi sp,sp,-8
    sw a5,4(sp)
    sw a4,0(sp)

    // increase frame counter
    lui a5,%hi(frame_counter)
    addi a5,a5,%lo(frame_counter)
    lw a4,0(a5)
    addi a4,a4,1
    sw a4,0(a5)

    // clear VSYNC interrupt
    lui a5,0x20003
    addi a5,a5,0x100
    li a4,8
    sw a4,16*0x9(a5)        // XM_TIMER

    lw a4,0(sp)
    lw a5,4(sp)
    addi sp,sp,8
    ret

frame_counter:
    .word 0x00000000