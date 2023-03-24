module top(
    input  wire logic       CLK,
    input  wire logic       BTN_N,

    // UART
    input  wire logic       RX,
    output      logic       TX,

    // Display
    output      logic       LEDR_N,
    output      logic       LEDG_N,

    // SD Card
    output      logic        P2_1, // sd_csn
    output      logic        P2_2, // sd_mosi,
    input  wire logic        P2_3, // sd_miso,
    output      logic        P2_4  // sd_clk
    );

    // reset
    logic auto_reset;
    logic [5:0] auto_reset_counter = 0;
    logic reset;

    logic [7:0] display;

    assign {LEDR_N, LEDG_N} = ~display[1:0];

    xgsoc #(
        .FREQ_HZ(12000000),
        .BAUDS(230400)
    ) xgsoc(
        .clk(CLK),
        .reset_i(reset),
        .display_o(display),
        .rx_i(RX),
        .tx_o(TX),
`ifdef SD_CARD
        .sd_csn_o(P2_1),
        .sd_sclk_o(P2_4),
        .sd_miso_i(P2_3),
        .sd_mosi_o(P2_2),
`endif
    );

    // reset
    assign auto_reset = auto_reset_counter < 5'b11111;
    assign reset = auto_reset || !BTN_N;

	always @(posedge CLK) begin
        auto_reset_counter <= auto_reset_counter + auto_reset;
	end

endmodule