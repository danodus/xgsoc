module top(
    input  wire logic       clk_100mhz_p,
    input  wire logic       BTN,
    output      logic [1:0] led,
    input  wire logic       UART1_RXD,
    output      logic       UART1_TXD,
    input  wire logic       PMOD_PS2_K_CLK,
    input  wire logic       PMOD_PS2_K_DATA
);

    // reset
    logic auto_reset;
    logic [5:0] auto_reset_counter = 0;
    logic reset;

    logic [7:0] display;

    logic clk;
    logic clk_locked;

    pll pll (
        .clkin(clk_100mhz_p),
        .locked(clk_locked),
        .clkout0(clk)
    );

    soc #(
        .FREQ_HZ(25_000_000),
        .BAUDS(115200),
        .RAM_SIZE(256*1024)
    ) soc(
        .clk(clk),
        .reset_i(reset),
        .display_o(display),
        .rx_i(UART1_RXD),
        .tx_o(UART1_TXD),
`ifdef PS2
        .ps2_kbd_code_i(ps2_kbd_code),
        .ps2_kbd_strobe_i(ps2_kbd_strobe),
        .ps2_kbd_err_i(ps2_kbd_err)
`endif
    );

    // reset
    assign auto_reset = auto_reset_counter < 5'b11111;
    assign reset = auto_reset || BTN;

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