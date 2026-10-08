`ifndef RV32_DECOMPRESS
`define RV32_DECOMPRESS

/* Expand an RV32IMFC compressed instruction to its 32-bit equivalent.
 * Reserved encodings expand to 32'h0, which the decoder treats as illegal.
 * Quadrant 0/2 slots used by D (C.FLD, C.FSD, C.FLDSP, C.FSDSP) are illegal. */
module rv32_decompress (
    input [15:0] instr_in,
    output logic [31:0] instr_out
);
    localparam logic [6:0] OP_IMM   = 7'b0010011;
    localparam logic [6:0] OP       = 7'b0110011;
    localparam logic [6:0] LUI      = 7'b0110111;
    localparam logic [6:0] JALR     = 7'b1100111;
    localparam logic [6:0] LOAD     = 7'b0000011;
    localparam logic [6:0] STORE    = 7'b0100011;
    localparam logic [6:0] LOAD_FP  = 7'b0000111;
    localparam logic [6:0] STORE_FP = 7'b0100111;
    localparam logic [6:0] SYSTEM   = 7'b1110011;

    function automatic logic [4:0] creg(input logic [2:0] r);
        creg = {2'b01, r};
    endfunction

    function automatic logic [31:0] i_type(
        input logic [11:0] imm,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        i_type = {imm, rs1, funct3, rd, opcode};
    endfunction

    function automatic logic [31:0] r_type(
        input logic [6:0] funct7,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd
    );
        r_type = {funct7, rs2, rs1, funct3, rd, OP};
    endfunction

    function automatic logic [31:0] s_type(
        input logic [11:0] imm,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [6:0] opcode
    );
        s_type = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
    endfunction

    function automatic logic [31:0] b_type(
        input logic [12:0] imm,
        input logic [4:0] rs1,
        input logic [2:0] funct3
    );
        b_type = {imm[12], imm[10:5], 5'b0, rs1, funct3, imm[4:1], imm[11], 7'b1100011};
    endfunction

    function automatic logic [31:0] j_type(
        input logic [20:0] imm,
        input logic [4:0] rd
    );
        j_type = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
    endfunction

    logic [4:0] rd;
    logic [4:0] rs2;
    logic [4:0] rd_p;
    logic [4:0] rs1_p;
    logic [4:0] rs2_p;

    /* CI / shift immediates are sign- or zero-extended at the use site. */
    logic [11:0] ci_imm;
    logic [11:0] addi16sp_imm;
    logic [19:0] lui_imm;
    logic [11:0] addi4spn_imm;
    logic [11:0] mem_imm;
    logic [11:0] sp_load_imm;
    logic [11:0] sp_store_imm;
    logic [11:0] j_off;
    logic [20:0] j_imm;
    logic [12:0] b_imm;
    logic [4:0] shamt;
    logic nz_ci;

    assign rd  = instr_in[11:7];
    assign rs2 = instr_in[6:2];
    assign rd_p  = creg(instr_in[4:2]);
    assign rs1_p = creg(instr_in[9:7]);
    assign rs2_p = creg(instr_in[4:2]);

    assign ci_imm = {{6{instr_in[12]}}, instr_in[12], instr_in[6:2]};
    assign addi16sp_imm = {{2{instr_in[12]}}, instr_in[12], instr_in[4:3], instr_in[5], instr_in[2], instr_in[6], 4'b0};
    assign lui_imm = {{14{instr_in[12]}}, instr_in[12], instr_in[6:2]};
    assign addi4spn_imm = {2'b0, instr_in[10:7], instr_in[12:11], instr_in[5], instr_in[6], 2'b0};
    assign mem_imm = {5'b0, instr_in[5], instr_in[12:10], instr_in[6], 2'b0};
    assign sp_load_imm = {4'b0, instr_in[3:2], instr_in[12], instr_in[6:4], 2'b0};
    assign sp_store_imm = {4'b0, instr_in[8:7], instr_in[12:9], 2'b0};
    assign j_off = {instr_in[12], instr_in[8], instr_in[10:9], instr_in[6], instr_in[7], instr_in[2], instr_in[11], instr_in[5:3], 1'b0};
    assign j_imm = {{9{j_off[11]}}, j_off};
    assign b_imm = {{5{instr_in[12]}}, instr_in[6:5], instr_in[2], instr_in[11:10], instr_in[4:3], 1'b0};
    assign shamt = instr_in[6:2];
    assign nz_ci = instr_in[12] != 1'b0 || instr_in[6:2] != 5'b0;

    always_comb begin
        instr_out = 32'h00000000;

        case (instr_in[1:0])
            2'b00: begin
                case (instr_in[15:13])
                    3'b000: begin
                        /* C.ADDI4SPN. nzuimm == 0 is reserved. */
                        if (instr_in[12:5] != 8'b0)
                            instr_out = i_type(addi4spn_imm, 5'd2, 3'b000, rd_p, OP_IMM);
                    end
                    3'b010: /* C.LW */
                        instr_out = i_type(mem_imm, rs1_p, 3'b010, rd_p, LOAD);
                    3'b011: /* C.FLW (RV32FC). C.LD is RV64. */
                        instr_out = i_type(mem_imm, rs1_p, 3'b010, rd_p, LOAD_FP);
                    3'b110: /* C.SW */
                        instr_out = s_type(mem_imm, rs2_p, rs1_p, 3'b010, STORE);
                    3'b111: /* C.FSW (RV32FC). C.SD is RV64. */
                        instr_out = s_type(mem_imm, rs2_p, rs1_p, 3'b010, STORE_FP);
                    default: ;
                endcase
            end
            2'b01: begin
                case (instr_in[15:13])
                    3'b000: /* C.ADDI / C.NOP (rd == 0 is a hint) */
                        instr_out = i_type(ci_imm, rd, 3'b000, rd, OP_IMM);
                    3'b001: /* C.JAL (RV32) */
                        instr_out = j_type(j_imm, 5'd1);
                    3'b010: /* C.LI (rd == 0 is a hint) */
                        instr_out = i_type(ci_imm, 5'd0, 3'b000, rd, OP_IMM);
                    3'b011: begin
                        if (rd == 5'd2 && nz_ci)
                            /* C.ADDI16SP. nzimm == 0 is reserved. */
                            instr_out = i_type(addi16sp_imm, 5'd2, 3'b000, 5'd2, OP_IMM);
                        else if (rd != 5'd0 && rd != 5'd2 && nz_ci)
                            /* C.LUI. nzimm == 0 is reserved. */
                            instr_out = {lui_imm, rd, LUI};
                        else if (rd == 5'd0)
                            /* C.LUI with rd == 0 is a hint, including a zero immediate. */
                            instr_out = {lui_imm, rd, LUI};
                    end
                    3'b100: begin
                        case (instr_in[11:10])
                            2'b00: begin
                                /* C.SRLI. shamt[5] == 1 is reserved on RV32. shamt == 0 is a hint. */
                                if (!instr_in[12])
                                    instr_out = i_type({7'b0000000, shamt}, rs1_p, 3'b101, rs1_p, OP_IMM);
                            end
                            2'b01: begin
                                /* C.SRAI. Same shamt rules as C.SRLI. */
                                if (!instr_in[12])
                                    instr_out = i_type({7'b0100000, shamt}, rs1_p, 3'b101, rs1_p, OP_IMM);
                            end
                            2'b10: /* C.ANDI */
                                instr_out = i_type(ci_imm, rs1_p, 3'b111, rs1_p, OP_IMM);
                            2'b11: begin
                                /* instr[12] selects the RV64 W ops, which are reserved on RV32. */
                                if (!instr_in[12]) begin
                                    case (instr_in[6:5])
                                        2'b00: instr_out = r_type(7'b0100000, rs2_p, rs1_p, 3'b000, rs1_p);
                                        2'b01: instr_out = r_type(7'b0000000, rs2_p, rs1_p, 3'b100, rs1_p);
                                        2'b10: instr_out = r_type(7'b0000000, rs2_p, rs1_p, 3'b110, rs1_p);
                                        2'b11: instr_out = r_type(7'b0000000, rs2_p, rs1_p, 3'b111, rs1_p);
                                    endcase
                                end
                            end
                        endcase
                    end
                    3'b101: /* C.J */
                        instr_out = j_type(j_imm, 5'd0);
                    3'b110: /* C.BEQZ */
                        instr_out = b_type(b_imm, rs1_p, 3'b000);
                    3'b111: /* C.BNEZ */
                        instr_out = b_type(b_imm, rs1_p, 3'b001);
                endcase
            end
            2'b10: begin
                case (instr_in[15:13])
                    3'b000: begin
                        /* C.SLLI. shamt[5] == 1 is reserved on RV32. rd == 0 is a hint. */
                        if (!instr_in[12])
                            instr_out = i_type({7'b0000000, shamt}, rd, 3'b001, rd, OP_IMM);
                    end
                    3'b010: begin
                        /* C.LWSP. rd == 0 is reserved. */
                        if (rd != 5'd0)
                            instr_out = i_type(sp_load_imm, 5'd2, 3'b010, rd, LOAD);
                    end
                    3'b011: /* C.FLWSP. f0 is a real destination, so rd == 0 is legal. */
                        instr_out = i_type(sp_load_imm, 5'd2, 3'b010, rd, LOAD_FP);
                    3'b100: begin
                        if (!instr_in[12]) begin
                            if (rs2 == 5'd0 && rd != 5'd0)
                                /* C.JR */
                                instr_out = i_type(12'b0, rd, 3'b000, 5'd0, JALR);
                            else if (rs2 != 5'd0)
                                /* C.MV. rd == 0 is a hint. */
                                instr_out = r_type(7'b0000000, rs2, 5'd0, 3'b000, rd);
                        end else begin
                            if (rs2 == 5'd0 && rd == 5'd0)
                                /* C.EBREAK */
                                instr_out = {12'b000000000001, 5'b0, 3'b000, 5'b0, SYSTEM};
                            else if (rs2 == 5'd0)
                                /* C.JALR */
                                instr_out = i_type(12'b0, rd, 3'b000, 5'd1, JALR);
                            else
                                /* C.ADD. rd == 0 is a hint. */
                                instr_out = r_type(7'b0000000, rs2, rd, 3'b000, rd);
                        end
                    end
                    3'b110: /* C.SWSP */
                        instr_out = s_type(sp_store_imm, rs2, 5'd2, 3'b010, STORE);
                    3'b111: /* C.FSWSP. Same stack immediate as C.SWSP. */
                        instr_out = s_type(sp_store_imm, rs2, 5'd2, 3'b010, STORE_FP);
                    default: ;
                endcase
            end
            default: ;
        endcase
    end
endmodule

`endif
