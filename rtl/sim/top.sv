
/*

Ref.: https://projectf.io

640x480 Timings     HOR    VER
-------------------------------
Active Pixels       640     480
Front Porch         16      10
Sync Width          96      2
Back Porch          48      33
Blanking Total      160     45
Total Pixels        800     525
Sync Polarity       neg     neg

Pixel Clock @60Hz: 25.2 MHz

*/

/*
    0x00000000 - 0x00000FFF: memory
    0x00001000 - 0x00001FFF: display
    0x00002000 - 0x00002FFF: UART (BAUDS-N-8-1)
        0x0x00002000: Data Register (8 bits)
        0x0x00002004: Status Register (Read-only)
            bit 0: busy
            bit 1: valid
*/

module top (
    input  wire logic       clk,
    input  wire logic       reset_i,
    output      logic [7:0] display_o,
    input  wire logic       rx_i,
    output      logic       tx_o,

    input wire logic [3:0] sw,
    input wire logic btn_up,
    input wire logic btn_ctrl,
    input wire logic btn_dn,
    output logic vga_hsync,
    output logic vga_vsync,
    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b,

    input  wire logic [7:0]  ps2_kbd_code_i,
    input  wire logic        ps2_kbd_strobe_i,
    input  wire logic        ps2_kbd_err_i
    );

    soc #(
        .FREQ_HZ(1 * 1000000),
        .BAUDS(115200),
        .RAM_SIZE(256*1024)
    ) soc(
        .clk(clk),
        .clk_sdram(clk),
        .clk_pix(clk),
        .reset_i(reset_i),
        
        .display_o(display_o),

        .rx_i(),
        .tx_o(),

        .vga_hsync_o(vga_hsync),
        .vga_vsync_o(vga_vsync),
        .vga_r_o(vga_r),
        .vga_g_o(vga_g),
        .vga_b_o(vga_b),

        .ps2_kbd_code_i(ps2_kbd_code_i),
        .ps2_kbd_strobe_i(ps2_kbd_strobe_i),
        .ps2_kbd_err_i(),

        // SDRAM
        .sdram_clk_o(),
        .sdram_cke_o(),
        .sdram_cs_n_o(),
        .sdram_we_n_o(),
        .sdram_ras_n_o(),
        .sdram_cas_n_o(),
        .sdram_a_o(),
        .sdram_ba_o(),
        .sdram_dqm_o(),
        .sdram_dq_io()
    );
    
endmodule