module top(
    input  wire logic       CLK,
    input  wire logic       BTN_N,
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

    xgsoc #(
        .FREQ_HZ(12000000),
        .BAUDS(115200)
    ) xgsoc(
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

endmodule