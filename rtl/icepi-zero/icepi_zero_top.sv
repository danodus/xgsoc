// icepi_zero_top.sv
// Copyright (c) 2026 Daniel Cliche
// SPDX-License-Identifier: MIT

// Based on the Oberon ULX3S design

module icepi_zero_top(
    // System clock and reset
    input  wire logic clk, // main clock input from external clock source

    // On-board user buttons and status LEDs
    input  wire logic [1:0] button,
    output      logic [4:0] led,

    // USB
    output      logic [1:0] usb_pull_dp, usb_pull_dn,
    inout       logic [1:0] usb_dp, usb_dn,  // USB

    // USB Slave (FT231x) interface 
    output      logic usb_tx,
    input  wire logic usb_rx,
     
    // SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
    output      logic        sdram_csn, 
    output      logic        sdram_clk,	 // clock to SDRAM
    output      logic        sdram_cke,  // clock enable to SDRAM	
    output      logic        sdram_rasn, // SDRAM RAS
    output      logic        sdram_casn, // SDRAM CAS
    output      logic        sdram_wen,	 // SDRAM write-enable
    output      logic [12:0] sdram_a,	 // SDRAM address bus
    output      logic [1:0]  sdram_ba,	 // SDRAM bank-address
    output      logic [1:0]  sdram_dqm,
    inout       logic [15:0] sdram_dq,	 // data bus to/from SDRAM	

`ifdef VIDEO
    // DVI interface
    output      logic [3:0] gpdi_dp,
`endif // VIDEO
     
    // SD/MMC Interface (Support either SPI or nibble-mode)
    inout logic       sd_clk, sd_cmd,
    inout logic [3:0] sd_dat,
);

	assign usb_pull_dp = 2'b01; 	// pull USB D+ to +3.3V through 1.5K resistor
	assign usb_pull_dn = 2'b01; 	// pull USB D- to +3.3V through 1.5K resistor

`ifdef VIDEO
`ifdef VIDEO_480P
    localparam pixel_clock_hz = 34_000_000; // DMT: 33.75MHz
`elsif VIDEO_720P
    localparam pixel_clock_hz = 75_000_000; // DMT: 74.25MHz
`elsif VIDEO_1080P
    localparam pixel_clock_hz = 75_000_000; // DMT: 74.25MHz
`else // VGA
    localparam pixel_clock_hz = 25_000_000; // DMT: 25MHz
`endif
`endif // VIDEO

    assign sdram_cke = 1'b1; // SDRAM clock enable
`ifdef VIDEO
    logic pll_video_locked;
    logic [3:0] clocks_video;
    ecp5pll
    #(
        .in_hz(50_000_000),
        .out0_hz(5*pixel_clock_hz),
        .out1_hz(pixel_clock_hz)
    )
    ecp5pll_video_inst
    (
        .clk_i(clk),
        .clk_o(clocks_video),
        .locked(pll_video_locked)
    );
    logic clk_pixel, clk_shift;
    assign clk_shift = clocks_video[0]; // 125 MHz
    assign clk_pixel = clocks_video[1]; // 25 MHz
`endif // VIDEO

    logic clk_cpu, clk_sdram;
    logic pll_main_locked;

    pll_main pll_main(
        .clkin(clk),
        .clkout0(clk_sdram),
        .clkout1(clk_cpu),
        .locked(pll_main_locked)
    );

    assign sdram_clk = ~clk_sdram;

`ifdef VIDEO
    logic vga_hsync, vga_vsync, vga_blank;
    logic [7:0] vga_r, vga_g, vga_b;
`endif // VIDEO

    logic pll_locked;
`ifdef VIDEO
    assign pll_locked = pll_main_locked & pll_video_locked;
`else // VIDEO
    assign pll_locked = pll_main_locked;
`endif // VIDEO

    logic [7:0] led8;
    assign led = led8[4:0];

    soc_top #(
        .FREQ_HZ(25_000_000),
        .BAUD_RATE(1_000_000)
    ) soc_top(
        .clk_cpu(clk_cpu),
        .clk_sdram(clk_sdram),
`ifdef VIDEO
        .clk_pixel(clk_pixel),
`endif // VIDEO
        .reset_i(!pll_locked | ~button[0]), // reset

        // UART
        .rx_i(usb_rx),
        .tx_o(usb_tx),
        // LED
        .led_o(led8),
        // SD card
        .sd_do_i(sd_dat[0]),
        .sd_di_o(sd_cmd),
        .sd_ck_o(sd_clk),
        .sd_cs_n_o(sd_dat[3]),
`ifdef VIDEO
        // VGA video
        .vga_hsync_o(vga_hsync),
        .vga_vsync_o(vga_vsync),
        .vga_blank_o(vga_blank),
        .vga_r_o(vga_r),
        .vga_g_o(vga_g),
        .vga_b_o(vga_b),
`endif // VIDEO
`ifdef PS2_KBD
        // PS/2 keyboard
        .ps2clka_i(usb_dp[0]),  // keyboard clock
        .ps2data_i(usb_dn[0]),  // keyboard data
`endif // PS2_KBD
`ifdef PS2_MOUSE
        // PS/2 mouse
        .ps2clkb_io(usb_dp[1]), // mouse clock
        .ps2datb_io(usb_dn[1]), // mouse data
`endif // PS2_MOUSE
        // SDRAM
        .sdram_cas_n_o(sdram_casn),
        .sdram_ras_n_o(sdram_rasn),
        .sdram_cs_n_o(sdram_csn),
        .sdram_we_n_o(sdram_wen),
        .sdram_ba_o(sdram_ba),
        .sdram_addr_o(sdram_a),
        .sdram_data_io(sdram_dq),
        .sdram_dqm_o(sdram_dqm)
    );

`ifdef VIDEO
    // VGA to digital video converter
    hdmi_interface hdmi_interface_instance(
      .pixel_clk(clk_pixel),
      .pixel_clk_x5(clk_shift),
      .red(vga_r),
      .green(vga_g),
      .blue(vga_b),
      .vde(~vga_blank),
      .hsync(vga_hsync),
      .vsync(vga_vsync),
      .gpdi_dp(gpdi_dp),
      .gpdi_dn()
    );
`endif // VIDEO

endmodule
