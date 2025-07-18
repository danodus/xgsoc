// vdu.sv
// Copyright (c) 2023-2025 Daniel Cliche
// SPDX-License-Identifier: MIT

module vdu(
    input wire  logic        clk,
    input wire  logic        reset_i,

    input  wire logic        sel_i,
    input  wire logic        wr_en_i,
    input  wire logic [3:0]  wr_mask_i,
    input  wire logic [15:0] address_in_i,
    input  wire logic [31:0] data_in_i,
    output      logic [31:0] data_out_o,
    output      logic        ack_o,

    output      logic        vga_hsync_o,
    output      logic        vga_vsync_o,
    output      logic [7:0]  vga_r_o,
    output      logic [7:0]  vga_g_o,
    output      logic [7:0]  vga_b_o,
    output      logic        vga_de_o
);

    // display timings
    localparam CORDW = 16;
    logic signed [CORDW-1:0] sx, sy;
    logic hsync, vsync, de, frame, line;
    
    vdu_display_timings display_timings(
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

    // palette
    logic [23:0] palette[256];

    initial begin
        $readmemh("vdu_palette.hex", palette);
    end

    logic [14:0] base_address, line_address;
    logic [31:0] data_out;
    logic [1:0] pixel_counter;
    logic [31:0] data;
    logic vram_ack, regs_ack;

    always_comb begin
        ack_o = vram_ack | regs_ack;
    end

    // registers
    always_ff @(posedge clk) begin
        if (reset_i) begin
            regs_ack <= 1'b0;
        end else begin
            regs_ack <= 1'b0;
            if (sel_i && address_in_i[15]) begin
                if (wr_en_i) begin
                    // write
                    palette[address_in_i[7:0]] <= data_in_i;
                end else begin
                    // read
                    data_out_o <= palette[address_in_i[7:0]];
                end
                regs_ack <= 1'b1;
            end
        end
    end

    always_comb begin
        if (vga_de_o) begin
            vga_r_o = palette[data[7:0]][23:16];
            vga_g_o = palette[data[7:0]][15:8];
            vga_b_o = palette[data[7:0]][7:0];
        end else begin
            vga_r_o = 4'h0;
            vga_g_o = 4'h0;
            vga_b_o = 4'h0;
        end
    end

    // video display
    always_ff @(posedge clk) begin
        if (reset_i) begin
            base_address <= 15'h0;
            line_address <= 15'h0;
            pixel_counter <= 2'd0;
            data <= 32'h0;
        end else begin
            vga_hsync_o <= hsync;
            vga_vsync_o <= vsync;
            vga_de_o    <= de;
            if (frame) begin
                base_address <= 15'h0;
                line_address <= 15'h0;
            end
            if (line) begin
                if (sy[0]) begin
                    base_address <= base_address + 320/4;
                    line_address <= base_address;
                end else begin
                    base_address <= line_address;
                end
            end
            if (de) begin
                if (!sx[0]) begin
                    pixel_counter <= pixel_counter + 1;
                    if (pixel_counter == 2'd0) begin
                        data <= data_out;
                        line_address <= line_address + 1;
                    end else begin
                        data <= data >> 8;
                    end
                end
            end else begin
                data <= data_out;   // preload
            end
        end
    end

    vdu_vram #(
        .SIZE(128*1024/4)
    ) vram(
        .clk(clk),
        .sel_i(sel_i & ~address_in_i[15]),
        .wr_en_i(wr_en_i),
        .wr_mask_i(wr_mask_i),
        .address_in_i(address_in_i[14:0]),
        .data_in_i(data_in_i),
        .data_out_o(data_out_o),
        .sec_address_in_i(line_address),
        .sec_data_out_o(data_out),
        .ack_o(vram_ack)
    );

endmodule