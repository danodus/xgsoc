`ifndef RV32_MEM
`define RV32_MEM

`include "rv32_branch.sv"
`include "rv32_csrs.sv"
`include "rv32_opcodes.sv"

`define RV32_MEM_WIDTH_WORD 2'b00
`define RV32_MEM_WIDTH_HALF 2'b01
`define RV32_MEM_WIDTH_BYTE 2'b10

module rv32_mem (
    input clk,
    input ce_i,
    input reset,

`ifdef RISCV_FORMAL
    /* debug control in */
    input intr_in,
    input [4:0] rs1_in,
    input [4:0] rs2_in,

    /* debug data in */
    input [31:0] next_pc_in,
    input [31:0] instr_in,

    /* debug control out */
    output logic intr_out,
    output logic trap_out,
    output logic [4:0] rs1_out,
    output logic [4:0] rs2_out,
    output logic [3:0] read_mask_out,
    output logic [3:0] write_mask_out,

    /* debug data out */
    output logic [31:0] pc_out,
    output logic [31:0] next_pc_out,
    output logic [31:0] instr_out,
    output logic [31:0] rs1_value_out,
    output logic [31:0] rs2_value_out,
    output logic [31:0] address_out,
    output logic [31:0] read_value_out,
    output logic [31:0] write_value_out,
`endif

    /* control in (from hazard) */
    input stall_in,
    input flush_in,
    input writeback_flush_in,

    /* control in */
    input branch_predicted_taken_in,
    input branch_misaligned_in,
    input valid_in,
    input exception_in,
    input [3:0] exception_cause_in,
    input read_in,
    input write_in,
    input [1:0] width_in,
    input zero_extend_in,
    input csr_read_in,
    input csr_write_in,
    input [1:0] csr_write_op_in,
    input csr_src_in,
    input [1:0] branch_op_in,
    input ecall_in,
    input ebreak_in,
    input mret_in,
    input [4:0] rd_in,
    input rd_write_in,
    input rd_fp_in,
    input [3:0] amo_op_in,

    /* control in (from data memory bus) */
    input data_fault_in,
    input data_ready_in,

    /* data in */
    input [31:0] pc_in,
    input [31:0] result_in,
    input [31:0] rs1_value_in,
    input [31:0] rs2_value_in,
    input [31:0] imm_value_in,
    input [31:0] branch_pc_in,
    input [11:0] csr_in,
    input fflags_valid_in,
    input [4:0] fflags_in,

    /* data in (from data memory bus) */
    input [31:0] data_read_value_in,

    /* control out */
    output logic valid_out,
    output logic trap_unreg_out,
    output logic branch_mispredicted_out,
    output logic [4:0] rd_out,
    output logic rd_write_out,
    output logic rd_fp_out,
    output logic amo_hold_out,

    /* control out (to data memory bus) */
    output logic data_read_out,
    output logic data_write_out,
    output logic [3:0] data_write_mask_out,

    /* data out */
    output logic [31:0] rd_value_out,
    output logic [31:0] trap_pc_out,
    output logic [31:0] branch_pc_out,

    /* data out (to data memory bus) */
    output logic [31:0] data_address_out,
    output logic [31:0] data_write_value_out,

    /* data out (to timer) */
    output logic [63:0] cycle_out,

    /* frm, including a same-cycle bypass of a write in this stage */
    output logic [2:0] frm_out,
    output logic [2:0] frm_bypass_out,
    output logic frm_bypass_en_out
);
    logic branch_mispredicted;
    logic branch_taken;

    /* branch unit */
    rv32_branch_unit branch_unit (
        /* control in */
        .predicted_taken_in(branch_predicted_taken_in),
        .op_in(branch_op_in),

        /* data in */
        .result_in(result_in),

        /* control out */
        .taken_out(branch_taken),
        .mispredicted_out(branch_mispredicted)
    );

    assign branch_pc_out = branch_pc_in;
    assign branch_mispredicted_out = branch_mispredicted && !flush_in;

    /* A extension. Single hart, one reserved word. Cleared by this hart's
     * stores, AMOs to that word, any SC, and traps. aq/rl are ignored because
     * each memory op finishes before the next instruction. Other masters are
     * not snooped.
     *
     * The read strobe drops on data_ready so that ready pulse is not reused
     * as the following write. The write starts on its own select. */
    localparam AMO_IDLE  = 2'd0;
    localparam AMO_READ  = 2'd1;
    localparam AMO_WRITE = 2'd2;

    logic [1:0] amo_state;
    logic res_valid;
    logic [31:2] res_addr;
    logic [31:0] amo_old;

    logic amo_misaligned;
    logic amo_present;
    logic amo_is_lr;
    logic amo_is_sc;
    logic sc_hit;
    logic sc_fail;
    logic amo_live;
    logic lr_done;
    logic wr_done;
    logic amo_bus_read;
    logic amo_bus_write;
    logic word_hit;

    assign amo_misaligned = (amo_op_in != `RV32_AMO_NONE) && (result_in[1:0] != 2'b0);
    assign amo_present = (amo_op_in != `RV32_AMO_NONE) && !exception_in && !amo_misaligned;
    assign amo_is_lr = amo_op_in == `RV32_AMO_LR;
    assign amo_is_sc = amo_op_in == `RV32_AMO_SC;
    assign sc_hit = res_valid && (res_addr == result_in[31:2]);
    assign sc_fail = amo_present && amo_is_sc && !sc_hit;
    assign amo_live = amo_present && !sc_fail;
    assign lr_done = (amo_state == AMO_READ) && amo_is_lr && data_ready_in;
    assign wr_done = (amo_state == AMO_WRITE) && data_ready_in;
    assign amo_bus_read = (amo_state == AMO_READ) && !data_ready_in && (amo_op_in != `RV32_AMO_NONE);
    assign amo_bus_write = (amo_state == AMO_WRITE) && (amo_op_in != `RV32_AMO_NONE);
    assign word_hit = res_valid && (res_addr == result_in[31:2]);

    assign amo_hold_out = amo_live && !lr_done && !wr_done;

    function automatic [31:0] amo_result(
        input [3:0] op,
        input [31:0] oldv,
        input [31:0] rs2
    );
        case (op)
            `RV32_AMO_SWAP, `RV32_AMO_SC: amo_result = rs2;
            `RV32_AMO_ADD:  amo_result = oldv + rs2;
            `RV32_AMO_XOR:  amo_result = oldv ^ rs2;
            `RV32_AMO_AND:  amo_result = oldv & rs2;
            `RV32_AMO_OR:   amo_result = oldv | rs2;
            `RV32_AMO_MIN:  amo_result = ($signed(oldv) < $signed(rs2)) ? oldv : rs2;
            `RV32_AMO_MAX:  amo_result = ($signed(oldv) > $signed(rs2)) ? oldv : rs2;
            `RV32_AMO_MINU: amo_result = (oldv < rs2) ? oldv : rs2;
            `RV32_AMO_MAXU: amo_result = (oldv > rs2) ? oldv : rs2;
            default:        amo_result = rs2;
        endcase
    endfunction

    /* memory access unit */
    logic mem_misaligned;

    logic [31:0] read_value;
    logic [3:0] read_mask;

    assign data_read_out = (read_in && !mem_misaligned) || amo_bus_read;
    assign data_write_out = (write_in && !mem_misaligned) || amo_bus_write;
    assign data_address_out = {result_in[31:2], 2'b0};

    always_comb begin
        /* alignment check */
        case (width_in)
            `RV32_MEM_WIDTH_WORD: mem_misaligned = result_in[1:0] != 0;
            `RV32_MEM_WIDTH_HALF: mem_misaligned = result_in[0] != 0;
            `RV32_MEM_WIDTH_BYTE: mem_misaligned = 0;
            default:              mem_misaligned = 1'bx;
        endcase

        /* write port */
        if (amo_bus_write) begin
            data_write_value_out = amo_result(amo_op_in, amo_old, rs2_value_in);
            data_write_mask_out = 4'b1111;
        end else if (write_in) begin
            case (width_in)
                `RV32_MEM_WIDTH_WORD: begin
                    data_write_value_out = rs2_value_in;
                    data_write_mask_out = 4'b1111;
                end
                `RV32_MEM_WIDTH_HALF: begin
                    case (result_in[1])
                        1'b0: begin
                            data_write_value_out = {16'bx, rs2_value_in[15:0]};
                            data_write_mask_out = 4'b0011;
                        end
                        1'b1: begin
                            data_write_value_out = {rs2_value_in[15:0], 16'bx};
                            data_write_mask_out = 4'b1100;
                        end
                    endcase
                end
                `RV32_MEM_WIDTH_BYTE: begin
                    case (result_in[1:0])
                        2'b00: begin
                            data_write_value_out = {24'bx, rs2_value_in[7:0]};
                            data_write_mask_out = 4'b0001;
                        end
                        2'b01: begin
                            data_write_value_out = {16'bx, rs2_value_in[7:0], 8'bx};
                            data_write_mask_out = 4'b0010;
                        end
                        2'b10: begin
                            data_write_value_out = {8'bx, rs2_value_in[7:0], 16'bx};
                            data_write_mask_out = 4'b0100;
                        end
                        2'b11: begin
                            data_write_value_out = {rs2_value_in[7:0], 24'bx};
                            data_write_mask_out = 4'b1000;
                        end
                    endcase
                end
                default: begin
                    data_write_value_out = 32'bx;
                    data_write_mask_out = 4'bx;
                end
            endcase
        end else begin
            data_write_value_out = 32'bx;
            data_write_mask_out = 4'b0;
        end

        /* read port */
        if (read_in) begin
            case (width_in)
                `RV32_MEM_WIDTH_WORD: begin
                    read_value = data_read_value_in;
                    read_mask = 4'b1111;
                end
                `RV32_MEM_WIDTH_HALF: begin
                    case (result_in[1])
                        1'b0: begin
                            read_value = {{16{zero_extend_in ? 1'b0 : data_read_value_in[15]}}, data_read_value_in[15:0]};
                            read_mask = 4'b0011;
                        end
                        1'b1: begin
                            read_value = {{16{zero_extend_in ? 1'b0 : data_read_value_in[31]}}, data_read_value_in[31:16]};
                            read_mask = 4'b1100;
                        end
                    endcase
                end
                `RV32_MEM_WIDTH_BYTE: begin
                    case (result_in[1:0])
                        2'b00: begin
                            read_value = {{24{zero_extend_in ? 1'b0 : data_read_value_in[7]}},  data_read_value_in[7:0]};
                            read_mask = 4'b0001;
                        end
                        2'b01: begin
                            read_value = {{24{zero_extend_in ? 1'b0 : data_read_value_in[15]}}, data_read_value_in[15:8]};
                            read_mask = 4'b0010;
                        end
                        2'b10: begin
                            read_value = {{24{zero_extend_in ? 1'b0 : data_read_value_in[23]}}, data_read_value_in[23:16]};
                            read_mask = 4'b0100;
                        end
                        2'b11: begin
                            read_value = {{24{zero_extend_in ? 1'b0 : data_read_value_in[31]}}, data_read_value_in[31:24]};
                            read_mask = 4'b1000;
                        end
                    endcase
                end
                default: begin
                    read_value = 32'bx;
                    read_mask = 4'bx;
                end
            endcase
        end else if (amo_state == AMO_READ) begin
            read_value = data_read_value_in;
            read_mask = 4'b1111;
        end else begin
            read_value = 32'bx;
            read_mask = 4'b0;
        end
    end

    /* traps */
    logic exception;
    logic [3:0] exception_cause;
    logic mem_exception;

    always_comb begin
        exception = 0;
        exception_cause = 4'bx;
        mem_exception = 0;

        if (exception_in) begin
            exception = 1;
            exception_cause = exception_cause_in;
        end else if (branch_taken && branch_misaligned_in) begin
            exception = 1;
            exception_cause = `RV32_MCAUSE_INSTR_MISALIGNED_EXCEPTION;
            mem_exception = 1;
        end else if (read_in && mem_misaligned) begin
            exception = 1;
            exception_cause = `RV32_MCAUSE_LOAD_MISALIGNED_EXCEPTION;
            mem_exception = 1;
        end else if (write_in && mem_misaligned) begin
            exception = 1;
            exception_cause = `RV32_MCAUSE_STORE_MISALIGNED_EXCEPTION;
            mem_exception = 1;
        end else if (amo_op_in != `RV32_AMO_NONE && amo_misaligned) begin
            exception = 1;
            mem_exception = 1;
            if (amo_op_in == `RV32_AMO_LR)
                exception_cause = `RV32_MCAUSE_LOAD_MISALIGNED_EXCEPTION;
            else
                exception_cause = `RV32_MCAUSE_STORE_MISALIGNED_EXCEPTION;
        end else if (read_in && data_fault_in) begin
            exception = 1;
            exception_cause = `RV32_MCAUSE_LOAD_FAULT_EXCEPTION;
            mem_exception = 1;
        end else if (write_in && data_fault_in) begin
            exception = 1;
            exception_cause = `RV32_MCAUSE_STORE_FAULT_EXCEPTION;
            mem_exception = 1;
        end else if (ecall_in) begin
            exception = 1;
            exception_cause = `RV32_MCAUSE_MACHINE_ECALL_EXCEPTION;
        end else if (ebreak_in) begin
            exception = 1;
            exception_cause = `RV32_MCAUSE_BREAKPOINT_EXCEPTION;
        end
    end

    /* csr file */
    logic [31:0] csr_read_value;
    logic [63:0] cycle;

    rv32_csrs csrs (
        .clk(clk),
        .ce_i(ce_i),
        .reset(reset),
        .stall_in(stall_in),
        .flush_in(flush_in),
        .writeback_flush_in(writeback_flush_in),

        /* control in */
        .exception_in(exception),
        .exception_cause_in(exception_cause),
        .read_in(csr_read_in),
        .write_in(csr_write_in),
        .write_op_in(csr_write_op_in),
        .src_in(csr_src_in),
        .mret_in(mret_in),

        /* control in (from writeback) */
        .instr_retired_in(valid_out),

        /* data in */
        .pc_in(pc_in),
        .rs1_value_in(rs1_value_in),
        .imm_value_in(imm_value_in),
        .csr_in(csr_in),
        .fflags_acc_in(fflags_valid_in && valid_in && !exception),
        .fflags_in(fflags_in),

        /* control out */
        .trap_out(trap_unreg_out),

        /* data out */
        .read_value_out(csr_read_value),
        .trap_pc_out(trap_pc_out),
        .frm_out(frm_out),
        .frm_bypass_out(frm_bypass_out),
        .frm_bypass_en_out(frm_bypass_en_out),

        /* data out (to timer) */
        .cycle_out(cycle_out)
    );

    logic [31:0] next_pc;

`ifdef RISCV_FORMAL
    always_comb begin
        if (trap_unreg_out)
            next_pc = trap_pc_out;
        else if (branch_mispredicted)
            next_pc = branch_pc_in;
        else
            next_pc = next_pc_in;
    end
`endif

    always_ff @(posedge clk) begin
        if (ce_i) begin
            if (!stall_in) begin
    `ifdef RISCV_FORMAL
                intr_out <= intr_in;
                pc_out <= pc_in;
                next_pc_out <= next_pc;
                trap_out <= trap_unreg_out;
                rs1_out <= rs1_in;
                rs2_out <= rs2_in;
                instr_out <= instr_in;
                rs1_value_out <= rs1_value_in;
                rs2_value_out <= rs2_value_in;
                address_out <= data_address_out;
                read_mask_out <= read_mask;
                write_mask_out <= data_write_mask_out;
                read_value_out <= data_read_value_in;
                write_value_out <= data_write_value_out;
    `endif

                valid_out <= valid_in;
                rd_out <= rd_in;
                rd_write_out <= rd_write_in;
                rd_fp_out <= rd_fp_in;

                if (amo_op_in != `RV32_AMO_NONE && !amo_misaligned) begin
                    if (amo_op_in == `RV32_AMO_SC)
                        rd_value_out <= sc_fail ? 32'd1 : 32'd0;
                    else if (amo_op_in == `RV32_AMO_LR)
                        rd_value_out <= data_read_value_in;
                    else
                        rd_value_out <= amo_old;
                end else if (read_in)
                    rd_value_out <= read_value;
                else if (csr_read_in)
                    rd_value_out <= csr_read_value;
                else
                    rd_value_out <= result_in;

    `ifdef RISCV_FORMAL
                if (flush_in)
                    trap_out <= 0;
    `endif

                if (flush_in || mem_exception) begin
                    valid_out <= 0;
                    rd_write_out <= 0;
                    rd_fp_out <= 0;
                end
            end
        end
        
        if (reset) begin
`ifdef RISCV_FORMAL
            trap_out <= 0;
`endif
            valid_out <= 0;
            rd_out <= 0;
            rd_write_out <= 0;
            rd_fp_out <= 0;
            rd_value_out <= 0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            amo_state <= AMO_IDLE;
            res_valid <= 1'b0;
            res_addr <= 30'b0;
            amo_old <= 32'b0;
        end else if (ce_i) begin
            if (amo_state == AMO_READ && data_ready_in && !amo_is_lr && amo_op_in != `RV32_AMO_NONE)
                amo_old <= data_read_value_in;

            if (amo_state != AMO_IDLE && amo_op_in == `RV32_AMO_NONE)
                amo_state <= AMO_IDLE;
            else if (amo_state == AMO_IDLE && amo_live && !amo_is_sc)
                amo_state <= AMO_READ;
            else if (amo_state == AMO_IDLE && amo_live && amo_is_sc)
                amo_state <= AMO_WRITE;
            else if (amo_state == AMO_READ && data_ready_in && amo_is_lr)
                amo_state <= AMO_IDLE;
            else if (amo_state == AMO_READ && data_ready_in)
                amo_state <= AMO_WRITE;
            else if (amo_state == AMO_WRITE && data_ready_in)
                amo_state <= AMO_IDLE;

            if (!flush_in && exception)
                res_valid <= 1'b0;
            else if (!flush_in && lr_done) begin
                res_valid <= 1'b1;
                res_addr <= result_in[31:2];
            end else if (!flush_in && amo_present && amo_is_sc && (sc_fail || wr_done))
                res_valid <= 1'b0;
            else if (!flush_in && wr_done && word_hit)
                res_valid <= 1'b0;
            else if (!flush_in && write_in && !mem_misaligned && !exception && word_hit)
                res_valid <= 1'b0;
        end
    end
endmodule

`endif
