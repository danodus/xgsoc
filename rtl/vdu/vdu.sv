// vdu.sv
// Copyright (c) 2023-2025 Daniel Cliche
// SPDX-License-Identifier: MIT

module vdu(
    input wire  logic        clk,
    input wire  logic        reset_i,
`ifdef HDMI
    input wire  logic        clk_pix,
    input wire  logic [11:0] cx,
    input wire  logic [11:0] cy,
`endif

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
`ifdef HDMI
    // Same porch order as vdu_display_timings, counted from the HDMI beam:
    // active pixels first, then blanking. `line` pulses at the first blanking
    // pixel of the line that is about to become active.
`ifdef VIDEO_480P
    localparam [11:0] FRAME_H = 12'd517;
`elsif VIDEO_720P
    localparam [11:0] FRAME_H = 12'd750;
`elsif VIDEO_1080P
    localparam [11:0] FRAME_H = 12'd1125;
`else
    localparam [11:0] FRAME_H = 12'd525;
`endif
    wire de = (cx < 12'd640) && (cy < 12'd480);
    wire [11:0] next_line = (cy == FRAME_H - 12'd1) ? 12'd0 : cy + 12'd1;
    wire line = (cx == 12'd640) && (next_line < 12'd480);
    wire frame = (cx == 12'd640) && (cy == 12'd479);
    wire sy0 = next_line[0];
    wire sx0 = cx[0];

    logic [1:0] disp_rst_sync;
    always_ff @(posedge clk_pix or posedge reset_i) begin
        if (reset_i)
            disp_rst_sync <= 2'b11;
        else
            disp_rst_sync <= {disp_rst_sync[0], 1'b0};
    end
    wire disp_reset = disp_rst_sync[1];
`else
    logic signed [CORDW-1:0] sx, sy;
    logic hsync, vsync, de, frame, line;
    wire sy0 = sy[0];
    wire sx0 = sx[0];
    wire disp_reset = reset_i;

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
`endif

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
`ifdef HDMI
    always_ff @(posedge clk_pix) begin
`else
    always_ff @(posedge clk) begin
`endif
        if (disp_reset) begin
            base_address <= 15'h0;
            line_address <= 15'h0;
            pixel_counter <= 2'd0;
            data <= 32'h0;
        end else begin
`ifdef HDMI
            vga_hsync_o <= (cx >= 12'd656) && (cx < 12'd752);
            vga_vsync_o <= (cy >= 12'd490) && (cy < 12'd492);
`else
            vga_hsync_o <= hsync;
            vga_vsync_o <= vsync;
`endif
            vga_de_o    <= de;
            if (frame) begin
                base_address <= 15'h0;
                line_address <= 15'h0;
            end
            if (line) begin
                if (sy0) begin
                    base_address <= base_address + 320/4;
                    line_address <= base_address;
                end else begin
                    base_address <= line_address;
                end
            end
            if (de) begin
                if (!sx0) begin
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
        .SIZE(75*1024/4)
    ) vram(
        .clk(clk),
`ifdef HDMI
        .clk_pix(clk_pix),
`endif
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