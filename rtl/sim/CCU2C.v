// Behavioral model of the Lattice ECP5 CCU2C carry primitive.
// Synthesis uses the device cell; this file is only so Verilator can elaborate
// the cache tag comparator in rtl/cache_controller.v.
module CCU2C (
    input  CIN,
    input  A0, B0, C0, D0,
    input  A1, B1, C1, D1,
    output S0, S1,
    output COUT
);
    parameter [15:0] INIT0 = 16'h0000;
    parameter [15:0] INIT1 = 16'h0000;
    parameter INJECT1_0 = "YES";
    parameter INJECT1_1 = "YES";

    function automatic lut4;
        input [15:0] init;
        input a, b, c, d;
        begin
            lut4 = init[{d, c, b, a}];
        end
    endfunction

    wire LUT4_0 = lut4(INIT0, A0, B0, C0, D0);
    wire LUT2_0 = INIT0[{2'b00, B0, A0}];
    wire gated_cin_0 = (INJECT1_0 == "YES") ? 1'b0 : CIN;
    assign S0 = LUT4_0 ^ gated_cin_0;

    wire gated_lut2_0 = (INJECT1_0 == "YES") ? 1'b0 : LUT2_0;
    wire cout_0 = (~LUT4_0 & gated_lut2_0) | (LUT4_0 & CIN);

    wire LUT4_1 = lut4(INIT1, A1, B1, C1, D1);
    wire LUT2_1 = INIT1[{2'b00, B1, A1}];
    wire gated_cin_1 = (INJECT1_1 == "YES") ? 1'b0 : cout_0;
    assign S1 = LUT4_1 ^ gated_cin_1;

    wire gated_lut2_1 = (INJECT1_1 == "YES") ? 1'b0 : LUT2_1;
    assign COUT = (~LUT4_1 & gated_lut2_1) | (LUT4_1 & cout_0);
endmodule
