// Direct rv32_fpu checker. Berkeley SoftFloat (RISC-V NaN specialization) is
// the oracle for arithmetic, comparisons, and integer conversions.

#include "Vrv32_fpu.h"
#include "verilated.h"

extern "C" {
#include "softfloat.h"
#include "internals.h"
}

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

static Vrv32_fpu *top;
static int fails = 0;
static int checks = 0;

static void tick() {
    top->clk = 0;
    top->eval();
    top->clk = 1;
    top->eval();
}

static void reset() {
    top->reset = 1;
    top->ce = 1;
    top->wr = 0;
    top->frm = 0;
    top->instr = 0;
    top->rs1 = 0;
    top->rs2 = 0;
    top->rs3 = 0;
    for (int i = 0; i < 4; i++)
        tick();
    top->reset = 0;
    tick();
}

static uint32_t enc_opfp(uint32_t funct7, uint32_t rm) {
    uint32_t ins = (funct7 << 25) | (rm << 12) | 0x53;
    return ins >> 2;
}

static uint32_t enc_opfp_rs2(uint32_t funct7, uint32_t rs2, uint32_t rm) {
    uint32_t ins = (funct7 << 25) | (rs2 << 20) | (rm << 12) | 0x53;
    return ins >> 2;
}

static uint32_t enc_fused(uint32_t opcode, uint32_t rm) {
    uint32_t ins = (rm << 12) | opcode;
    return ins >> 2;
}

/* Put rm into instr[14:12]. instr is stored without the low two opcode bits. */
static uint32_t with_rm(uint32_t instr, uint32_t rm) {
    uint32_t full = (instr << 2) | 3u;
    full = (full & ~(7u << 12)) | ((rm & 7u) << 12);
    return full >> 2;
}

static void run(uint32_t instr, uint32_t a, uint32_t b, uint32_t c, uint32_t rm,
                uint32_t *out, uint32_t *flags) {
    top->frm = rm & 7;
    top->instr = instr;
    top->rs1 = a;
    top->rs2 = b;
    top->rs3 = c;
    top->wr = 1;
    tick();
    top->wr = 0;
    int guard = 0;
    while (top->busy) {
        tick();
        if (++guard > 200) {
            std::printf("timeout instr=%08x a=%08x b=%08x c=%08x\n",
                        (instr << 2) | 3, a, b, c);
            *out = 0xdeadbeef;
            *flags = 0x1f;
            return;
        }
    }
    *out = top->out;
    *flags = top->fflags & 0x1f;
}

static void expect(const char *op, uint32_t rm, uint32_t a, uint32_t b, uint32_t c,
                   uint32_t got, uint32_t gfl, uint32_t want, uint32_t wfl) {
    checks++;
    if (got != want || gfl != wfl) {
        if (fails < 40) {
            std::printf("FAIL %s rm=%u a=%08x b=%08x c=%08x got %08x/%02x want %08x/%02x\n",
                        op, rm, a, b, c, got, gfl, want, wfl);
        }
        fails++;
    }
}

static float32_t f32(uint32_t u) {
    float32_t x;
    x.v = u;
    return x;
}

static uint32_t u32(float32_t x) { return x.v; }

static void check_bin(const char *name, uint32_t instr, uint32_t a, uint32_t b, int rm,
                      float32_t (*fn)(float32_t, float32_t)) {
    softfloat_exceptionFlags = 0;
    softfloat_roundingMode = rm;
    float32_t z = fn(f32(a), f32(b));
    uint32_t got, fl;
    run(with_rm(instr, rm), a, b, 0, rm, &got, &fl);
    expect(name, rm, a, b, 0, got, fl, u32(z), softfloat_exceptionFlags & 0x1f);
}

static void check_un(const char *name, uint32_t instr, uint32_t a, int rm,
                     float32_t (*fn)(float32_t)) {
    softfloat_exceptionFlags = 0;
    softfloat_roundingMode = rm;
    float32_t z = fn(f32(a));
    uint32_t got, fl;
    run(with_rm(instr, rm), a, 0, 0, rm, &got, &fl);
    expect(name, rm, a, 0, 0, got, fl, u32(z), softfloat_exceptionFlags & 0x1f);
}

static void check_fma(const char *name, uint32_t instr, uint32_t a, uint32_t b, uint32_t c,
                      int rm, uint32_t a2, uint32_t b2, uint32_t c2) {
    softfloat_exceptionFlags = 0;
    softfloat_roundingMode = rm;
    float32_t z = softfloat_mulAddF32(a2, b2, c2, 0);
    uint32_t got, fl;
    run(with_rm(instr, rm), a, b, c, rm, &got, &fl);
    expect(name, rm, a, b, c, got, fl, u32(z), softfloat_exceptionFlags & 0x1f);
}

static void check_cmp(const char *name, uint32_t instr, uint32_t a, uint32_t b,
                      bool (*fn)(float32_t, float32_t)) {
    softfloat_exceptionFlags = 0;
    bool z = fn(f32(a), f32(b));
    uint32_t got, fl;
    run(instr, a, b, 0, 0, &got, &fl);
    expect(name, 0, a, b, 0, got, fl, z ? 1u : 0u, softfloat_exceptionFlags & 0x1f);
}

static void check_f2i(const char *name, uint32_t instr, uint32_t a, int rm, bool unsign) {
    softfloat_exceptionFlags = 0;
    softfloat_roundingMode = rm;
    uint32_t want;
    if (unsign)
        want = f32_to_ui32(f32(a), rm, true);
    else
        want = (uint32_t)f32_to_i32(f32(a), rm, true);
    uint32_t got, fl;
    run(with_rm(instr, rm), a, 0, 0, rm, &got, &fl);
    expect(name, rm, a, 0, 0, got, fl, want, softfloat_exceptionFlags & 0x1f);
}

static void check_i2f(const char *name, uint32_t instr, uint32_t a, int rm, bool unsign) {
    softfloat_exceptionFlags = 0;
    softfloat_roundingMode = rm;
    float32_t z = unsign ? ui32_to_f32(a) : i32_to_f32((int32_t)a);
    uint32_t got, fl;
    run(with_rm(instr, rm), a, 0, 0, rm, &got, &fl);
    expect(name, rm, a, 0, 0, got, fl, u32(z), softfloat_exceptionFlags & 0x1f);
}

static uint32_t fclass_ref(uint32_t v) {
    bool sign = v >> 31;
    unsigned exp = (v >> 23) & 255;
    unsigned frac = v & 0x7fffff;
    unsigned bit = 0;
    if (exp == 255 && frac == 0) bit = sign ? 0 : 7;
    else if (exp == 255 && (frac & 0x400000)) bit = 9;
    else if (exp == 255) bit = 8;
    else if (exp == 0 && frac == 0) bit = sign ? 3 : 4;
    else if (exp == 0) bit = sign ? 2 : 5;
    else bit = sign ? 1 : 6;
    return 1u << bit;
}

static bool both_nan(uint32_t a, uint32_t b) {
    auto nan = [](uint32_t v) { return ((v >> 23) & 255) == 255 && (v & 0x7fffff); };
    return nan(a) && nan(b);
}
static bool one_nan(uint32_t v) {
    return ((v >> 23) & 255) == 255 && (v & 0x7fffff);
}
static bool snan(uint32_t v) {
    return ((v >> 23) & 255) == 255 && !(v & 0x400000) && (v & 0x3fffff);
}
static bool is_zero(uint32_t v) { return (v & 0x7fffffff) == 0; }

static uint32_t minmax_ref(uint32_t a, uint32_t b, bool is_min, uint32_t *fl) {
    *fl = (snan(a) || snan(b)) ? 0x10 : 0;
    if (one_nan(a) && one_nan(b)) return 0x7fc00000;
    if (one_nan(a)) return b;
    if (one_nan(b)) return a;
    if (is_zero(a) && is_zero(b)) return is_min ? ((a | b) & 0x80000000) : 0;
    softfloat_exceptionFlags = 0;
    bool lt = f32_lt(f32(a), f32(b));
    if (is_min) return lt ? a : b;
    bool gt = f32_lt(f32(b), f32(a));
    return gt ? a : b;
}

static uint32_t rnd_fp(unsigned &s) {
    s = s * 1664525u + 1013904223u;
    unsigned kind = s % 16;
    unsigned frac = s & 0x7fffff;
    unsigned sign = (s >> 23) & 1;
    unsigned exp;
    if (kind == 0) return sign << 31;
    if (kind == 1) return (sign << 31) | frac;                 /* subnormal / zero */
    if (kind == 2) return (sign << 31) | (255u << 23);         /* inf */
    if (kind == 3) return (sign << 31) | (255u << 23) | (frac | 1);          /* q/s nan */
    if (kind == 4) return (sign << 31) | (255u << 23) | ((frac & 0x3fffff) | 1); /* snan if bit22 clear */
    exp = 1 + (s % 254);
    return (sign << 31) | (exp << 23) | frac;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    top = new Vrv32_fpu;
    reset();
    softfloat_detectTininess = softfloat_tininess_afterRounding;

    const uint32_t FADD = enc_opfp(0x00, 0);
    const uint32_t FSUB = enc_opfp(0x04, 0);
    const uint32_t FMUL = enc_opfp(0x08, 0);
    const uint32_t FDIV = enc_opfp(0x0c, 0);
    const uint32_t FSQRT = enc_opfp(0x2c, 0);
    const uint32_t FMADD = enc_fused(0x43, 0);
    const uint32_t FMSUB = enc_fused(0x47, 0);
    const uint32_t FNMSUB = enc_fused(0x4b, 0);
    const uint32_t FNMADD = enc_fused(0x4f, 0);
    const uint32_t FEQ = enc_opfp(0x50, 2);
    const uint32_t FLT = enc_opfp(0x50, 1);
    const uint32_t FLE = enc_opfp(0x50, 0);
    const uint32_t FMIN = enc_opfp(0x14, 0);
    const uint32_t FMAX = enc_opfp(0x14, 1);
    const uint32_t FSGNJ = enc_opfp(0x10, 0);
    const uint32_t FSGNJN = enc_opfp(0x10, 1);
    const uint32_t FSGNJX = enc_opfp(0x10, 2);
    const uint32_t FCLASS = enc_opfp(0x70, 1);
    const uint32_t FMVXW = enc_opfp(0x70, 0);
    const uint32_t FMVWX = enc_opfp(0x78, 0);
    const uint32_t FCVTWS = enc_opfp_rs2(0x60, 0, 0);
    const uint32_t FCVTWUS = enc_opfp_rs2(0x60, 1, 0);
    const uint32_t FCVTSW = enc_opfp_rs2(0x68, 0, 0);
    const uint32_t FCVTSWU = enc_opfp_rs2(0x68, 1, 0);

    std::vector<uint32_t> directed = {
        0x00000000, 0x80000000, 0x3f800000, 0xbf800000, 0x40000000, 0xc0000000,
        0x3f000000, 0x7f800000, 0xff800000, 0x7fc00000, 0x7f800001, 0xffc00001,
        0x7f800000, 0x00800000, 0x00000001, 0x80000001, 0x7f7fffff, 0x00800001,
        0x3fc00000, 0x3f8ccccd, 0x42c80000, 0x33800000, 0x3eaaaaab, 0x5f3759df,
        0x322bcc77, 0x1, 0x7fffff, 0xcf000000, 0x4f000000, 0x3f802000
    };

    auto forall_rm = [&](auto &&body) {
        for (int rm = 0; rm < 5; rm++)
            body(rm);
    };

    for (uint32_t a : directed) {
        for (uint32_t b : directed) {
            forall_rm([&](int rm) {
                check_bin("add", FADD, a, b, rm, f32_add);
                check_bin("sub", FSUB, a, b, rm, f32_sub);
                check_bin("mul", FMUL, a, b, rm, f32_mul);
                check_bin("div", FDIV, a, b, rm, f32_div);
            });
            check_cmp("eq", FEQ, a, b, f32_eq);
            check_cmp("lt", FLT, a, b, f32_lt);
            check_cmp("le", FLE, a, b, f32_le);
            uint32_t fl, want, got, gfl;
            want = minmax_ref(a, b, true, &fl);
            run(FMIN, a, b, 0, 0, &got, &gfl);
            expect("min", 0, a, b, 0, got, gfl, want, fl);
            want = minmax_ref(a, b, false, &fl);
            run(FMAX, a, b, 0, 0, &got, &gfl);
            expect("max", 0, a, b, 0, got, gfl, want, fl);
            run(FSGNJ, a, b, 0, 0, &got, &gfl);
            expect("sgnj", 0, a, b, 0, got, gfl, (b & 0x80000000) | (a & 0x7fffffff), 0);
            run(FSGNJN, a, b, 0, 0, &got, &gfl);
            expect("sgnjn", 0, a, b, 0, got, gfl, ((~b) & 0x80000000) | (a & 0x7fffffff), 0);
            run(FSGNJX, a, b, 0, 0, &got, &gfl);
            expect("sgnjx", 0, a, b, 0, got, gfl, ((a ^ b) & 0x80000000) | (a & 0x7fffffff), 0);
        }
        forall_rm([&](int rm) {
            check_un("sqrt", FSQRT, a, rm, f32_sqrt);
            check_f2i("cvt.w", FCVTWS, a, rm, false);
            check_f2i("cvt.wu", FCVTWUS, a, rm, true);
        });
        uint32_t got, gfl;
        run(FCLASS, a, 0, 0, 0, &got, &gfl);
        expect("class", 0, a, 0, 0, got, gfl, fclass_ref(a), 0);
        run(FMVXW, a, 0, 0, 0, &got, &gfl);
        expect("fmv.x", 0, a, 0, 0, got, gfl, a, 0);
        run(FMVWX, a, 0, 0, 0, &got, &gfl);
        expect("fmv.w", 0, a, 0, 0, got, gfl, a, 0);
    }

    std::vector<uint32_t> ints = {
        0, 1, 0xffffffff, 0x80000000, 0x7fffffff, 2, 3, 0x00ffffff, 0x01000000,
        0x01000001, 0xfffffffe, 100, 0x12345678, 0x80000001
    };
    for (uint32_t a : ints) {
        forall_rm([&](int rm) {
            check_i2f("cvt.s.w", FCVTSW, a, rm, false);
            check_i2f("cvt.s.wu", FCVTSWU, a, rm, true);
        });
    }

    for (uint32_t a : directed) {
        for (uint32_t b : directed) {
            for (uint32_t c : directed) {
                forall_rm([&](int rm) {
                    check_fma("madd", FMADD, a, b, c, rm, a, b, c);
                    check_fma("msub", FMSUB, a, b, c, rm, a, b, c ^ 0x80000000);
                    check_fma("nmsub", FNMSUB, a, b, c, rm, a ^ 0x80000000, b, c);
                    check_fma("nmadd", FNMADD, a, b, c, rm, a ^ 0x80000000, b, c ^ 0x80000000);
                });
            }
        }
    }

    unsigned rng = 1;
    for (int n = 0; n < 400; n++) {
        uint32_t a = rnd_fp(rng);
        uint32_t b = rnd_fp(rng);
        uint32_t c = rnd_fp(rng);
        for (int rm = 0; rm < 5; rm++) {
            check_bin("add", FADD, a, b, rm, f32_add);
            check_bin("sub", FSUB, a, b, rm, f32_sub);
            check_bin("mul", FMUL, a, b, rm, f32_mul);
            check_bin("div", FDIV, a, b, rm, f32_div);
            check_un("sqrt", FSQRT, a, rm, f32_sqrt);
            check_fma("madd", FMADD, a, b, c, rm, a, b, c);
            check_fma("msub", FMSUB, a, b, c, rm, a, b, c ^ 0x80000000);
            check_f2i("cvt.w", FCVTWS, a, rm, false);
            check_f2i("cvt.wu", FCVTWUS, a, rm, true);
            check_i2f("cvt.s.w", FCVTSW, a, rm, false);
            check_i2f("cvt.s.wu", FCVTSWU, a, rm, true);
        }
    }

    /* Dynamic rm (instr rm == 111) follows frm. check_* would overwrite that field. */
    for (int rm = 0; rm < 5; rm++) {
        uint32_t a = 0x3f800000, b = 0x3fc00000, c = 0x3eaaaaab;
        uint32_t got, fl;
        softfloat_exceptionFlags = 0;
        softfloat_roundingMode = rm;
        float32_t z = f32_add(f32(a), f32(b));
        run(with_rm(FADD, 7), a, b, 0, rm, &got, &fl);
        expect("add.dyn", rm, a, b, 0, got, fl, u32(z), softfloat_exceptionFlags & 0x1f);
        softfloat_exceptionFlags = 0;
        z = f32_div(f32(a), f32(b));
        run(with_rm(FDIV, 7), a, b, 0, rm, &got, &fl);
        expect("div.dyn", rm, a, b, 0, got, fl, u32(z), softfloat_exceptionFlags & 0x1f);
        softfloat_exceptionFlags = 0;
        z = f32_sqrt(f32(a));
        run(with_rm(FSQRT, 7), a, 0, 0, rm, &got, &fl);
        expect("sqrt.dyn", rm, a, 0, 0, got, fl, u32(z), softfloat_exceptionFlags & 0x1f);
        softfloat_exceptionFlags = 0;
        z = softfloat_mulAddF32(a, b, c, 0);
        run(with_rm(FMADD, 7), a, b, c, rm, &got, &fl);
        expect("madd.dyn", rm, a, b, c, got, fl, u32(z), softfloat_exceptionFlags & 0x1f);
    }

    std::printf("%d checks, %d fails\n", checks, fails);
    delete top;
    return fails ? 1 : 0;
}
