module top(
    input  wire logic  CLK,
    input  wire logic  BTN_N,
    output      logic P1B1, P1B2, P1B3, P1B4, P1B7, P1B8, P1B9, P1B10,
    input  wire logic RX,
    output      logic TX
    );

    // reset
    logic auto_reset;
    logic [5:0] auto_reset_counter = 0;
    logic reset;

    logic [7:0] display;

    soc #(
        .FREQ_MHZ(12),
        .BAUDS(115200)
    ) soc(
        .clk(CLK),
        .reset_i(reset),
        .display_o(display),
        .rx_i(RX),
        .tx_o(TX)
    );

    // reset
    assign auto_reset = auto_reset_counter < 5'b11111;
    assign reset = auto_reset || !BTN_N;

	always @(posedge CLK) begin
		auto_reset_counter <= auto_reset_counter + auto_reset;
	end

    // display
    always_comb begin
        {P1B1, P1B2, P1B3, P1B4, P1B7, P1B8, P1B9, P1B10} = display;
    end


endmodule