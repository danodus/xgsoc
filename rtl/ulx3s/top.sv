module top(
    input  wire logic       clk_25mhz,
    input  wire logic [6:0] btn,
    output      logic [7:0] led,
    input  wire logic       ftdi_txd,
    output      logic       ftdi_rxd,

    input  wire logic       usb_fpga_dp,
    inout  wire logic       usb_fpga_bd_dp,
    inout  wire logic       usb_fpga_bd_dn,
    output      logic       usb_fpga_pu_dp,
    output      logic       usb_fpga_pu_dn
    );

    localparam USB_REPORT_NB_BYTES = 8;


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
        .rx_i(ftdi_txd),
        .tx_o(ftdi_rxd),
        .usb_report_i(usb_report),
        .usb_report_valid_i(usb_report_valid)
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

    //
    // USB
    //

    logic clk_usb;  // 6 MHz
    logic pll_locked_usb;

    generated_pll_usb pll_usb(
        .clkin(clk_25mhz),

        .clkout1(clk_usb),
        .locked(pll_locked_usb)
    );
    
    logic [USB_REPORT_NB_BYTES * 8 - 1:0] usb_report;
    logic usb_report_valid;

    usbh_host_hid #(
        .C_usb_speed(0),
        .C_report_length(USB_REPORT_NB_BYTES),
        .C_report_length_strict(0)
    ) us2_hid_host (
        .clk(clk_usb),
        .bus_reset(reset),
        .usb_dif(usb_fpga_dp),
        .usb_dp(usb_fpga_bd_dp),
        .usb_dn(usb_fpga_bd_dn),
        .hid_report(usb_report),
        .hid_valid(usb_report_valid)
    );

    assign usb_fpga_pu_dp = 1'b0;
    assign usb_fpga_pu_dn = 1'b0;

endmodule