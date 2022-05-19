module top(
    input  wire logic       clk_100mhz_p,
    input  wire logic       BTN,
    output      logic [1:0] led,
    input  wire logic       UART1_RXD,
    output      logic       UART1_TXD,
    input  wire logic       PMOD_PS2_K_CLK,
    input  wire logic       PMOD_PS2_K_DATA,

    input  wire logic [3:0] HEX,

    // Digital Video (differential outputs)
    output      logic [3:0] dio_p,

    output      logic       AUDIO_L,
    output      logic       AUDIO_R,

    // SDRAM
    output      logic        sdram_clk,
    output      logic        sdram_cke,
    output      logic        sdram_csn,
    output      logic        sdram_wen,
    output      logic        sdram_rasn,
    output      logic        sdram_casn,
    output      logic [12:0] sdram_a,
    output      logic [1:0]  sdram_ba,
    output      logic [1:0]  sdram_dqm,
    inout       logic [15:0] sdram_d  
);

    // reset
    logic auto_reset;
    logic [5:0] auto_reset_counter = 0;
    logic reset;

    logic [7:0] display;

    logic clk, clk_x5, clk_sdram;
    logic clk_locked;

    pll pll (
        .clkin(clk_100mhz_p),
        .locked(clk_locked),
        .clkout0(clk_x5),
        .clkout2(clk),
        .clkout3(clk_sdram)
    );

    logic [3:0] vga_r;                      // vga red (4-bit)
    logic [3:0] vga_g;                      // vga green (4-bits)
    logic [3:0] vga_b;                      // vga blue (4-bits)
    logic       vga_hsync;                  // vga hsync
    logic       vga_vsync;                  // vga vsync
    logic       vga_de;                     // vga data enable

    hdmi_encoder hdmi(
        .pixel_clk(clk),
        .pixel_clk_x5(clk_x5),

        .red({2{vga_r}}),
        .green({2{vga_g}}),
        .blue({2{vga_b}}),

        .vde(vga_de),
        .hsync(vga_hsync),
        .vsync(vga_vsync),

        .gpdi_dp(dio_p),
        .gpdi_dn()
    );    

    soc #(
        .FREQ_HZ(25_000_000),
        .BAUDS(115200),
        .RAM_SIZE(240*1024),
        .SDRAM_CLK_FREQ_MHZ(78)
    ) soc(
        .clk(clk),
        .clk_sdram(clk_sdram),
`ifdef VGA        
        .clk_pix(clk),
`endif
        .reset_i(reset),
        .display_o(display),
        .rx_i(UART1_RXD),
        .tx_o(UART1_TXD),
`ifdef VGA
        .vga_hsync_o(vga_hsync),
        .vga_vsync_o(vga_vsync),
        .vga_r_o(vga_r),
        .vga_g_o(vga_g),
        .vga_b_o(vga_b),
        .vga_de_o(vga_de),
        .audio_l_o(AUDIO_L),
        .audio_r_o(AUDIO_R),
`endif
`ifdef PS2
        .ps2_kbd_code_i(ps2_kbd_code),
        .ps2_kbd_strobe_i(ps2_kbd_strobe),
        .ps2_kbd_err_i(ps2_kbd_err),
`endif

        // SDRAM
        .sdram_clk_o(sdram_clk),
        .sdram_cke_o(sdram_cke),
        .sdram_cs_n_o(sdram_csn),
        .sdram_we_n_o(sdram_wen),
        .sdram_ras_n_o(sdram_rasn),
        .sdram_cas_n_o(sdram_casn),
        .sdram_a_o(sdram_a),
        .sdram_ba_o(sdram_ba),
        .sdram_dqm_o(sdram_dqm),
        .sdram_dq_io(sdram_d)
    );

    // reset
    assign auto_reset = auto_reset_counter < 5'b11111;
    assign reset = auto_reset || (BTN && HEX == 4'd1);

	always @(posedge clk) begin
        if (clk_locked)
		    auto_reset_counter <= auto_reset_counter + auto_reset;
	end

    // display
    always_comb begin
        led = display[1:0];
    end

    // ps/2

    logic [7:0] ps2_kbd_code;
    logic       ps2_kbd_strobe;
    logic       ps2_kbd_err;

    ps2kbd ps2_kbd(
        .clk(clk),
        .ps2_clk(PMOD_PS2_K_CLK),
        .ps2_data(PMOD_PS2_K_DATA),
        .ps2_code(ps2_kbd_code),
        .strobe(ps2_kbd_strobe),
        .err(ps2_kbd_err)
    );    

endmodule