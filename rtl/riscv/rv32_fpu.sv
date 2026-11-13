// RISC-V F / IEEE 754-2008 binary32 FPU.
//
// Five rounding modes (RNE, RTZ, RDN, RUP, RMM), subnormals, signed zeros,
// infinities, RISC-V canonical NaNs, and accrued exception flags.
// Division and square root are restoring significand digit recurrences.
// Arithmetic NaNs are the canonical quiet NaN 0x7fc00000. No exception traps.
//
// The pipeline contract matches the previous unit: wr starts an operation,
// busy is high while it runs, and out/fflags stay valid through the commit
// cycle after busy falls.

`ifndef RV32_FPU
`define RV32_FPU

module rv32_fpu (
    input             clk,
    input             reset,
    input             ce,
    input             wr,
    input      [31:2] instr,
    input      [2:0]  frm,
    input      [31:0] rs1,
    input      [31:0] rs2,
    input      [31:0] rs3,
    output            busy,
    output     [31:0] out,
    output     [4:0]  fflags,
    output            fflags_valid
);

    localparam [4:0] F_NX = 5'b00001;
    localparam [4:0] F_UF = 5'b00010;
    localparam [4:0] F_OF = 5'b00100;
    localparam [4:0] F_DZ = 5'b01000;
    localparam [4:0] F_NV = 5'b10000;
    localparam [31:0] CANON_NAN = 32'h7fc00000;

    localparam [3:0] ST_IDLE  = 4'd0;
    localparam [3:0] ST_ALIGN = 4'd1;
    localparam [3:0] ST_ADD   = 4'd2;
    localparam [3:0] ST_NORM  = 4'd3;
    localparam [3:0] ST_PACK  = 4'd4;
    localparam [3:0] ST_MUL   = 4'd5;
    localparam [3:0] ST_DIV   = 4'd6;
    localparam [3:0] ST_SQRT  = 4'd7;
    localparam [3:0] ST_F2I   = 4'd8;

    localparam [2:0] RM_RNE = 3'b000;
    localparam [2:0] RM_RTZ = 3'b001;
    localparam [2:0] RM_RDN = 3'b010;
    localparam [2:0] RM_RUP = 3'b011;
    localparam [2:0] RM_RMM = 3'b100;

    reg isFMADD, isFMSUB, isFNMSUB, isFNMADD;
    reg isFADD, isFSUB, isFMUL, isFDIV, isFSQRT;
    reg isFSGNJ, isFSGNJN, isFSGNJX;
    reg isFMIN, isFMAX;
    reg isFEQ, isFLT, isFLE;
    reg isFCLASS, isFCVTWS, isFCVTWUS;
    reg isFCVTSW, isFCVTSWU;
    reg isFMVXW, isFMVWX;

    always_comb begin
        isFMADD   = (instr[4:2] == 3'b000);
        isFMSUB   = (instr[4:2] == 3'b001);
        isFNMSUB  = (instr[4:2] == 3'b010);
        isFNMADD  = (instr[4:2] == 3'b011);
        isFADD    = (instr[4] && (instr[31:27] == 5'b00000));
        isFSUB    = (instr[4] && (instr[31:27] == 5'b00001));
        isFMUL    = (instr[4] && (instr[31:27] == 5'b00010));
        isFDIV    = (instr[4] && (instr[31:27] == 5'b00011));
        isFSQRT   = (instr[4] && (instr[31:27] == 5'b01011));
        isFSGNJ   = (instr[4] && (instr[31:27] == 5'b00100) && (instr[13:12] == 2'b00));
        isFSGNJN  = (instr[4] && (instr[31:27] == 5'b00100) && (instr[13:12] == 2'b01));
        isFSGNJX  = (instr[4] && (instr[31:27] == 5'b00100) && (instr[13:12] == 2'b10));
        isFMIN    = (instr[4] && (instr[31:27] == 5'b00101) && !instr[12]);
        isFMAX    = (instr[4] && (instr[31:27] == 5'b00101) &&  instr[12]);
        isFEQ     = (instr[4] && (instr[31:27] == 5'b10100) && (instr[13:12] == 2'b10));
        isFLT     = (instr[4] && (instr[31:27] == 5'b10100) && (instr[13:12] == 2'b01));
        isFLE     = (instr[4] && (instr[31:27] == 5'b10100) && (instr[13:12] == 2'b00));
        isFCLASS  = (instr[4] && (instr[31:27] == 5'b11100) &&  instr[12]);
        isFCVTWS  = (instr[4] && (instr[31:27] == 5'b11000) && !instr[20]);
        isFCVTWUS = (instr[4] && (instr[31:27] == 5'b11000) &&  instr[20]);
        isFCVTSW  = (instr[4] && (instr[31:27] == 5'b11010) && !instr[20]);
        isFCVTSWU = (instr[4] && (instr[31:27] == 5'b11010) &&  instr[20]);
        isFMVXW   = (instr[4] && (instr[31:27] == 5'b11100) && !instr[12]);
        isFMVWX   = (instr[4] && (instr[31:27] == 5'b11110));
    end

    function automatic logic is_snan(input [31:0] v);
        is_snan = (v[30:23] == 8'hff) && !v[22] && (v[21:0] != 0);
    endfunction

    function automatic logic is_qnan(input [31:0] v);
        is_qnan = (v[30:23] == 8'hff) && v[22];
    endfunction

    function automatic logic is_nan(input [31:0] v);
        is_nan = (v[30:23] == 8'hff) && (v[22:0] != 0);
    endfunction

    function automatic logic is_inf(input [31:0] v);
        is_inf = (v[30:23] == 8'hff) && (v[22:0] == 0);
    endfunction

    function automatic logic is_zero(input [31:0] v);
        is_zero = (v[30:0] == 0);
    endfunction

    /* True biased exponent and 24-bit significand. Subnormals are normalized.
     * A zero yields sig=0 and exp=0. Infinities and NaNs are not unpacked. */
    function automatic void unpack(input [31:0] v, output logic sign,
                                   output logic signed [15:0] exp, output logic [23:0] sig);
        integer msb;
        integer sh;
        integer i;
        begin
            sign = v[31];
            if (v[30:23] == 0) begin
                if (v[22:0] == 0) begin
                    exp = 0;
                    sig = 0;
                end else begin
                    msb = 0;
                    for (i = 0; i < 23; i = i + 1)
                        if (v[i]) msb = i;
                    sh = 23 - msb;
                    sig = {1'b0, v[22:0]} << sh;
                    exp = 16'sd1 - 16'(sh);
                end
            end else begin
                exp = {8'b0, v[30:23]};
                sig = {1'b1, v[22:0]};
            end
        end
    endfunction

    function automatic [31:0] shr_jam32(input [31:0] a, input [15:0] amt);
        begin
            if (amt == 0)
                shr_jam32 = a;
            else if (amt >= 16'd31)
                shr_jam32 = {31'b0, a != 0};
            else
                shr_jam32 = (a >> amt) | {31'b0, |(a & ~({32{1'b1}} << amt))};
        end
    endfunction

    function automatic [63:0] shr_jam64(input [63:0] a, input [15:0] amt);
        begin
            if (amt == 0)
                shr_jam64 = a;
            else if (amt >= 16'd64)
                shr_jam64 = {63'b0, a != 0};
            else
                shr_jam64 = (a >> amt) | {63'b0, |(a & ~({64{1'b1}} << amt))};
        end
    endfunction

    /* {shifted[95:0], sticky}. amt>=96 collapses to a sticky bit. */
    function automatic [96:0] shr96(input [95:0] a, input [15:0] amt);
        logic [95:0] s;
        begin
            if (amt == 0)
                shr96 = {a, 1'b0};
            else if (amt >= 16'd96)
                shr96 = {96'b0, |a};
            else begin
                s = a >> amt;
                shr96 = {s, |(a & ~({96{1'b1}} << amt))};
            end
        end
    endfunction

    function automatic [31:0] wide_sig(input [95:0] frac, input sticky);
        logic [31:0] sig;
        begin
            sig = {1'b0, frac[47:17]};
            if (sticky || (|frac[16:0]))
                sig[0] = 1'b1;
            wide_sig = sig;
        end
    endfunction

    function automatic logic mag_less_raw(input [31:0] a, input [31:0] b);
        begin
            if (a[30:23] != b[30:23])
                mag_less_raw = a[30:23] < b[30:23];
            else
                mag_less_raw = a[22:0] < b[22:0];
        end
    endfunction

    function automatic logic flt_raw(input [31:0] a, input [31:0] b);
        begin
            if (is_zero(a) && is_zero(b))
                flt_raw = 1'b0;
            else if (a[31] != b[31])
                flt_raw = a[31];
            else if (a[31])
                flt_raw = mag_less_raw(b, a);
            else
                flt_raw = mag_less_raw(a, b);
        end
    endfunction

    function automatic [31:0] fclass_of(input [31:0] v);
        logic exp_z, exp_ff, frac_z;
        begin
            exp_z = (v[30:23] == 0);
            exp_ff = (v[30:23] == 8'hff);
            frac_z = (v[22:0] == 0);
            fclass_of = {
                22'b0,
                exp_ff & v[22],
                exp_ff & ~v[22] & (|v[21:0]),
                ~v[31] & exp_ff & frac_z,
                ~v[31] & ~exp_z & ~exp_ff,
                ~v[31] & exp_z & ~frac_z,
                ~v[31] & exp_z & frac_z,
                v[31] & exp_z & frac_z,
                v[31] & exp_z & ~frac_z,
                v[31] & ~exp_z & ~exp_ff,
                v[31] & exp_ff & frac_z
            };
        end
    endfunction

    /* Float to int, shift half. Mirrors SoftFloat f32_to_{i,ui}32 up to the
     * rounding add. Bit 117 set means {flags,z} is already final. */
    function automatic [117:0] f2i_align(input [31:0] a, input unsign, input [2:0] rm);
        logic sign;
        logic [7:0] exp;
        logic [23:0] sig;
        logic [63:0] sig64;
        logic signed [15:0] shift_dist;
        logic [15:0] round_inc;
        logic [31:0] z;
        logic [4:0] flags;
        logic early;
        begin
            sign = a[31];
            exp = a[30:23];
            sig = {1'b0, a[22:0]};
            sig64 = 64'b0;
            round_inc = 16'b0;
            early = 1'b0;
            flags = 5'b0;
            z = 32'b0;
            if ((exp == 8'hff) && (a[22:0] != 0)) begin
                flags = F_NV;
                z = unsign ? 32'hffffffff : 32'h7fffffff;
                early = 1'b1;
            end
            if (!early) begin
                if (exp != 0)
                    sig[23] = 1'b1;
                sig64 = {8'b0, sig, 32'b0};
                shift_dist = 16'sh00aa - {8'b0, exp};
                if (shift_dist > 0)
                    sig64 = shr_jam64(sig64, shift_dist[15:0]);
                round_inc = 16'h0800;
                if ((rm != RM_RMM) && (rm != RM_RNE)) begin
                    round_inc = 16'h0000;
                    if (unsign) begin
                        if (sign) begin
                            if (sig64 == 0) begin
                                z = 0;
                                early = 1'b1;
                            end else if (rm == RM_RDN) begin
                                flags = F_NV;
                                z = 32'h00000000;
                                early = 1'b1;
                            end
                        end else if (rm == RM_RUP) begin
                            round_inc = 16'h0fff;
                        end
                    end else if (sign ? (rm == RM_RDN) : (rm == RM_RUP)) begin
                        round_inc = 16'h0fff;
                    end
                end
            end
            f2i_align = {early, flags, z, round_inc, sig64};
        end
    endfunction

    function automatic [5:0] clz32(input [31:0] a);
        integer i;
        begin
            clz32 = 6'd32;
            for (i = 31; i >= 0; i = i - 1)
                if (a[i] && (clz32 == 6'd32))
                    clz32 = 6'(31 - i);
        end
    endfunction

    /* Integer to binary32, before round_pack. Returns {sign, exp[15:0], sig[31:0]}.
     * Rounding happens on the following cycle from the pack registers. */
    function automatic [48:0] i2f_align(input [31:0] a, input unsign);
        logic sign;
        logic [31:0] mag;
        logic [5:0] lz;
        logic signed [15:0] bit_i;
        logic signed [15:0] sh;
        logic [31:0] sig;
        logic signed [15:0] exp;
        begin
            if (!unsign && a[31]) begin
                sign = 1'b1;
                mag = ~a + 32'd1;
            end else begin
                sign = 1'b0;
                mag = a;
            end
            lz = clz32(mag);
            bit_i = 16'sd31 - {10'b0, lz};
            sh = 16'sd30 - bit_i;
            exp = bit_i + 16'sd126;
            if (sh >= 0)
                sig = mag << sh[4:0];
            else
                sig = shr_jam32(mag, (-sh));
            i2f_align = {sign, exp, sig};
        end
    endfunction

    reg [3:0] state;
    reg [31:0] result_q;
    reg [4:0] flags_q;
    reg flags_pulse;

    reg x_sign, y_sign;
    reg signed [15:0] x_exp, y_exp;
    reg [95:0] x_frac, y_frac;
    reg x_sticky;
    reg do_sub;

    reg [95:0] sum_frac;
    reg sum_sticky;
    reg sum_sign;
    reg signed [15:0] sum_exp;

    reg pack_sign;
    reg signed [15:0] pack_exp;
    reg [31:0] pack_sig;
    reg [2:0] rm_q;
    reg fma_pend;

    reg [54:0] div_rem;
    reg [23:0] div_b;
    reg [31:0] div_quot;
    reg [5:0] div_bit;
    reg div_sign;
    reg signed [15:0] div_exp;

    reg [51:0] sqrt_rad;
    reg [63:0] sqrt_rem;
    reg [25:0] sqrt_root;
    reg [5:0] sqrt_left;
    reg signed [15:0] sqrt_exp;

    reg [95:0] norm_frac;
    reg [63:0] f2i_sig;
    reg [15:0] f2i_inc;
    reg f2i_sign;
    reg f2i_uns;

    /* Rounding stays in its own module so synth cannot share those adders
     * with the cache/address cone and bypass these registers. */
    wire [36:0] pack_rounded;
    wire [36:0] f2i_rounded;
    fpu_finish finish (
        .pack_sign(pack_sign),
        .pack_exp(pack_exp),
        .pack_sig(pack_sig),
        .rm(rm_q),
        .f2i_sig(f2i_sig),
        .f2i_inc(f2i_inc),
        .f2i_sign(f2i_sign),
        .f2i_uns(f2i_uns),
        .pack_out(pack_rounded),
        .f2i_out(f2i_rounded)
    );
    wire [6:0] norm_clz;
    CLZ #(.W_IN(128)) clz_norm (
        .in({32'b0, norm_frac}),
        .out(norm_clz)
    );

    assign busy = (state != ST_IDLE);
    assign out = result_q;
    assign fflags = flags_q;
    assign fflags_valid = flags_pulse;

    wire [2:0] rm_now = (instr[14:12] == 3'b111) ? frm : instr[14:12];

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= ST_IDLE;
            result_q <= 32'b0;
            flags_q <= 5'b0;
            flags_pulse <= 1'b0;
        end else if (ce) begin
            flags_pulse <= 1'b0;
            if (wr && (state == ST_IDLE)) begin
                rm_q <= rm_now;
                fma_pend <= 1'b0;
                begin : issue
                    logic a_sign, b_sign, c_sign;
                    logic signed [15:0] a_exp, b_exp, c_exp;
                    logic [23:0] a_sig, b_sig, c_sig;
                    logic b_sign_eff, c_sign_eff, p_sign;
                    logic [4:0] fl;
                    logic [31:0] res;
                    logic done;

                    unpack(rs1, a_sign, a_exp, a_sig);
                    unpack(rs2, b_sign, b_exp, b_sig);
                    unpack(rs3, c_sign, c_exp, c_sig);
                    b_sign_eff = b_sign ^ isFSUB;
                    c_sign_eff = c_sign ^ (isFMSUB | isFNMADD);
                    p_sign = a_sign ^ b_sign ^ (isFNMSUB | isFNMADD);
                    done = 1'b1;
                    fl = 5'b0;
                    res = 32'b0;

                    if (isFSGNJ) begin
                        res = {rs2[31], rs1[30:0]};
                    end else if (isFSGNJN) begin
                        res = {~rs2[31], rs1[30:0]};
                    end else if (isFSGNJX) begin
                        res = {rs1[31] ^ rs2[31], rs1[30:0]};
                    end else if (isFMVXW || isFMVWX) begin
                        res = rs1;
                    end else if (isFCLASS) begin
                        res = fclass_of(rs1);
                    end else if (isFEQ || isFLT || isFLE) begin
                        if (is_nan(rs1) || is_nan(rs2)) begin
                            res = 32'b0;
                            if (isFEQ)
                                fl = (is_snan(rs1) || is_snan(rs2)) ? F_NV : 5'b0;
                            else
                                fl = F_NV;
                        end else if (isFEQ) begin
                            res = {31'b0, (is_zero(rs1) && is_zero(rs2)) || (rs1 == rs2)};
                        end else if (isFLT) begin
                            res = {31'b0, flt_raw(rs1, rs2)};
                        end else begin
                            res = {31'b0, flt_raw(rs1, rs2) ||
                                          ((is_zero(rs1) && is_zero(rs2)) || (rs1 == rs2))};
                        end
                    end else if (isFMIN || isFMAX) begin
                        if (is_nan(rs1) && is_nan(rs2)) begin
                            res = CANON_NAN;
                            fl = (is_snan(rs1) || is_snan(rs2)) ? F_NV : 5'b0;
                        end else if (is_nan(rs1)) begin
                            res = rs2;
                            fl = is_snan(rs1) ? F_NV : 5'b0;
                        end else if (is_nan(rs2)) begin
                            res = rs1;
                            fl = is_snan(rs2) ? F_NV : 5'b0;
                        end else if (is_zero(rs1) && is_zero(rs2)) begin
                            res = isFMIN ? ({31'b0, rs1[31] | rs2[31]} << 31) : 32'b0;
                        end else if (isFMIN) begin
                            res = flt_raw(rs1, rs2) ? rs1 : rs2;
                        end else begin
                            res = flt_raw(rs2, rs1) ? rs1 : rs2;
                        end
                    end else if (isFCVTWS || isFCVTWUS) begin
                        logic [117:0] al;
                        al = f2i_align(rs1, isFCVTWUS, rm_now);
                        if (al[117]) begin
                            fl = al[116:112];
                            res = al[111:80];
                        end else begin
                            done = 1'b0;
                            f2i_sig <= al[63:0];
                            f2i_inc <= al[79:64];
                            f2i_sign <= rs1[31];
                            f2i_uns <= isFCVTWUS;
                            state <= ST_F2I;
                        end
                    end else if (isFCVTSW || isFCVTSWU) begin
                        logic [48:0] al;
                        if (rs1 == 0) begin
                            res = 32'b0;
                        end else if (!isFCVTSWU && (rs1 == 32'h80000000)) begin
                            res = 32'hcf000000;
                        end else begin
                            al = i2f_align(rs1, isFCVTSWU);
                            done = 1'b0;
                            pack_sign <= al[48];
                            pack_exp <= al[47:32];
                            pack_sig <= al[31:0];
                            state <= ST_PACK;
                        end
                    end else if (isFADD || isFSUB) begin
                        if (is_snan(rs1) || is_snan(rs2)) begin
                            res = CANON_NAN;
                            fl = F_NV;
                        end else if (is_qnan(rs1) || is_qnan(rs2)) begin
                            res = CANON_NAN;
                        end else if (is_inf(rs1) && is_inf(rs2) && (a_sign != b_sign_eff)) begin
                            res = CANON_NAN;
                            fl = F_NV;
                        end else if (is_inf(rs1)) begin
                            res = {a_sign, 8'hff, 23'b0};
                        end else if (is_inf(rs2)) begin
                            res = {b_sign_eff, 8'hff, 23'b0};
                        end else if ((a_sig == 0) && (b_sig == 0)) begin
                            res = {((a_sign == b_sign_eff) ? b_sign_eff : (rm_now == RM_RDN)), 31'b0};
                        end else begin
                            done = 1'b0;
                            x_sign <= a_sign;
                            y_sign <= b_sign_eff;
                            x_exp <= a_exp;
                            y_exp <= b_exp;
                            x_frac <= (a_sig == 0) ? 96'b0 : {48'b0, a_sig, 24'b0};
                            y_frac <= (b_sig == 0) ? 96'b0 : {48'b0, b_sig, 24'b0};
                            x_sticky <= 1'b0;
                            state <= ST_ALIGN;
                        end
                    end else if (isFMUL || isFMADD || isFMSUB || isFNMADD || isFNMSUB) begin
                        if (is_snan(rs1) || is_snan(rs2) ||
                            ((isFMADD || isFMSUB || isFNMADD || isFNMSUB) && is_snan(rs3))) begin
                            res = CANON_NAN;
                            fl = F_NV;
                        end else if (is_qnan(rs1) || is_qnan(rs2) ||
                                     ((isFMADD || isFMSUB || isFNMADD || isFNMSUB) && is_qnan(rs3))) begin
                            /* 0*inf is invalid even when the addend is a quiet NaN. */
                            if ((isFMADD || isFMSUB || isFNMADD || isFNMSUB) &&
                                ((is_inf(rs1) && (b_sig == 0) && !is_nan(rs2) && !is_inf(rs2)) ||
                                 (is_inf(rs2) && (a_sig == 0) && !is_nan(rs1) && !is_inf(rs1))))
                                fl = F_NV;
                            res = CANON_NAN;
                        end else if (is_inf(rs1) || is_inf(rs2)) begin
                            if ((is_inf(rs1) && (b_sig == 0) && !is_inf(rs2)) ||
                                (is_inf(rs2) && (a_sig == 0) && !is_inf(rs1))) begin
                                res = CANON_NAN;
                                fl = F_NV;
                            end else if (isFMUL) begin
                                res = {p_sign, 8'hff, 23'b0};
                            end else if (is_inf(rs3) && (p_sign != c_sign_eff)) begin
                                res = CANON_NAN;
                                fl = F_NV;
                            end else begin
                                res = {p_sign, 8'hff, 23'b0};
                            end
                        end else if (isFMUL && ((a_sig == 0) || (b_sig == 0))) begin
                            res = {p_sign, 31'b0};
                        end else if ((isFMADD || isFMSUB || isFNMADD || isFNMSUB) &&
                                     ((a_sig == 0) || (b_sig == 0))) begin
                            if (is_inf(rs3))
                                res = {c_sign_eff, 8'hff, 23'b0};
                            else if (c_sig == 0)
                                res = {((p_sign == c_sign_eff) ? c_sign_eff : (rm_now == RM_RDN)), 31'b0};
                            else
                                res = {c_sign_eff, rs3[30:0]};
                        end else if ((isFMADD || isFMSUB || isFNMADD || isFNMSUB) && is_inf(rs3)) begin
                            res = {c_sign_eff, 8'hff, 23'b0};
                        end else begin
                            done = 1'b0;
                            x_sign <= p_sign;
                            x_exp <= a_exp;
                            y_exp <= b_exp;
                            x_frac <= {72'b0, a_sig};
                            y_frac <= {72'b0, b_sig};
                            state <= ST_MUL;
                            fma_pend <= isFMADD | isFMSUB | isFNMADD | isFNMSUB;
                            /* Park the addend in the Y fields after the multiply overwrites them.
                             * Saved below into sum_* as a side channel until MUL completes. */
                            sum_sign <= c_sign_eff;
                            sum_exp <= c_exp;
                            sum_frac <= (c_sig == 0) ? 96'b0 : {48'b0, c_sig, 24'b0};
                            sum_sticky <= 1'b0;
                        end
                    end else if (isFDIV) begin
                        if (is_snan(rs1) || is_snan(rs2)) begin
                            res = CANON_NAN;
                            fl = F_NV;
                        end else if (is_qnan(rs1) || is_qnan(rs2)) begin
                            res = CANON_NAN;
                        end else if ((is_inf(rs1) && is_inf(rs2)) || ((a_sig == 0) && (b_sig == 0))) begin
                            res = CANON_NAN;
                            fl = F_NV;
                        end else if (is_inf(rs1)) begin
                            res = {a_sign ^ b_sign, 8'hff, 23'b0};
                        end else if (is_inf(rs2)) begin
                            res = {a_sign ^ b_sign, 31'b0};
                        end else if (b_sig == 0) begin
                            res = {a_sign ^ b_sign, 8'hff, 23'b0};
                            fl = F_DZ;
                        end else if (a_sig == 0) begin
                            res = {a_sign ^ b_sign, 31'b0};
                        end else begin
                            done = 1'b0;
                            div_sign <= a_sign ^ b_sign;
                            div_b <= b_sig;
                            div_quot <= 32'b0;
                            div_bit <= 6'd31;
                            if (a_sig < b_sig) begin
                                div_rem <= {a_sig, 31'b0};
                                div_exp <= a_exp - b_exp + 16'sd126 - 16'sd1;
                            end else begin
                                div_rem <= {a_sig, 30'b0};
                                div_exp <= a_exp - b_exp + 16'sd126;
                            end
                            state <= ST_DIV;
                        end
                    end else if (isFSQRT) begin
                        if (is_snan(rs1)) begin
                            res = CANON_NAN;
                            fl = F_NV;
                        end else if (is_qnan(rs1)) begin
                            res = CANON_NAN;
                        end else if (is_zero(rs1)) begin
                            res = {a_sign, 31'b0};
                        end else if (is_inf(rs1) && !a_sign) begin
                            res = {1'b0, 8'hff, 23'b0};
                        end else if (a_sign) begin
                            res = CANON_NAN;
                            fl = F_NV;
                        end else begin
                            done = 1'b0;
                            sqrt_exp <= ((a_exp - 16'sd127) >>> 1) + 16'sd126;
                            /* Unbiased exponent LSB selects the even/odd radicand. */
                            if (((a_exp - 16'sd127) & 16'sd1) != 0)
                                sqrt_rad <= {a_sig, 28'b0};
                            else
                                sqrt_rad <= {1'b0, a_sig, 27'b0};
                            sqrt_rem <= 64'b0;
                            sqrt_root <= 26'b0;
                            sqrt_left <= 6'd26;
                            state <= ST_SQRT;
                        end
                    end

                    if (done) begin
                        result_q <= res;
                        flags_q <= fl;
                        flags_pulse <= 1'b1;
                        state <= ST_IDLE;
                    end
                end
            end else if (state == ST_ALIGN) begin
                logic x_zero, y_zero, x_bigger;
                logic signed [15:0] big_exp, small_exp, diff;
                logic big_sign, small_sign;
                logic [95:0] big_frac, small_frac;
                logic [96:0] sh;
                x_zero = (x_frac == 0);
                y_zero = (y_frac == 0);
                x_bigger = 1'b0;
                if (y_zero && !x_zero)
                    x_bigger = 1'b1;
                else if (!x_zero && !y_zero) begin
                    if (x_exp > y_exp)
                        x_bigger = 1'b1;
                    else if ((x_exp == y_exp) && (x_frac > y_frac))
                        x_bigger = 1'b1;
                end
                if (x_bigger) begin
                    big_frac = x_frac;
                    big_exp = x_exp;
                    big_sign = x_sign;
                    small_frac = y_frac;
                    small_exp = y_exp;
                    small_sign = y_sign;
                end else begin
                    big_frac = y_frac;
                    big_exp = y_exp;
                    big_sign = y_sign;
                    small_frac = x_frac;
                    small_exp = x_exp;
                    small_sign = x_sign;
                end
                diff = big_exp - small_exp;
                if ((small_frac == 0) || (diff < 0))
                    diff = 0;
                sh = shr96(small_frac, diff);
                y_frac <= big_frac;
                y_exp <= big_exp;
                y_sign <= big_sign;
                x_frac <= sh[96:1];
                x_sticky <= sh[0];
                x_sign <= small_sign;
                x_exp <= big_exp;
                do_sub <= big_sign ^ small_sign;
                state <= ST_ADD;
            end else if (state == ST_ADD) begin
                logic [96:0] acc;
                logic [95:0] mag;
                logic st;
                logic signed [15:0] expn;
                if (do_sub) begin
                    acc = {1'b0, y_frac} - {1'b0, x_frac};
                    if (x_sticky) begin
                        if (acc == 0) begin
                            mag = 96'b0;
                            expn = y_exp;
                            st = 1'b1;
                        end else begin
                            mag = acc[95:0] - 96'd1;
                            expn = y_exp;
                            st = 1'b1;
                        end
                    end else begin
                        mag = acc[95:0];
                        expn = y_exp;
                        st = 1'b0;
                    end
                end else begin
                    acc = {1'b0, y_frac} + {1'b0, x_frac};
                    mag = acc[95:0];
                    expn = y_exp;
                    st = x_sticky;
                end
                norm_frac <= mag;
                sum_sticky <= st;
                sum_sign <= y_sign;
                sum_exp <= expn;
                state <= ST_NORM;
            end else if (state == ST_NORM) begin
                logic signed [15:0] sh;
                logic [95:0] shifted;
                logic st;
                logic [96:0] shs;
                if ((norm_frac == 0) && !sum_sticky) begin
                    result_q <= {do_sub ? (rm_q == RM_RDN) : sum_sign, 31'b0};
                    flags_q <= 5'b0;
                    flags_pulse <= 1'b1;
                    state <= ST_IDLE;
                end else if (norm_frac == 0) begin
                    pack_sign <= sum_sign;
                    pack_exp <= -16'sd200;
                    pack_sig <= 32'h00000001;
                    state <= ST_PACK;
                end else begin
                    sh = {9'b0, norm_clz} - 16'sd80;
                    if (sh > 0) begin
                        shifted = norm_frac << sh[6:0];
                        st = sum_sticky;
                    end else if (sh < 0) begin
                        shs = shr96(norm_frac, -sh);
                        shifted = shs[96:1];
                        st = sum_sticky | shs[0];
                    end else begin
                        shifted = norm_frac;
                        st = sum_sticky;
                    end
                    pack_sign <= sum_sign;
                    /* sum_exp is the true biased exponent of bit 47. Pack wants that minus 1. */
                    pack_exp <= sum_exp - sh - 16'sd1;
                    pack_sig <= wide_sig(shifted, st);
                    state <= ST_PACK;
                end
            end else if (state == ST_PACK) begin
                result_q <= pack_rounded[31:0];
                flags_q <= pack_rounded[36:32];
                flags_pulse <= 1'b1;
                state <= ST_IDLE;
            end else if (state == ST_F2I) begin
                result_q <= f2i_rounded[31:0];
                flags_q <= f2i_rounded[36:32];
                flags_pulse <= 1'b1;
                state <= ST_IDLE;
            end else if (state == ST_MUL) begin
                logic [47:0] prod;
                logic signed [15:0] expm;
                logic [95:0] frac;
                prod = x_frac[23:0] * y_frac[23:0];
                if (prod[47]) begin
                    frac = {48'b0, prod};
                    expm = x_exp + y_exp - 16'sd126;
                end else begin
                    frac = {48'b0, prod[46:0], 1'b0};
                    expm = x_exp + y_exp - 16'sd127;
                end
                if (fma_pend) begin
                    x_frac <= frac;
                    x_exp <= expm;
                    x_sticky <= 1'b0;
                    y_sign <= sum_sign;
                    y_exp <= sum_exp;
                    y_frac <= sum_frac;
                    state <= ST_ALIGN;
                end else begin
                    pack_sign <= x_sign;
                    pack_exp <= expm - 16'sd1;
                    pack_sig <= wide_sig(frac, 1'b0);
                    state <= ST_PACK;
                end
            end else if (state == ST_DIV) begin
                logic [54:0] sub;
                logic [54:0] rem_n;
                logic [31:0] quot_n;
                logic [31:0] sig;
                sub = {31'b0, div_b} << div_bit;
                rem_n = div_rem;
                quot_n = div_quot;
                if (rem_n >= sub) begin
                    rem_n = rem_n - sub;
                    quot_n[div_bit] = 1'b1;
                end
                div_rem <= rem_n;
                div_quot <= quot_n;
                if (div_bit == 0) begin
                    sig = quot_n;
                    if ((sig[5:0] == 0) && (rem_n != 0))
                        sig[0] = 1'b1;
                    pack_sign <= div_sign;
                    pack_exp <= div_exp;
                    pack_sig <= sig;
                    state <= ST_PACK;
                end else begin
                    div_bit <= div_bit - 6'd1;
                end
            end else if (state == ST_SQRT) begin
                logic [1:0] top;
                logic [63:0] rem_n;
                logic [51:0] rad_n;
                logic [25:0] root_n;
                logic [63:0] trial;
                logic [31:0] sig;
                top = sqrt_rad[51:50];
                rad_n = {sqrt_rad[49:0], 2'b0};
                rem_n = {sqrt_rem[61:0], top};
                trial = {36'b0, sqrt_root, 2'b01};
                if (rem_n >= trial) begin
                    rem_n = rem_n - trial;
                    root_n = {sqrt_root[24:0], 1'b1};
                end else begin
                    root_n = {sqrt_root[24:0], 1'b0};
                end
                sqrt_rad <= rad_n;
                sqrt_rem <= rem_n;
                sqrt_root <= root_n;
                if (sqrt_left == 6'd1) begin
                    sig = {1'b0, root_n[25:1], 6'b0};
                    if (root_n[0] || (rem_n != 0))
                        sig[0] = 1'b1;
                    pack_sign <= 1'b0;
                    pack_exp <= sqrt_exp;
                    pack_sig <= sig;
                    state <= ST_PACK;
                end else begin
                    sqrt_left <= sqrt_left - 6'd1;
                end
            end
        end
    end
endmodule

/* Count leading zeros. W_IN must be a power of two. */
module CLZ #(
    parameter W_IN = 64,
    parameter W_OUT = $clog2(W_IN)
) (
    input  wire [W_IN-1:0]  in,
    output wire [W_OUT-1:0] out
);
    generate
        if (W_IN == 2) begin
            assign out = !in[1];
        end else begin
            wire [W_OUT-2:0] half_count;
            wire [W_IN/2-1:0] lhs = in[W_IN/2 +: W_IN/2];
            wire [W_IN/2-1:0] rhs = in[0 +: W_IN/2];
            wire left_empty = ~|lhs;
            CLZ #(.W_IN(W_IN/2)) inner (
                .in(left_empty ? rhs : lhs),
                .out(half_count)
            );
            assign out = {left_empty, half_count};
        end
    endgenerate
endmodule

/* Kept out of rv32_fpu so the rounding adders cannot be shared with the
 * cache and address datapath. Inlining this puts that cone back on the
 * CPU clock. */
(* noflatten *)
module fpu_finish (
    input             pack_sign,
    input signed [15:0] pack_exp,
    input      [31:0] pack_sig,
    input      [2:0]  rm,
    input      [63:0] f2i_sig,
    input      [15:0] f2i_inc,
    input             f2i_sign,
    input             f2i_uns,
    output     [36:0] pack_out,
    output     [36:0] f2i_out
);
    localparam [4:0] F_NX = 5'b00001;
    localparam [4:0] F_UF = 5'b00010;
    localparam [4:0] F_OF = 5'b00100;
    localparam [4:0] F_NV = 5'b10000;
    localparam [2:0] RM_RNE = 3'b000;
    localparam [2:0] RM_RDN = 3'b010;
    localparam [2:0] RM_RUP = 3'b011;
    localparam [2:0] RM_RMM = 3'b100;

    function automatic [31:0] shr_jam32(input [31:0] a, input [15:0] amt);
        begin
            if (amt == 0)
                shr_jam32 = a;
            else if (amt >= 16'd31)
                shr_jam32 = {31'b0, a != 0};
            else
                shr_jam32 = (a >> amt) | {31'b0, |(a & ~({32{1'b1}} << amt))};
        end
    endfunction

    function automatic [36:0] round_pack(input logic sign, input logic signed [15:0] exp_in,
                                         input logic [31:0] sig_in, input logic [2:0] rm_in);
        logic round_near_even;
        logic [7:0] round_inc;
        logic [6:0] round_bits;
        logic signed [15:0] exp;
        logic [31:0] sig;
        logic [32:0] sig_inc;
        logic is_tiny;
        logic [4:0] flags;
        logic [31:0] ui;
        logic [15:0] sh;
        begin
            round_near_even = (rm_in == RM_RNE);
            round_inc = 8'h40;
            if (!round_near_even && (rm_in != RM_RMM)) begin
                if (rm_in == (sign ? RM_RDN : RM_RUP))
                    round_inc = 8'h7f;
                else
                    round_inc = 8'h00;
            end
            exp = exp_in;
            sig = sig_in;
            flags = 5'b0;
            round_bits = sig[6:0];
            round_pack = 37'b0;
            if ((exp >= 16'sd253) &&
                ((exp > 16'sd253) ||
                 (({1'b0, sig} + {25'b0, round_inc}) >= 33'h80000000))) begin
                ui = {sign, 8'hff, 23'b0};
                if (round_inc == 0)
                    ui = ui - 32'd1;
                round_pack = {F_OF | F_NX, ui};
            end else begin
                if (exp < 0) begin
                    sig_inc = {1'b0, sig} + {25'b0, round_inc};
                    is_tiny = (exp < -16'sd1) || (sig_inc < 33'h80000000);
                    sh = -exp;
                    sig = shr_jam32(sig, sh);
                    exp = 0;
                    round_bits = sig[6:0];
                    if (is_tiny && (round_bits != 0))
                        flags = flags | F_UF;
                end
                sig = ({1'b0, sig} + {25'b0, round_inc}) >> 7;
                if (round_bits != 0)
                    flags = flags | F_NX;
                if (round_near_even && (round_bits == 7'h40))
                    sig[0] = 1'b0;
                if (sig == 0)
                    exp = 0;
                ui = {sign, exp[7:0], 23'b0} + sig;
                round_pack = {flags, ui};
            end
        end
    endfunction

    function automatic [36:0] f2i_round(input [63:0] sig64, input [15:0] round_inc,
                                        input sign, input unsign, input [2:0] rm_in);
        logic [11:0] round_bits;
        logic [63:0] sig2;
        logic [31:0] mag;
        logic [31:0] z;
        logic [4:0] flags;
        begin
            flags = 5'b0;
            z = 32'b0;
            round_bits = sig64[11:0];
            sig2 = sig64 + {48'b0, round_inc};
            if (|sig2[63:44]) begin
                flags = F_NV;
                if (unsign)
                    z = sign ? 32'h00000000 : 32'hffffffff;
                else
                    z = sign ? 32'h80000000 : 32'h7fffffff;
            end else begin
                mag = sig2[43:12];
                if ((round_bits == 12'h800) && (rm_in == RM_RNE))
                    mag[0] = 1'b0;
                if (unsign) begin
                    if (sign && (mag != 0)) begin
                        flags = F_NV;
                        z = 32'h00000000;
                    end else begin
                        z = mag;
                        if (round_bits != 0)
                            flags = flags | F_NX;
                    end
                end else begin
                    z = sign ? (~mag + 32'd1) : mag;
                    if ((z != 0) && (z[31] ^ sign)) begin
                        flags = F_NV;
                        z = sign ? 32'h80000000 : 32'h7fffffff;
                    end else if (round_bits != 0) begin
                        flags = flags | F_NX;
                    end
                end
            end
            f2i_round = {flags, z};
        end
    endfunction

    assign pack_out = round_pack(pack_sign, pack_exp, pack_sig, rm);
    assign f2i_out = f2i_round(f2i_sig, f2i_inc, f2i_sign, f2i_uns, rm);
endmodule

`endif
