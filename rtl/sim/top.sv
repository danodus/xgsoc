
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

module top #(
    parameter FREQ_MHZ = 12,
    parameter BAUDS    = 115200
    ) (
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
    output logic [3:0] vga_b
    );

    soc #(
        .FREQ_MHZ(1),
        .BAUDS(115200)
    ) soc(
        .clk(clk),
        .reset_i(reset_i),
        .display_o(display_o),
        .rx_i(),
        .tx_o()
    );
    
endmodule