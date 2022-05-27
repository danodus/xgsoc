// bram.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module bram #(
    parameter SIZE = 1024,
    parameter INIT_FILE = ""
    ) (
    input  wire logic        clk,
    input  wire logic        sel_i,
    input  wire logic        wr_en_i,
    input  wire logic [3:0]  wr_mask_i,
    input  wire logic [31:0] address_in_i,
    input  wire logic [31:0] data_in_i,
    output      logic [31:0] data_out_o,
    output      logic        ack_o
    );

    logic [31:0] mem_array[SIZE];

    logic [$clog2(SIZE)-1:0] addr;

    assign addr = address_in_i[$clog2(SIZE)-1:0];

    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem_array);
        end
    end

    always_ff @(posedge clk) begin
        ack_o <= 1'b0;
        if (sel_i) begin
            ack_o <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (sel_i) begin
            if (wr_en_i) begin
                if (wr_mask_i[0])
                    mem_array[addr][7:0] <= data_in_i[7:0];
                if (wr_mask_i[1])
                    mem_array[addr][15:8] <= data_in_i[15:8];
                if (wr_mask_i[2])
                    mem_array[addr][23:16] <= data_in_i[23:16];
                if (wr_mask_i[3])
                    mem_array[addr][31:24] <= data_in_i[31:24];
            end
            data_out_o <= mem_array[addr];
        end
    end

endmodule