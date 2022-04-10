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

    input  wire logic       gn0,    // C2
    input  wire logic       gn1,    // C1
    input  wire logic       gn2,    // D2
    input  wire logic       gn3     // D1
    );

    localparam USB_REPORT_NB_BYTES = 8;


    // reset
    logic auto_reset;
    logic [5:0] auto_reset_counter = 0;
    logic reset;

    logic [7:0] display;

    logic clk_pix, clk_1x, clk_10x;
    logic clk_locked;

    pll_ecp5 #(
        .ENABLE_FAST_CLK(0)
    ) pll_main (
        .clk_25m(clk_25mhz),
        .locked(clk_locked),
        .clk_1x(clk_1x),
        .clk_2x(clk_pix),
        .clk_10x(clk_10x)
    );

    logic [3:0] vga_r;                      // vga red (4-bit)
    logic [3:0] vga_g;                      // vga green (4-bits)
    logic [3:0] vga_b;                      // vga blue (4-bits)
    logic       vga_hsync;                  // vga hsync
    logic       vga_vsync;                  // vga vsync
    logic       vga_de;                     // vga data enable


    hdmi_encoder hdmi(
        .pixel_clk(clk_pix),
        .pixel_clk_x5(clk_10x),

        .red({2{vga_r}}),
        .green({2{vga_g}}),
        .blue({2{vga_b}}),

        .vde(vga_de),
        .hsync(vga_hsync),
        .vsync(vga_vsync),

        .gpdi_dp(gpdi_dp),
        .gpdi_dn(gpdi_dn)
    );    

    soc #(
        .FREQ_HZ(25000000),
        .BAUDS(115200),
        .RAM_SIZE(256*1024)
    ) soc(
        .clk(clk_pix),
`ifdef VGA        
        .clk_pix(clk_pix),
`endif
        .reset_i(reset),
        .display_o(display),
        .rx_i(ftdi_txd),
        .tx_o(ftdi_rxd),
`ifdef VGA
        .vga_hsync_o(vga_hsync),
        .vga_vsync_o(vga_vsync),
        .vga_r_o(vga_r),
        .vga_g_o(vga_g),
        .vga_b_o(vga_b),
        .vga_de_o(vga_de),
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
        .ps2_kbd_err_i(ps2_kbd_err)
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

    // ps/2

    logic ps2_clk;
    logic ps2_data;

    logic [7:0] ps2_kbd_code;
    logic       ps2_kbd_strobe;
    logic       ps2_kbd_err;

    assign ps2_clk = gn1;
    assign ps2_data = gn3;

    ps2kbd ps2_kbd(
        .clk(clk_25mhz),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .ps2_code(ps2_kbd_code),
        .strobe(ps2_kbd_strobe),
        .err(ps2_kbd_err)
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