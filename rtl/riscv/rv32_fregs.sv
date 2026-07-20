`ifndef RV32_FREGS
`define RV32_FREGS

module rv32_fregs (
    input clk,
    input ce_i,
    input stall_in,
    input flush_in,
    input writeback_flush_in,

    /* control in */
    input [4:0] rs1_in,
    input [4:0] rs2_in,
    input [4:0] rs3_in,
    input [4:0] rd_in,
    input rd_write_in,

    /* data in */
    input [31:0] rd_value_in,

    /* data out */
    output logic [31:0] rs1_value_out,
    output logic [31:0] rs2_value_out,
    output logic [31:0] rs3_value_out
);
    logic [31:0] regs [31:0];
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [4:0] rs3;

    generate
        genvar i;
        for (i = 0; i < 32; i = i+1) begin
            initial
                regs[i] = 0;
        end
    endgenerate

    assign rs1_value_out = regs[rs1];
    assign rs2_value_out = regs[rs2];
    assign rs3_value_out = regs[rs3];

    always_ff @(posedge clk) begin
        if (ce_i) begin
            /* Ignore flush so read addresses stay aligned with bank selects. */
            if (!stall_in && !flush_in) begin
                rs1 <= rs1_in;
                rs2 <= rs2_in;
                rs3 <= rs3_in;
            end

            /* f0 is a real register (unlike x0) */
            if (!writeback_flush_in && rd_write_in) begin
                regs[rd_in] <= rd_value_in;
            end
        end
    end
endmodule

`endif
