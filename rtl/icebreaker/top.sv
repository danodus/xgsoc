module top(
    input  wire logic       CLK,
    input  wire logic       BTN_N,
    output      logic       P1A1, P1A2, P1A3, P1A4, P1A7, P1A8, P1A9, P1A10,   // PMOD 1A
    output      logic       P1B1, P1B2, P1B3, P1B4, P1B7, P1B8, P1B9, P1B10,   // PMOD 1B
    input  wire logic       RX,
    output      logic       TX,
    output      logic [4:0] LED 
    );

    // reset
    logic auto_reset;
    logic [5:0] auto_reset_counter = 0;
    logic reset;

    logic [7:0] display;

    assign LED[4:0] = display[4:0];

    logic clk_pix, clk_pix_half;
    logic clk_locked;

    logic [3:0] vga_r;                      // vga red (4-bit)
    logic [3:0] vga_g;                      // vga green (4-bits)
    logic [3:0] vga_b;                      // vga blue (4-bits)
    logic       vga_hsync;                  // vga hsync
    logic       vga_vsync;                  // vga vsync

    assign {P1A1, P1A2, P1A3, P1A4, P1A7, P1A8, P1A9, P1A10} =
       {vga_r[0], vga_r[1], vga_r[2], vga_r[3], vga_b[0], vga_b[1], vga_b[2], vga_b[3]};
    assign {P1B1, P1B2, P1B3, P1B4, P1B7, P1B8, P1B9, P1B10} =
       {vga_g[0], vga_g[1], vga_g[2], vga_g[3], vga_hsync, vga_vsync, 1'b0, 1'b0};

    // clock gen
    clock_gen_480p clock_gen_480p(
        .clk(CLK),
        .rst(BTN_N),
        .clk_pix(clk_pix),
        .clk_pix_half(clk_pix_half),
        .clk_locked(clk_locked)
    );

    soc #(
        .FREQ_HZ(25125000 / 2),
        .BAUDS(115200)
    ) soc(
        .clk(clk_pix_half),
        .clk_pix(clk_pix),
        .reset_i(reset),
        .display_o(display),
        .rx_i(RX),
        .tx_o(TX),
        .vga_hsync_o(vga_hsync),
        .vga_vsync_o(vga_vsync),
        .vga_r_o(vga_r),
        .vga_g_o(vga_g),
        .vga_b_o(vga_b)
    );

    // reset
    assign auto_reset = auto_reset_counter < 5'b11111;
    assign reset = auto_reset || !BTN_N || !clk_locked;

	always @(posedge clk_pix_half) begin
        if (clk_locked)        
            auto_reset_counter <= auto_reset_counter + auto_reset;
	end

endmodule