`ifndef RV32_ALU
`define RV32_ALU

`define RV32_ALU_OP_ADD_SUB 5'b00000
`define RV32_ALU_OP_XOR     5'b00001
`define RV32_ALU_OP_OR      5'b00010
`define RV32_ALU_OP_AND     5'b00011
`define RV32_ALU_OP_SLL     5'b00100
`define RV32_ALU_OP_SRL_SRA 5'b00101
`define RV32_ALU_OP_SLT     5'b00110
`define RV32_ALU_OP_SLTU    5'b00111
`define RV32_ALU_OP_MUL     5'b01000
`define RV32_ALU_OP_MULH    5'b01001
`define RV32_ALU_OP_MULHSU  5'b01010
`define RV32_ALU_OP_MULHU   5'b01011
`define RV32_ALU_OP_FXMUL   5'b01100
`define RV32_ALU_OP_DIV     5'b01101
`define RV32_ALU_OP_DIVU    5'b01110
`define RV32_ALU_OP_REM     5'b01111
`define RV32_ALU_OP_REMU    5'b10000

`define RV32_ALU_SRC1_REG  2'b00
`define RV32_ALU_SRC1_PC   2'b01
`define RV32_ALU_SRC1_ZERO 2'b10

`define RV32_ALU_SRC2_REG  2'b00
`define RV32_ALU_SRC2_IMM  2'b01
`define RV32_ALU_SRC2_FOUR 2'b10

function logic signed [31:0] fix_mul(logic signed [31:0] x, logic signed [31:0] y);
    logic signed [63:0] x2, y2, mul2;
    begin
        x2 = {{32{x[31]}}, x};
        y2 = {{32{y[31]}}, y};
        mul2 = (x2 * y2) >>> 16;
        fix_mul = mul2[31:0];
    end
endfunction

module rv32_alu (
    input clk,
    input reset,
    input ce_i,
    input stall_in,
    input external_stall_in,

    /* control in */
    input [4:0] op_in,
    input sub_sra_in,
    input [1:0] src1_in,
    input [1:0] src2_in,
    input rd_write_in,

    /* data in */
    input [31:0] pc_in,
    input [31:0] rs1_value_in,
    input [31:0] rs2_value_in,
    input [31:0] imm_value_in,

    /* data out */
    output logic [31:0] result_out,
    output logic busy_out
);
    logic [31:0] src1;
    logic [31:0] src2;

    logic src1_sign;
    logic src2_sign;

    logic [4:0] shamt;

    logic [32:0] add_sub;
    logic [31:0] srl_sra;

    logic carry;
    logic sign;
    logic ovf;

    logic lt;
    logic ltu;

    always_comb begin
        case (src1_in)
            `RV32_ALU_SRC1_REG:  src1 = rs1_value_in;
            `RV32_ALU_SRC1_PC:   src1 = pc_in;
            `RV32_ALU_SRC1_ZERO: src1 = 0;
            default:             src1 = 32'bx;
        endcase

        case (src2_in)
            `RV32_ALU_SRC2_REG:  src2 = rs2_value_in;
            `RV32_ALU_SRC2_IMM:  src2 = imm_value_in;
            `RV32_ALU_SRC2_FOUR: src2 = 4;
            default:             src2 = 32'bx;
        endcase
    end

    assign src1_sign = src1[31];
    assign src2_sign = src2[31];

    assign shamt = src2[4:0];

    assign add_sub = sub_sra_in ? src1 - src2 : src1 + src2;
    assign srl_sra = $signed({sub_sra_in ? src1_sign : 1'b0, src1}) >>> shamt;

    assign carry = add_sub[32];
    assign sign  = add_sub[31];
    assign ovf   = (!src1_sign && src2_sign && sign) || (src1_sign && !src2_sign && !sign);

    assign lt  = sign != ovf;
    assign ltu = carry;

    logic mul_sign1, mul_sign2;
    assign mul_sign1 = src1_sign && (op_in == `RV32_ALU_OP_MULH);
    assign mul_sign2 = src2_sign && ((op_in == `RV32_ALU_OP_MULH) || (op_in == `RV32_ALU_OP_MULHSU));

    logic signed [32:0] mul_signed1, mul_signed2;
    assign mul_signed1 = {mul_sign1, src1};
    assign mul_signed2 = {mul_sign2, src2};

    logic signed [63:0] multiply;
    assign multiply = mul_signed1 * mul_signed2;

    // Multi-cycle divider.
    //
    // Start on rd_write && is_div_op, not pipeline valid_in. This core writebacks
    // from rd_write; valid can be 0 in EX while rd_write/op still describe a live
    // divide. Op-alone is unsafe: a flushed instr can leave a sticky alu_op.
    logic is_div_op;
    logic is_signed_div;
    logic div_start;
    logic [31:0] dividend;
    logic [31:0] divisor;
    logic [63:0] div_reg;
    logic [31:0] div_d;
    logic [31:0] div_src1;
    logic [5:0] div_ctr;
    logic div_active;
    logic div_ready;
    logic div_q_sign;
    logic div_r_sign;
    logic div_by_zero;
    logic [4:0] div_op;

    assign is_div_op = op_in == `RV32_ALU_OP_DIV ||
                       op_in == `RV32_ALU_OP_DIVU ||
                       op_in == `RV32_ALU_OP_REM ||
                       op_in == `RV32_ALU_OP_REMU;
    assign is_signed_div = op_in == `RV32_ALU_OP_DIV || op_in == `RV32_ALU_OP_REM;
    assign dividend = (is_signed_div && src1[31]) ? -src1 : src1;
    assign divisor = (is_signed_div && src2[31]) ? -src2 : src2;
    assign div_start = rd_write_in && is_div_op;
    assign busy_out = div_active || (div_start && !div_ready);

    logic [63:0] shifted;
    logic [32:0] sub;
    assign shifted = div_reg << 1;
    assign sub = {1'b0, shifted[63:32]} - {1'b0, div_d};

    always_ff @(posedge clk) begin
        if (reset) begin
            div_active <= 0;
            div_ready <= 0;
            div_ctr <= 0;
            div_op <= 0;
            div_reg <= 0;
            div_d <= 0;
            div_q_sign <= 0;
            div_r_sign <= 0;
            div_by_zero <= 0;
            div_src1 <= 0;
        end else if (ce_i) begin
            if (div_start && !div_active && !div_ready && !external_stall_in) begin
                div_active <= 1;
                div_ctr <= 31;
                div_op <= op_in;
                div_reg <= {32'b0, dividend};
                div_d <= divisor;
                div_src1 <= src1;
                div_q_sign <= is_signed_div && (src1[31] != src2[31]);
                div_r_sign <= is_signed_div && src1[31];
                div_by_zero <= (src2 == 0);
            end else if (div_active) begin
                if (div_ctr == 0) begin
                    div_active <= 0;
                    div_ready <= 1;
                end
                div_ctr <= div_ctr - 1;
                
                if (sub[32]) begin
                    div_reg <= {shifted[63:32], shifted[31:1], 1'b0};
                end else begin
                    div_reg <= {sub[31:0], shifted[31:1], 1'b1};
                end
            end else if (div_ready) begin
                if (!stall_in || !div_start) begin
                    div_ready <= 0;
                end
            end
        end
    end

    logic div_overflow;
    assign div_overflow = (div_op == `RV32_ALU_OP_DIV || div_op == `RV32_ALU_OP_REM) &&
                          (div_src1 == 32'h80000000) && (div_d == 32'hFFFFFFFF);

    logic [31:0] final_q, final_r;
    assign final_q = div_by_zero ? 32'hFFFFFFFF :
                     div_overflow ? 32'h80000000 :
                     (div_q_sign ? -div_reg[31:0] : div_reg[31:0]);

    assign final_r = div_by_zero ? div_src1 :
                     div_overflow ? 32'b0 :
                     (div_r_sign ? -div_reg[63:32] : div_reg[63:32]);

    always_comb begin
        result_out = 32'b0;
        if (div_ready) begin
            case (div_op)
                `RV32_ALU_OP_DIV,
                `RV32_ALU_OP_DIVU:    result_out = final_q;
                `RV32_ALU_OP_REM,
                `RV32_ALU_OP_REMU:    result_out = final_r;
                default:              result_out = 32'b0;
            endcase
        end else begin
            case (op_in)
                `RV32_ALU_OP_ADD_SUB: result_out = add_sub[31:0];
                `RV32_ALU_OP_XOR:     result_out = src1 ^ src2;
                `RV32_ALU_OP_OR:      result_out = src1 | src2;
                `RV32_ALU_OP_AND:     result_out = src1 & src2;
                `RV32_ALU_OP_SLL:     result_out = src1 << shamt;
                `RV32_ALU_OP_SRL_SRA: result_out = srl_sra;
                `RV32_ALU_OP_SLT:     result_out = {31'b0, lt};
                `RV32_ALU_OP_SLTU:    result_out = {31'b0, ltu};
                `RV32_ALU_OP_MUL:     result_out = multiply[31:0];
                `RV32_ALU_OP_MULH,
                `RV32_ALU_OP_MULHSU,
                `RV32_ALU_OP_MULHU:   result_out = multiply[63:32];
                `RV32_ALU_OP_FXMUL:   result_out = fix_mul(src1, src2);
                default:              result_out = 32'b0;
            endcase
        end
    end
endmodule

`endif
