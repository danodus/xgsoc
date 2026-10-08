`ifndef RV32_FETCH
`define RV32_FETCH

`include "rv32_csrs.sv"
`include "rv32_opcodes.sv"
`include "rv32_decompress.sv"

module rv32_fetch #(
    parameter RESET_VECTOR = 32'b0,
    parameter BRANCH_PREDICTION = 0
) (
    input clk,
    input ce_i,
    input reset,

`ifdef RISCV_FORMAL
    /* debug control out */
    output logic intr_out,

    /* debug data out */
    output logic [31:0] next_pc_out,
`endif

    /* control in (from hazard) */
    input pcgen_stall_in,
    input stall_in,
    input flush_in,

    /* control in (from mem) */
    input trap_in,
    input branch_mispredicted_in,

    /* control in (from memory bus) */
    input instr_ready_in,
    input instr_fault_in,

    /* data in (from mem) */
    input [31:0] trap_pc_in,
    input [31:0] branch_pc_in,

    /* data in (from memory bus) */
    input [31:0] instr_read_value_in,

    /* control out (to hazard) */
    output logic overwrite_pc_out,

    /* control out (to memory bus) */
    output logic instr_read_out,

    /* control out */
    output logic valid_out,
    output logic exception_out,
    output logic [3:0] exception_cause_out,
    output logic branch_predicted_taken_out,

    /* data out */
    output logic [31:0] pc_out,
    output logic [31:0] instr_out,
    output logic [31:0] pc_incr_out,

    /* data out (to memory bus) */
    output logic [31:0] instr_address_out
);
    logic [31:0] pc;
    logic [31:0] next_pc;

    logic overwrite_pc;
    logic trap;
    logic [31:0] overwritten_pc;

    /* Halfword left over from the previous word. Valid when pc[1] is set and
     * the instruction at pc starts with these bits. */
    logic residue_valid;
    logic [15:0] residue;

    logic need_fetch;
    logic absorb;
    logic [31:0] fetch_addr;
    logic [15:0] comp_half;
    logic [31:0] comp_instr;
    logic [31:0] issued_instr;
    logic [31:0] issued_len;

    logic sign;
    logic [31:0] imm_j;
    logic [31:0] imm_b;
    logic [6:0] opcode;

    logic branch_predicted_taken;
    logic [31:0] branch_offset;

    logic redirect;

    assign overwrite_pc_out = overwrite_pc;
    assign redirect = overwrite_pc || trap_in || branch_mispredicted_in;

    rv32_decompress decompress (
        .instr_in(comp_half),
        .instr_out(comp_instr)
    );

    always_comb begin
        if (residue_valid && residue[1:0] != 2'b11)
            comp_half = residue;
        else if (!residue_valid && pc[1])
            comp_half = instr_read_value_in[31:16];
        else
            comp_half = instr_read_value_in[15:0];
    end

    /* Assemble one instruction. Memory is word-addressed, so a PC with bit 1
     * set is built from halfwords. A 32-bit instruction that starts on a
     * halfword boundary needs the next word; until that word is in hand, absorb
     * stores the first half and does not issue. */
    always_comb begin
        need_fetch = 1'b1;
        fetch_addr = {pc[31:2], 2'b00};
        absorb = 1'b0;
        issued_instr = `RV32_INSTR_NOP;
        issued_len = 32'd4;

        if (residue_valid && residue[1:0] != 2'b11) begin
            need_fetch = 1'b0;
            issued_instr = comp_instr;
            issued_len = 32'd2;
        end else if (residue_valid) begin
            fetch_addr = {pc[31:2], 2'b00} + 32'd4;
            issued_instr = {instr_read_value_in[15:0], residue};
            issued_len = 32'd4;
        end else if (!pc[1]) begin
            if (instr_read_value_in[1:0] != 2'b11) begin
                issued_instr = comp_instr;
                issued_len = 32'd2;
            end else begin
                issued_instr = instr_read_value_in;
                issued_len = 32'd4;
            end
        end else if (instr_read_value_in[17:16] != 2'b11) begin
            issued_instr = comp_instr;
            issued_len = 32'd2;
        end else begin
            absorb = !instr_fault_in;
        end
    end

    /* Dropping instr_read in the cycle a word is accepted stops the bus from
     * starting another read when the upper halfword is already a whole
     * instruction. The address must stay with the transaction that produced
     * instr_ready, so this is only done once that word is valid. */
    wire hold_upper;
    assign hold_upper = instr_ready_in && !stall_in && !redirect && !instr_fault_in &&
                        !branch_predicted_taken && !residue_valid && !pc[1] &&
                        instr_read_value_in[1:0] != 2'b11 &&
                        instr_read_value_in[17:16] != 2'b11;

    assign instr_read_out = need_fetch && !hold_upper;
    assign instr_address_out = fetch_addr;

    assign sign = issued_instr[31];
    assign imm_j = {{12{sign}}, issued_instr[19:12], issued_instr[20],    issued_instr[30:25], issued_instr[24:21], 1'b0};
    assign imm_b = {{20{sign}}, issued_instr[7],     issued_instr[30:25], issued_instr[11:8],  1'b0};
    assign opcode = issued_instr[6:0];

    generate
        if (BRANCH_PREDICTION) begin
            always_comb begin
                casez ({opcode, sign})
                    {`RV32_OPCODE_JAL, 1'b?}: begin
                        branch_predicted_taken = 1;
                        branch_offset = imm_j;
                    end
                    {`RV32_OPCODE_BRANCH, 1'b1}: begin
                        branch_predicted_taken = 1;
                        branch_offset = imm_b;
                    end
                    default: begin
                        branch_predicted_taken = 0;
                        branch_offset = issued_len;
                    end
                endcase
            end
        end else begin
            assign branch_predicted_taken = 0;
            assign branch_offset = issued_len;
        end
    endgenerate

    always_comb begin
        if (overwrite_pc)
            next_pc = overwritten_pc;
        else if (trap_in)
            next_pc = trap_pc_in;
        else if (branch_mispredicted_in)
            next_pc = branch_pc_in;
        else
            next_pc = pc + branch_offset;
    end

    initial begin
        pc = RESET_VECTOR;
        instr_out = `RV32_INSTR_NOP;
        residue_valid = 1'b0;
        residue = 16'b0;
    end

    always_ff @(posedge clk) begin
        if (ce_i) begin
            if (pcgen_stall_in) begin
                if (!overwrite_pc && (trap_in || branch_mispredicted_in)) begin
                    overwrite_pc <= 1;
                    trap <= trap_in;
                    overwritten_pc <= trap_in ? trap_pc_in : branch_pc_in;
                end
            end else if (redirect) begin
                overwrite_pc <= 0;
                trap <= 0;
                pc <= next_pc;
                residue_valid <= 1'b0;
            end else if (absorb) begin
                residue <= instr_read_value_in[31:16];
                residue_valid <= 1'b1;
            end else begin
                overwrite_pc <= 0;
                trap <= 0;
                pc <= next_pc;
                /* A taken prediction or a fence leaves the other halfword on the
                 * wrong path, or requires the next fetch to observe stores. */
                if (branch_predicted_taken || issued_instr[6:0] == 7'b0001111) begin
                    residue_valid <= 1'b0;
                end else if (residue_valid && residue[1:0] == 2'b11) begin
                    residue <= instr_read_value_in[31:16];
                    residue_valid <= 1'b1;
                end else if (!residue_valid && !pc[1] && instr_read_value_in[1:0] != 2'b11) begin
                    residue <= instr_read_value_in[31:16];
                    residue_valid <= 1'b1;
                end else begin
                    residue_valid <= 1'b0;
                end
            end

            if (!stall_in) begin
                valid_out <= 1;
                exception_out <= 0;
                branch_predicted_taken_out <= branch_predicted_taken;
                instr_out <= issued_instr;
                pc_out <= pc;
                pc_incr_out <= issued_len;
    `ifdef RISCV_FORMAL
                intr_out <= trap || trap_in;
                next_pc_out <= next_pc;
    `endif

                if (need_fetch && instr_fault_in) begin
                    valid_out <= 0;
                    exception_out <= 1;
                    exception_cause_out <= `RV32_MCAUSE_INSTR_FAULT_EXCEPTION;
                    branch_predicted_taken_out <= 0;
    `ifdef RISCV_FORMAL
                    instr_out <= 0;
    `else
                    instr_out <= `RV32_INSTR_NOP;
    `endif
                end

                if (flush_in || absorb) begin
                    valid_out <= 0;
                    exception_out <= 0;
                    branch_predicted_taken_out <= 0;
                    instr_out <= `RV32_INSTR_NOP;
                    pc_out <= 0;
                    pc_incr_out <= 32'd4;
                end
            end
        end

        if (reset) begin
            overwrite_pc <= 0;
            valid_out <= 0;
            exception_out <= 0;
            branch_predicted_taken_out <= 0;
            instr_out <= `RV32_INSTR_NOP;
            pc <= RESET_VECTOR;
            pc_out <= 0;
            pc_incr_out <= 32'd4;
            residue_valid <= 1'b0;
            residue <= 16'b0;
        end
    end
endmodule

`endif
