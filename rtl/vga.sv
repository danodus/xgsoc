//`define GRAPHITE

module vga(
    input wire  logic        clk,
    input wire  logic        reset_i,

    // AXI stream command interface (slave)
    input  wire logic                        cmd_axis_tvalid_i,
    output      logic                        cmd_axis_tready_o,
    input  wire logic [31:0]                 cmd_axis_tdata_i,

    output      logic        vga_hsync_o,
    output      logic        vga_vsync_o,
    output      logic [3:0]  vga_r_o,
    output      logic [3:0]  vga_g_o,
    output      logic [3:0]  vga_b_o
);

    // display timings
    localparam CORDW = 16;
    logic signed [CORDW-1:0] sx, sy;
    logic hsync, vsync, de, frame, line;

    logic [3:0] text_r, text_g, text_b;
    
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


    // VGA output
    // 128x128: 14 bits to address 16-bit values
    logic [13:0] vga_read_addr;
    logic [11:0] line_counter, col_counter;
    always_ff @(posedge clk) begin
        vga_hsync_o <= hsync;
        vga_vsync_o <= vsync;

        if (frame) begin
            col_counter <= 12'd0;
            line_counter <= 12'd0;
            vga_read_addr <= 14'd0;
        end else begin
            if (line) begin
                col_counter  <= 12'd0;
                line_counter <= line_counter + 1;
            end
        end
        

        if (de) begin
            col_counter <= col_counter + 1;
            if (line_counter < 12'd128 && col_counter < 12'd128) begin
                vga_read_addr <= vga_read_addr + 1;
                vga_r_o <= text_r | vram_data_out[11:8];
                vga_g_o <= text_g | vram_data_out[7:4];
                vga_b_o <= text_b | vram_data_out[3:0];
            end else begin
                vga_r_o <= text_r | 4'h1;
                vga_g_o <= text_g | 4'h1;
                vga_b_o <= text_b | 4'h1;
            end
        end else begin
            vga_r_o <= 4'h0;
            vga_g_o <= 4'h0;
            vga_b_o <= 4'h0;
        end

        if (reset_i) begin
            vga_read_addr <= 14'd0;
            line_counter  <= 12'd0;
            col_counter   <= 12'd0;
        end
    end

    // video ram

    logic        vram_wr;
    logic [3:0]  vram_mask;
    logic [15:0] vram_address;
    logic [15:0] vram_data_in;
    logic [15:0] vram_data_out;

    logic        graphite_vram_sel;
    logic        graphite_vram_wr;
    logic [3:0]  graphite_vram_mask;
    logic [15:0] graphite_vram_address;
    logic [15:0] graphite_vram_data_out;    

    assign vram_wr = graphite_vram_sel ? graphite_vram_wr : 1'b0;
    assign vram_mask = graphite_vram_sel ? graphite_vram_mask : 4'hF;
    assign vram_address = graphite_vram_sel ? graphite_vram_address : {2'd0, vga_read_addr};
    assign vram_data_in = graphite_vram_sel ? graphite_vram_data_out : 16'd0;

    vram vram(
        .clk(clk),
        .sel_i(1'b1),
        .wr_en_i(vram_wr),
        .wr_mask_i(vram_mask),
        .address_in_i(vram_address),
        .data_in_i(vram_data_in),
        .data_out_o(vram_data_out)
    );

    graphite graphite(
        .clk(clk),
        .reset_i(reset_i),
        .cmd_axis_tvalid_i(cmd_axis_tvalid_i),
        .cmd_axis_tready_o(cmd_axis_tready_o),
        .cmd_axis_tdata_i(cmd_axis_tdata_i),
        .vram_sel_o(graphite_vram_sel),
        .vram_wr_o(graphite_vram_wr),
        .vram_mask_o(graphite_vram_mask),
        .vram_addr_o(graphite_vram_address),
        .vram_data_in_i(vram_data_out),
        .vram_data_out_o(graphite_vram_data_out),
        .swap_o()
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
        if (de) begin
            text_r <= char_bit ? 4'hF : 4'h0;
            text_g <= char_bit ? 4'hF : 4'h0;
            text_b <= char_bit ? 4'hF : 4'hD;
            font_x <= font_x + 1;

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
