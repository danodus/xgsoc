// top.sv
// Copyright (c) 2022-2023 Daniel Cliche
// SPDX-License-Identifier: MIT

module top(
    input  wire logic       clk_25mhz,
    input  wire logic [6:0] btn,
    output      logic [7:0] led,
    input  wire logic       ftdi_txd,
    output      logic       ftdi_rxd,

    output      logic [3:0] gpdi_dp,
    output      logic [3:0] gpdi_dn,
    output      logic [3:0] audio_l, audio_r,

    input  wire logic       usb_fpga_dp,
    inout  wire logic       usb_fpga_bd_dp,
    inout  wire logic       usb_fpga_bd_dn,
    output      logic       usb_fpga_pu_dp,
    output      logic       usb_fpga_pu_dn,

    inout  wire logic       gn0,    // C2
    input  wire logic       gn1,    // C1
    inout  wire logic       gn2,    // D2
    input  wire logic       gn3,    // D1

    // SD Card
    output      logic        sd_clk,
    inout       logic        sd_cmd,
    inout       logic [3:0]  sd_d,

    // Flash
    output      logic        flash_csn,
    input  wire logic        flash_miso,
    output      logic        flash_mosi,
    output      logic        flash_wpn,
    output      logic        flash_holdn,              // flash_holdn

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

    localparam USB_REPORT_NB_BYTES = 8;


    // reset
    logic auto_reset;
    logic [5:0] auto_reset_counter = 0;
    logic reset;

    logic [7:0] display;

    logic clk_pix, clk_pix_x5, clk_sdram;
    logic clk_locked;

    generated_pll_main pll_main(
        .clkin(clk_25mhz),
        .clkout0(clk_sdram),
        .clkout2(),
        .locked(clk_locked)
    );

    generated_pll_video pll_video(
        .clkin(clk_25mhz),
        .clkout0(clk_pix_x5),
        .clkout2(clk_pix),
        .locked()
    );

    logic [3:0] vga_r;                      // vga red (4-bit)
    logic [3:0] vga_g;                      // vga green (4-bits)
    logic [3:0] vga_b;                      // vga blue (4-bits)
    logic       vga_hsync;                  // vga hsync
    logic       vga_vsync;                  // vga vsync
    logic       vga_de;                     // vga data enable


    hdmi_encoder hdmi(
        .pixel_clk(clk_pix),
        .pixel_clk_x5(clk_pix_x5),

        .red({2{vga_r}}),
        .green({2{vga_g}}),
        .blue({2{vga_b}}),

        .vde(vga_de),
        .hsync(vga_hsync),
        .vsync(vga_vsync),

        .gpdi_dp(gpdi_dp),
        .gpdi_dn(gpdi_dn)
    );    

    logic flash_sclk;
    USRMCLK u1 (.USRMCLKI(flash_sclk), .USRMCLKTS(1'b0));

    assign flash_wpn = 1'b1;     // disable write protect
    assign flash_holdn = 1'b1;     // disable hold

    xgsoc #(
        .FREQ_HZ(33_750_000),
        .BAUDS(230400),
        .RAM_SIZE(128*1024),    // must be a power of 2
        .SDRAM_CLK_FREQ_MHZ(75)
    ) xgsoc(
        .clk(clk_pix),
        .clk_sdram(clk_sdram),
        .clk_pix(clk_pix),
        .reset_i(reset),
        .display_o(display),
        .rx_i(ftdi_txd),
        .tx_o(ftdi_rxd),
        .vga_hsync_o(vga_hsync),
        .vga_vsync_o(vga_vsync),
        .vga_r_o(vga_r),
        .vga_g_o(vga_g),
        .vga_b_o(vga_b),
        .vga_de_o(vga_de),
`ifdef XGA
        .audio_l_o(audio_l[3]),
        .audio_r_o(audio_r[3]),
`endif
`ifdef USB
        .usb_report_i(usb_report),
        .usb_report_valid_i(usb_report_valid),
`endif
`ifdef PS2
        .ps2_kbd_code_i(ps2_kbd_code),
        .ps2_kbd_strobe_i(ps2_kbd_strobe),
        .ps2_kbd_err_i(ps2_kbd_err),
        .ps2_mouse_btn_i(ps2_mouse_btn),
        .ps2_mouse_x_i(ps2_mouse_x),
        .ps2_mouse_y_i(ps2_mouse_y),
`endif
`ifdef SD_CARD
        .sd_csn_o(sd_d[3]),
        .sd_sclk_o(sd_clk),
        .sd_miso_i(sd_d[0]),
        .sd_mosi_o(sd_cmd),
`endif
`ifdef FLASH
        .flash_csn_o(flash_csn),
        .flash_sclk_o(flash_sclk),
        .flash_miso_i(flash_miso),
        .flash_mosi_o(flash_mosi),
`endif
`ifdef SDRAM
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
`endif        
    );

    assign audio_l[2:0] = 3'd0;
    assign audio_r[2:0] = 3'd0;

    // reset
    assign auto_reset = auto_reset_counter < 5'b11111;
    assign reset = auto_reset || !btn[0];

	always @(posedge clk_pix) begin
        if (clk_locked)
		    auto_reset_counter <= auto_reset_counter + auto_reset;
	end

    // display
    always_comb begin
        led = display;
    end

    // ps/2 keyboard

    logic ps2_clk;
    logic ps2_data;

    logic [7:0] ps2_kbd_code;
    logic       ps2_kbd_strobe;
    logic       ps2_kbd_err;

    assign ps2_clk = gn1;
    assign ps2_data = gn3;

    ps2kbd ps2_kbd(
        .clk(clk_pix),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .ps2_code(ps2_kbd_code),
        .strobe(ps2_kbd_strobe),
        .err(ps2_kbd_err)
    );

    // ps/2 mouse

    logic ps2_mdat_in, ps2_mclk_in, ps2_mdat_out, ps2_mclk_out;
    assign gn0 = ps2_mclk_out ? 1'bz : 1'b0;
    assign gn2 = ps2_mdat_out ? 1'bz : 1'b0;
    assign ps2_mclk_in = gn0;
    assign ps2_mdat_in = gn2;

    logic [15:0] ps2_mouse_x, ps2_mouse_y;
    logic [2:0] ps2_mouse_btn;

    ps2mouse
    #(
        .c_x_bits(16),
        .c_y_bits(16)
    )
    ps2mouse
    (
        .clk(clk_pix),
        .reset(reset),
        .ps2mdati(ps2_mdat_in),
        .ps2mclki(ps2_mclk_in),
        .ps2mdato(ps2_mdat_out),
        .ps2mclko(ps2_mclk_out),
        .xcount(ps2_mouse_x),
        .ycount(ps2_mouse_y),
        .btn(ps2_mouse_btn)
    );

    //
    // USB
    //

    logic clk_usb;  // 6 MHz
    logic pll_locked_usb;

    generated_pll_usb pll_usb(
        .clkin(clk_25mhz),

        .clkout1(clk_usb),
        .locked(pll_locked_usb)
    );
    
    logic [USB_REPORT_NB_BYTES * 8 - 1:0] usb_report;
    logic usb_report_valid;

    usbh_host_hid #(
        .C_usb_speed(0),
        .C_report_length(USB_REPORT_NB_BYTES),
        .C_report_length_strict(0)
    ) us2_hid_host (
        .clk(clk_usb),
        .bus_reset(reset),
        .usb_dif(usb_fpga_dp),
        .usb_dp(usb_fpga_bd_dp),
        .usb_dn(usb_fpga_bd_dn),
        .hid_report(usb_report),
        .hid_valid(usb_report_valid)
    );

    assign usb_fpga_pu_dp = 1'b0;
    assign usb_fpga_pu_dn = 1'b0;

endmodule