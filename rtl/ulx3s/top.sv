module top(
    input  wire logic       clk_25mhz,
    input  wire logic [6:0] btn,
    output      logic [7:0] led,
    input  wire logic       ftdi_txd,
    output      logic       ftdi_rxd,
    output      logic [3:0] gpdi_dp,
    output      logic [3:0] gpdi_dn    
    );

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
        .vga_de_o(vga_de)
    );

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


endmodule