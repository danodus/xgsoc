`timescale 1ns/1ps

module soc_tb;
    logic clk = 0;
    logic reset;
    logic [7:0] display;

    soc #(
        .FREQ_MHZ(1),
        .BAUDS(115200)
    ) soc(
        .clk(clk),
        .reset_i(reset),
        .display_o(display),
        .rx_i(),
        .tx_o()
    );


    initial begin
        $dumpfile("soc_tb.vcd");
        $dumpvars(0, soc);
        reset = 1'b1;
        #20
        reset = 1'b0;
        #100000
        $finish;
    end

    always #5 clk = !clk;

endmodule