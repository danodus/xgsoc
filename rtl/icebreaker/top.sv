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
    output      logic        P1A1,//P2_1, // sd_csn
    output      logic        P1A2,//P2_2, // sd_mosi,
    input  wire logic        P1A3,//P2_3, // sd_miso,
    output      logic        P1A4,//P2_4,  // sd_clk

    // PS/2 Keyboard
    input       logic        P2_1, // ps2_kb_dat
    inout       logic        P2_2, // ps2_ms_dat
    input       logic        P2_3, // ps2_kb_clk
    inout       logic        P2_4  // ps2_ms_clk
    );

    // reset
    logic auto_reset;
    logic [5:0] auto_reset_counter = 0;
    logic reset;

    logic [7:0] display;

    assign {LEDR_N, LEDG_N} = ~display[1:0];

    // ps/2 keyboard

    logic ps2_clk;
    logic ps2_data;

    logic [7:0] ps2_kbd_code;
    logic       ps2_kbd_strobe;
    logic       ps2_kbd_err;

    assign ps2_clk = P1A3;
    assign ps2_data = P1A1;

    ps2kbd ps2_kbd(
        .clk(CLK),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .ps2_code(ps2_kbd_code),
        .strobe(ps2_kbd_strobe),
        .err(ps2_kbd_err)
    );

    // ps/2 mouse

    logic ps2_mdat_in, ps2_mclk_in, ps2_mdat_out, ps2_mclk_out;
    assign P2_4 = ps2_mclk_out ? 1'bz : 1'b0;
    assign P2_2 = ps2_mdat_out ? 1'bz : 1'b0;
    assign ps2_mclk_in = P2_4;
    assign ps2_mdat_in = P2_2;

    logic [15:0] ps2_mouse_x, ps2_mouse_y;
    logic [2:0] ps2_mouse_btn;

    ps2mouse
    #(
        .c_x_bits(16),
        .c_y_bits(16)
    )
    ps2mouse
    (
        .clk(CLK),
        .reset(reset),
        .ps2mdati(ps2_mdat_in),
        .ps2mclki(ps2_mclk_in),
        .ps2mdato(ps2_mdat_out),
        .ps2mclko(ps2_mclk_out),
        .xcount(ps2_mouse_x),
        .ycount(ps2_mouse_y),
        .btn(ps2_mouse_btn)
    );    


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
        .sd_csn_o(P1A1),
        .sd_sclk_o(P1A4),
        .sd_miso_i(P1A3),
        .sd_mosi_o(P1A2),
`endif
`ifdef PS2
        .ps2_kbd_code_i(ps2_kbd_code),
        .ps2_kbd_strobe_i(ps2_kbd_strobe),
        .ps2_kbd_err_i(ps2_kbd_err),
        .ps2_mouse_btn_i(ps2_mouse_btn),
        .ps2_mouse_x_i(ps2_mouse_x),
        .ps2_mouse_y_i(ps2_mouse_y),
`endif
    );

    // reset
    assign auto_reset = auto_reset_counter < 5'b11111;
    assign reset = auto_reset || !BTN_N;

	always @(posedge CLK) begin
        auto_reset_counter <= auto_reset_counter + auto_reset;
	end

endmodule