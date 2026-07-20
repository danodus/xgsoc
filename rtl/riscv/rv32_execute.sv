`ifndef RV32_EXECUTE
`define RV32_EXECUTE

`include "rv32_alu.sv"
`include "rv32_branch.sv"

module rv32_execute #(
    parameter BYPASSING = 0
) (
    input clk,
    input ce_i,
    input reset,

`ifdef RISCV_FORMAL
    /* debug control in */
    input intr_in,

    /* debug data in */
    input [31:0] next_pc_in,
    input [31:0] instr_in,

    /* debug control out */
    output logic intr_out,
    output logic [4:0] rs1_out,
    output logic [4:0] rs2_out,

    /* debug data out */
    output logic [31:0] next_pc_out,
    output logic [31:0] instr_out,
`endif

    /* control in (from hazard) */
    input stall_in,
    input external_stall_in,
    input flush_in,
    input mem_flush_in,
    input writeback_flush_in,

    /* control in */
    input branch_predicted_taken_in,
    input valid_in,
    input exception_in,
    input [3:0] exception_cause_in,
    input [4:0] rs1_in,
    input [4:0] rs2_in,
    input [4:0] alu_op_in,
    input alu_sub_sra_in,
    input [1:0] alu_src1_in,
    input [1:0] alu_src2_in,
    input mem_read_in,
    input mem_write_in,
    input [1:0] mem_width_in,
    input mem_zero_extend_in,
    input mem_fence_in,
    input csr_read_in,
    input csr_write_in,
    input [1:0] csr_write_op_in,
    input csr_src_in,
    input [1:0] branch_op_in,
    input branch_pc_src_in,
    input ecall_in,
    input ebreak_in,
    input mret_in,
    input [4:0] rd_in,
    input rd_write_in,
    input rd_fp_in,
    input fpu_en_in,

    /* control in (from writeback) */
    input [4:0] writeback_rd_in,
    input writeback_rd_write_in,
    input writeback_rd_fp_in,

    /* data in */
    input [31:0] pc_in,
    input [31:0] rs1_value_in,
    input [31:0] rs2_value_in,
    input [31:0] rs3_value_in,
    input [31:0] imm_value_in,
    input [11:0] csr_in,
    input [31:2] instr_fpu_in,

    /* data in (from writeback) */
    input [31:0] writeback_rd_value_in,

    /* control out */
    output logic alu_busy_out,
    output logic branch_predicted_taken_out,
    output logic branch_misaligned_out,
    output logic valid_out,
    output logic exception_out,
    output logic [3:0] exception_cause_out,
    output logic mem_read_out,
    output logic mem_write_out,
    output logic [1:0] mem_width_out,
    output logic mem_zero_extend_out,
    output logic mem_fence_out,
    output logic csr_read_out,
    output logic csr_write_out,
    output logic [1:0] csr_write_op_out,
    output logic csr_src_out,
    output logic [1:0] branch_op_out,
    output logic ecall_out,
    output logic ebreak_out,
    output logic mret_out,
    output logic [4:0] rd_out,
    output logic rd_write_out,
    output logic rd_fp_out,

    /* data out */
    output logic [31:0] pc_out,
    output logic [31:0] result_out,
    output logic [31:0] rs1_value_out,
    output logic [31:0] rs2_value_out,
    output logic [31:0] imm_value_out,
    output logic [11:0] csr_out,
    output logic [31:0] branch_pc_out
);
    /* bypassing */
    logic [31:0] rs1_value;
    logic [31:0] rs2_value;

    generate
        if (BYPASSING) begin
            always_comb begin
                if (rd_write_out && !mem_flush_in && rd_out == rs1_in && !rd_fp_out && |rs1_in)
                    rs1_value = result_out;
                else if (writeback_rd_write_in && !writeback_flush_in && writeback_rd_in == rs1_in &&
                         !writeback_rd_fp_in && |rs1_in)
                    rs1_value = writeback_rd_value_in;
                else
                    rs1_value = rs1_value_in;

                if (rd_write_out && !mem_flush_in && rd_out == rs2_in && !rd_fp_out && |rs2_in)
                    rs2_value = result_out;
                else if (writeback_rd_write_in && !writeback_flush_in && writeback_rd_in == rs2_in &&
                         !writeback_rd_fp_in && |rs2_in)
                    rs2_value = writeback_rd_value_in;
                else
                    rs2_value = rs2_value_in;
            end
        end else begin
            assign rs1_value = rs1_value_in;
            assign rs2_value = rs2_value_in;
        end
    endgenerate

    /* ALU */
    logic [31:0] alu_result;
    logic alu_div_busy;
    logic alu_was_busy;
    logic rd_write_out_saved;
    logic [4:0] rd_out_saved;
    logic rd_fp_saved;
    logic was_fpu_saved;

    /* FPU
     * PetitBateau is multi-cycle (wr pulse, then busy). Commit mirrors divide:
     * stall while busy, then one cycle with alu_was_busy to write fpu_out.
     *
     * Important: start on rd_write && fpu_en, NOT valid_in — same as the
     * divider. This core writebacks from rd_write; valid can be 0 in EX while
     * rd_write still describes a live op. Requiring valid_in let OP-FP fall
     * through to alu_result (ZERO+FOUR => 0x4) on FPGA. */
    logic fpu_hold;
    logic fpu_wr;
    logic fpu_busy;
    logic [31:0] fpu_out;
    logic fpu_busy_for_hazard;
    logic multi_cycle_busy;
    logic fpu_alu_inert;

    /* OP-FP / FMA decode forces ALU to 0+4 as an inert placeholder. */
    assign fpu_alu_inert = (alu_src1_in == `RV32_ALU_SRC1_ZERO) &&
                           (alu_src2_in == `RV32_ALU_SRC2_FOUR) &&
                           rd_write_in;

    assign fpu_wr = fpu_en_in && rd_write_in && !external_stall_in && !fpu_hold && !alu_div_busy;
    /* Stall for the wr cycle and while the unit is working. The cycle after
     * busy falls has fpu_hold still set and alu_was_busy=1 for commit. */
    assign fpu_busy_for_hazard = fpu_wr || (fpu_hold && fpu_busy);
    assign multi_cycle_busy = alu_div_busy || fpu_busy_for_hazard;
    assign alu_busy_out = multi_cycle_busy;

    always_ff @(posedge clk) begin
        if (reset) begin
            alu_was_busy <= 0;
            rd_write_out_saved <= 0;
            rd_out_saved <= 0;
            rd_fp_saved <= 0;
            was_fpu_saved <= 0;
            fpu_hold <= 0;
        end else if (ce_i) begin
            /* Do not drop alu_was_busy under external_stall. SDRAM waits can
             * coincide with busy falling; updating here would lose the commit
             * cycle. Verilator rarely hits this. */
            if (!external_stall_in)
                alu_was_busy <= alu_busy_out;

            /* Capture FPU destination on start (wr), not only on busy edge —
             * covers single-cycle FPU ops where busy never rises after wr. */
            if (!external_stall_in && fpu_wr) begin
                rd_write_out_saved <= rd_write_in;
                rd_out_saved <= rd_in;
                rd_fp_saved <= rd_fp_in;
                was_fpu_saved <= 1;
            end else if (!external_stall_in && !alu_was_busy && alu_busy_out) begin
                rd_write_out_saved <= rd_write_in;
                rd_out_saved <= rd_in;
                rd_fp_saved <= rd_fp_in;
                was_fpu_saved <= fpu_en_in;
            end

            if (!external_stall_in) begin
                if (fpu_wr)
                    fpu_hold <= 1;
                else if (fpu_hold && !fpu_busy)
                    fpu_hold <= 0;
            end
        end
    end

    rv32_alu alu (
        .clk(clk),
        .ce_i(ce_i),
        .reset(reset),

        /* control in */
        .stall_in(stall_in),
        .external_stall_in(external_stall_in),
        .op_in(alu_op_in),
        .sub_sra_in(alu_sub_sra_in),
        .src1_in(alu_src1_in),
        .src2_in(alu_src2_in),
        .rd_write_in(rd_write_in && !fpu_en_in),

        /* data in */
        .pc_in(pc_in),
        .rs1_value_in(rs1_value),
        .rs2_value_in(rs2_value),
        .imm_value_in(imm_value_in),

        /* data out */
        .result_out(alu_result),
        .busy_out(alu_div_busy)
    );

    PetitBateau fpu (
        .clk(clk),
        .ce(ce_i),
        .wr(fpu_wr),
        .instr(instr_fpu_in),
        .rs1(rs1_value),
        .rs2(rs2_value),
        .rs3(rs3_value_in),
        .busy(fpu_busy),
        .out(fpu_out)
    );

    /* branch target calculation */
    logic branch_misaligned;
    logic [31:0] branch_pc;

    rv32_branch_pc_mux branch_pc_mux (
        /* control in */
        .predicted_taken_in(branch_predicted_taken_in),
        .pc_src_in(branch_pc_src_in),

        /* data in */
        .pc_in(pc_in),
        .rs1_value_in(rs1_value),
        .imm_value_in(imm_value_in),

        /* control out */
        .misaligned_out(branch_misaligned),

        /* data out */
        .pc_out(branch_pc)
    );

    always_ff @(posedge clk) begin
        if (ce_i) begin
            if (flush_in && !multi_cycle_busy) begin
                branch_predicted_taken_out <= 0;
                valid_out <= 0;
                exception_out <= 0;
                mem_read_out <= 0;
                mem_write_out <= 0;
                csr_read_out <= 0;
                csr_write_out <= 0;
                branch_op_out <= `RV32_BRANCH_OP_NEVER;
                ecall_out <= 0;
                ebreak_out <= 0;
                mret_out <= 0;
                rd_write_out <= 0;
                rd_fp_out <= 0;
            end else if (stall_in && !external_stall_in) begin
                /* Bubble EX→MEM while multi-cycle op runs. Clear rd_write so
                 * MEM does not retire a stale result (FPU 0+4 / old ALU). Hazard
                 * coverage comes from execute_alu_busy stalling the pipe — same
                 * as the original divider. Do NOT gate MEM on valid; that drops
                 * real writebacks under SDRAM stalls on ULX3S. */
                branch_predicted_taken_out <= 0;
                valid_out <= 0;
                exception_out <= 0;
                mem_read_out <= 0;
                mem_write_out <= 0;
                csr_read_out <= 0;
                csr_write_out <= 0;
                branch_op_out <= `RV32_BRANCH_OP_NEVER;
                ecall_out <= 0;
                ebreak_out <= 0;
                mret_out <= 0;
                rd_write_out <= 0;
                rd_fp_out <= 0;
            end else if (!stall_in) begin
                if (alu_was_busy || (fpu_hold && !fpu_busy && was_fpu_saved)) begin
                    /* Div/FPU commit: only this cycle should write the regfile. */
                    result_out <= was_fpu_saved ? fpu_out : alu_result;
                    rd_out <= rd_out_saved;
                    rd_write_out <= rd_write_out_saved;
                    rd_fp_out <= rd_fp_saved;
                    valid_out <= 1;
                    mem_read_out <= 0;
                    mem_write_out <= 0;
                    csr_read_out <= 0;
                    csr_write_out <= 0;
                    branch_op_out <= `RV32_BRANCH_OP_NEVER;
                    ecall_out <= 0;
                    ebreak_out <= 0;
                    mret_out <= 0;
                end else if (fpu_en_in && rd_write_in) begin
                    /* Must not fall through to alu_result (0+4 canary). Bubble;
                     * fpu_wr/hold should prevent this path — safety net only. */
                    branch_predicted_taken_out <= 0;
                    valid_out <= 0;
                    exception_out <= 0;
                    mem_read_out <= 0;
                    mem_write_out <= 0;
                    csr_read_out <= 0;
                    csr_write_out <= 0;
                    branch_op_out <= `RV32_BRANCH_OP_NEVER;
                    ecall_out <= 0;
                    ebreak_out <= 0;
                    mret_out <= 0;
                    rd_write_out <= 0;
                    rd_fp_out <= 0;
                end else begin
`ifdef RISCV_FORMAL
                    intr_out <= intr_in;
                    next_pc_out <= next_pc_in;
                    rs1_out <= rs1_in;
                    rs2_out <= rs2_in;
                    instr_out <= instr_in;
`endif

                    branch_predicted_taken_out <= branch_predicted_taken_in;
                    branch_misaligned_out <= branch_misaligned;
                    valid_out <= valid_in;
                    exception_out <= exception_in;
                    exception_cause_out <= exception_cause_in;
                    mem_read_out <= mem_read_in;
                    mem_write_out <= mem_write_in;
                    mem_width_out <= mem_width_in;
                    mem_zero_extend_out <= mem_zero_extend_in;
                    mem_fence_out <= mem_fence_in;
                    csr_read_out <= csr_read_in;
                    csr_write_out <= csr_write_in;
                    csr_write_op_out <= csr_write_op_in;
                    csr_src_out <= csr_src_in;
                    branch_op_out <= branch_op_in;
                    ecall_out <= ecall_in;
                    ebreak_out <= ebreak_in;
                    mret_out <= mret_in;
                    rd_out <= rd_in;
                    rd_write_out <= rd_write_in;
                    rd_fp_out <= rd_fp_in;
                    pc_out <= pc_in;
                    rs1_value_out <= rs1_value;
                    rs2_value_out <= rs2_value;
                    imm_value_out <= imm_value_in;
                    csr_out <= csr_in;
                    branch_pc_out <= branch_pc;
                    /* ZERO+FOUR is only the FPU inert ALU placeholder (JAL is
                     * PC+FOUR). Never retire 0+4 if OP-FP lost fpu_en. */
                    result_out <= fpu_alu_inert ? fpu_out : alu_result;
                end
            end
        end

        if (reset) begin
            branch_predicted_taken_out <= 0;
            valid_out <= 0;
            exception_out <= 0;
            mem_read_out <= 0;
            mem_write_out <= 0;
            mem_width_out <= 0;
            mem_zero_extend_out <= 0;
            mem_fence_out <= 0;
            csr_read_out <= 0;
            csr_write_out <= 0;
            branch_op_out <= 0;
            ecall_out <= 0;
            ebreak_out <= 0;
            mret_out <= 0;
            rd_out <= 0;
            rd_write_out <= 0;
            rd_fp_out <= 0;
            rs2_value_out <= 0;
            branch_pc_out <= 0;
            result_out <= 0;
        end
    end
endmodule

`endif
