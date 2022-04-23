module top(
    input  wire logic       clk_100mhz_p,
    input  wire logic       BTN,
    output      logic [1:0] led,
    input  wire logic       UART1_RXD,
    output      logic       UART1_TXD
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
        .tx_o(UART1_TXD)
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

endmodule