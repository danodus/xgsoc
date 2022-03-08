module vga(
    input wire  logic        clk,
    input wire  logic        reset_i,

    output      logic        vram_sel_o,
    output      logic        vram_wr_o,
    output      logic [3:0]  vram_mask_o,
    output      logic [15:0] vram_addr_o,
    input       logic [15:0] vram_data_in_i,
    output      logic [15:0] vram_data_out_o,    

    output      logic        vga_hsync_o,
    output      logic        vga_vsync_o,
    output      logic [3:0]  vga_r_o,
    output      logic [3:0]  vga_g_o,
    output      logic [3:0]  vga_b_o
);

    // vga timings
    localparam CORDW = 16;
    logic signed [CORDW-1:0] sx, sy;
    logic hsync, vsync;
    logic de, line;
    logic frame;
    
    vga_timings #(.CORDW(CORDW)) vga_timings(
        .clk_pix(clk),
        .rst(reset_i),
        .sx(sx),
        .sy(sy),
        .hsync(hsync),
        .vsync(vsync),
        .de(de),
        .frame(frame),
        .line(line)
    );

    logic [3:0] font_x, font_y;
    logic [7:0] char_pattern;
    logic       char_bit;

    logic [15:0] font[256*4];

    logic [7:0] char;
    logic [15:0] char_addr;

    initial begin
        $readmemb("ANSI_PC_8x8w.mem", font);
    end

    assign char_addr = 4 * char + font_y / 2;
    assign char_pattern = font_y[0] ? font[char_addr][7:0] : font[char_addr][15:8];
    assign char_bit = char_pattern[7-font_x];

    always_ff @(posedge clk) begin
        vga_hsync_o <= hsync;
        vga_vsync_o <= vsync;
        if (de) begin
            vga_r_o <= char_bit ? 4'hF : 4'h0;
            vga_g_o <= char_bit ? 4'hF : 4'h0;
            vga_b_o <= char_bit ? 4'hF : 4'hD;
            font_x <= font_x + 1;

        end else begin
            vga_r_o <= 4'h0;
            vga_g_o <= 4'h0;
            vga_b_o <= 4'h0;
        end

        if (font_x == 7) begin
            font_x <= 0;
        end

        if (font_y == 8) begin
            font_y <= 0;
        end

        if (line && sy > 0) begin
            font_y <= font_y + 1;
        end

        if (frame) begin
            font_x <= 0;
            font_y <= 0;
            //char <= char + 1;
        end

        if (reset_i) begin
            font_x <= 0;
            font_y <= 0;
            char <= 8'h42;
        end
    end
endmodule
