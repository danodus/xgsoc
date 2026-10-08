`ifndef RV32_BUS_ARBITER
`define RV32_BUS_ARBITER

module rv32_bus_arbiter (
    input clk,
    input ce_i,
    input reset,

    /* instruction memory bus */
    input [31:0] instr_address_in,
    input instr_read_in,
    output logic [31:0] instr_read_value_out,
    output logic instr_ready_out,
    output logic instr_fault_out,

    /* data memory bus */
    input [31:0] data_address_in,
    input data_read_in,
    input data_write_in,
    output logic [31:0] data_read_value_out,
    input [3:0] data_write_mask_in,
    input [31:0] data_write_value_in,
    output logic data_ready_out,
    output logic data_fault_out,

    /* common memory bus */
    output logic [31:0] address_out,
    output logic read_out,
    output logic write_out,
    input [31:0] read_value_in,
    output logic [3:0] write_mask_out,
    output logic [31:0] write_value_out,
    input ready_in,
    input fault_in
);
    logic data_read;
    logic data_read_in_progress;
    logic instr_read_in_progress;

    assign data_read = data_read_in || data_write_in;

    always_comb begin
        /* A data beat owns the bus once it has been accepted. ready_in is also
         * high for one cycle after a fetch whose follow-up select was cancelled
         * (the next instruction came from the saved halfword). Completing a new
         * load or store on that leftover ready drops the access before its
         * select is visible, so data_ready waits until this beat is in progress. */
        if (data_read_in_progress || (data_read && !instr_read_in_progress)) begin
            address_out = data_address_in;
            read_out = data_read_in;
            write_out = data_write_in;
            instr_read_value_out = 32'h00000013;
            data_read_value_out = read_value_in;
            write_mask_out = data_write_mask_in;
            write_value_out = data_write_value_in;
            instr_ready_out = 1'b0;
            data_ready_out = data_read_in_progress && ready_in;
            instr_fault_out = 1'b0;
            data_fault_out = data_read_in_progress && fault_in;
        end else if (instr_read_in_progress) begin
            /* The beat that produced ready_in stays visible after fetch drops
             * instr_read. Gating this on the live request feeds instr_read back
             * through ready and the read data, which oscillates when the word
             * holds two compressed instructions. read_out still follows the
             * live request so the completed beat does not start another one. */
            address_out = instr_address_in;
            read_out = instr_read_in;
            write_out = 1'b0;
            instr_read_value_out = read_value_in;
            data_read_value_out = 32'h00000013;
            write_mask_out = 4'b0;
            write_value_out = 32'bx;
            instr_ready_out = ready_in;
            data_ready_out = 1'b0;
            instr_fault_out = fault_in;
            data_fault_out = 1'b0;
        end else if (instr_read_in) begin
            address_out = instr_address_in;
            read_out = 1'b1;
            write_out = 1'b0;
            instr_read_value_out = 32'h00000013;
            data_read_value_out = 32'h00000013;
            write_mask_out = 4'b0;
            write_value_out = 32'bx;
            instr_ready_out = 1'b0;
            data_ready_out = 1'b0;
            instr_fault_out = 1'b0;
            data_fault_out = 1'b0;
        end else begin
            address_out = instr_address_in;
            read_out = 1'b0;
            write_out = 1'b0;
            instr_read_value_out = 32'h00000013;
            data_read_value_out = 32'h00000013;
            write_mask_out = 4'b0;
            write_value_out = 32'bx;
            instr_ready_out = 1'b0;
            data_ready_out = 1'b0;
            instr_fault_out = 1'b0;
            data_fault_out = 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (ce_i) begin
            if (data_read_in_progress) begin
                if (ready_in)
                    data_read_in_progress <= 0;
            end else if (!instr_read_in_progress && data_read && !ready_in) begin
                data_read_in_progress <= 1;
            end

            if (instr_read_in_progress) begin
                if (ready_in)
                    instr_read_in_progress <= 0;
            end else if (!data_read && !data_read_in_progress && instr_read_in && !ready_in) begin
                instr_read_in_progress <= 1;
            end
        end

        if (reset) begin
            data_read_in_progress <= 0;
            instr_read_in_progress <= 0;
        end
    end
endmodule

`endif
