module top(
    input  wire logic       clk_25mhz,
    input  wire logic [6:0] btn,
    output      logic [7:0] led,
    input  wire logic       ftdi_rxd,
    output      logic       ftdi_txd
    );

    // reset
    logic auto_reset;
    logic [5:0] auto_reset_counter = 0;
    logic reset;

    logic [7:0] display;

    soc #(
        .FREQ_MHZ(25),
        .BAUDS(115200)
    ) soc(
        .clk(clk_25mhz),
        .reset_i(reset),
        .display_o(display),
        .rx_i(ftdi_rxd),
        .tx_o(ftdi_txd)
    );

    // reset
    assign auto_reset = auto_reset_counter < 5'b11111;
    assign reset = auto_reset || !btn[0];

	always @(posedge clk_25mhz) begin
		auto_reset_counter <= auto_reset_counter + auto_reset;
	end

    // display
    always_comb begin
        led = display;
    end


endmodule