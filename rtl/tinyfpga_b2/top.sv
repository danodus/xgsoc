module top(
    input  wire logic pin3_clk_16mhz,
    output      logic pin21,  // PMOD rts
    output      logic pin20,  // PMOD rxd
    input  wire logic pin19,  // PMOD txd
    output      logic pin18,  // PMOD cts
    output      logic pin6,
    output      logic pin7,
    output      logic pin8,
    output      logic pin9,
    output      logic pin10,
    output      logic pin11,
    output      logic pin12,
    output      logic pin13
    );

    // reset
    logic auto_reset;
    logic [5:0] auto_reset_counter = 0;
    logic reset;

    logic [7:0] display;

    soc #(
        .FREQ_MHZ(16),
        .BAUDS(115200)
    ) soc(
        .clk(pin3_clk_16mhz),
        .reset_i(reset),
        .display_o(display),
        .rx_i(pin19),
        .tx_o(pin20)
    );

    // reset
    assign auto_reset = auto_reset_counter < 5'b11111;
    assign reset = auto_reset;

	always @(posedge pin3_clk_16mhz) begin
		auto_reset_counter <= auto_reset_counter + auto_reset;
	end

    // display
    always_comb begin
        {pin6, pin7, pin8, pin9, pin10, pin11, pin12, pin13} = display;
        pin21 = 1'b1;
        pin18 = 1'b1;
    end

endmodule