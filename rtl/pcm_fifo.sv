// pcm_fifo.sv
// Copyright (c) 2026 Daniel Cliche
// SPDX-License-Identifier: MIT

// Async FIFO, DEPTH x 32. Gray-coded pointers.
// The read port is registered so Yosys maps the array onto ECP5 block RAM.
// rd_data is the oldest word. It updates one read clock after the read
// address changes, which is well before the next 48 kHz sample strobe.

module pcm_fifo #(
    parameter DEPTH = 1024
) (
    input  wire logic        clk_wr,
    input  wire logic        clk_rd,
    input  wire logic        rst_n,
    input  wire logic        wr_en,
    input  wire logic [31:0] wr_data,
    output wire logic        full,
    input  wire logic        rd_en,
    output wire logic [31:0] rd_data,
    output wire logic        empty
);
    localparam AW = $clog2(DEPTH);
    localparam PW = AW + 1;

    (* ram_style = "block" *) logic [31:0] mem [0:DEPTH-1];

    logic [PW-1:0] wr_bin;
    logic [PW-1:0] rd_bin;
    logic [PW-1:0] wr_gray;
    logic [PW-1:0] rd_gray;
    logic [PW-1:0] rd_gray_wr1, rd_gray_wr2;
    logic [PW-1:0] wr_gray_rd1, wr_gray_rd2;

    function automatic [PW-1:0] bin2gray(input logic [PW-1:0] b);
        bin2gray = (b >> 1) ^ b;
    endfunction

    wire [PW-1:0] wr_bin_p1 = wr_bin + 1'b1;
    wire [PW-1:0] wr_gray_p1 = bin2gray(wr_bin_p1);
    assign full = (wr_gray_p1 == {~rd_gray_wr2[PW-1:PW-2], rd_gray_wr2[PW-3:0]});

    assign empty = (rd_gray == wr_gray_rd2);

    always_ff @(posedge clk_wr) begin
        if (wr_en && !full)
            mem[wr_bin[AW-1:0]] <= wr_data;
    end

    logic [31:0] rd_data_r;
    always_ff @(posedge clk_rd) begin
        rd_data_r <= mem[rd_bin[AW-1:0]];
    end
    assign rd_data = rd_data_r;

    always_ff @(posedge clk_wr) begin
        if (!rst_n) begin
            wr_bin <= '0;
            wr_gray <= '0;
            rd_gray_wr1 <= '0;
            rd_gray_wr2 <= '0;
        end else begin
            rd_gray_wr1 <= rd_gray;
            rd_gray_wr2 <= rd_gray_wr1;
            if (wr_en && !full) begin
                wr_bin <= wr_bin_p1;
                wr_gray <= wr_gray_p1;
            end
        end
    end

    logic [1:0] rd_rst_sync;
    always_ff @(posedge clk_rd or negedge rst_n) begin
        if (!rst_n)
            rd_rst_sync <= 2'b00;
        else
            rd_rst_sync <= {rd_rst_sync[0], 1'b1};
    end
    wire rd_rst_n = rd_rst_sync[1];

    wire [PW-1:0] rd_bin_p1 = rd_bin + 1'b1;

    always_ff @(posedge clk_rd) begin
        if (!rd_rst_n) begin
            rd_bin <= '0;
            rd_gray <= '0;
            wr_gray_rd1 <= '0;
            wr_gray_rd2 <= '0;
        end else begin
            wr_gray_rd1 <= wr_gray;
            wr_gray_rd2 <= wr_gray_rd1;
            if (rd_en && !empty) begin
                rd_bin <= rd_bin_p1;
                rd_gray <= bin2gray(rd_bin_p1);
            end
        end
    end

endmodule
