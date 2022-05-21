module top (
    input  wire logic       clk,
    input  wire logic       clk_sdram,
    input  wire logic       reset_i,
    output      logic [7:0] display_o,
    input  wire logic       rx_i,
    output      logic       tx_o,

    output logic vga_hsync,
    output logic vga_vsync,
    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b,

    input  wire logic [7:0]  ps2_kbd_code_i,
    input  wire logic        ps2_kbd_strobe_i,
    input  wire logic        ps2_kbd_err_i,

    // SDRAM
    output      logic        sdram_clk_o,
    output      logic        sdram_cke_o,
    output      logic        sdram_cs_n_o,
    output      logic        sdram_we_n_o,
    output      logic        sdram_ras_n_o,
    output      logic        sdram_cas_n_o,
    output      logic [12:0] sdram_a_o,
    output      logic [1:0]  sdram_ba_o,
    output      logic [1:0]  sdram_dqm_o,
    inout       logic [15:0] sdram_dq_io  
    );

    xgsoc #(
        .FREQ_HZ(1 * 1000000),
        .BAUDS(115200),
        .RAM_SIZE(240*1024)
    ) xgsoc(
        .clk(clk),
        .clk_sdram(clk_sdram),
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
        .sdram_clk_o,
        .sdram_cke_o,
        .sdram_cs_n_o,
        .sdram_we_n_o,
        .sdram_ras_n_o,
        .sdram_cas_n_o,
        .sdram_a_o,
        .sdram_ba_o,
        .sdram_dqm_o,
        .sdram_dq_io
    );
    
endmodule