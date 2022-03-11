// bram.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module bram(
    input  wire logic        clk,
    input  wire logic        sel_i,
    input  wire logic        wr_en_i,
    input  wire logic [3:0]  wr_mask_i,
    input  wire logic [9:0]  address_in_i,
    input  wire logic [31:0] data_in_i,
    output      logic [31:0] data_out_o
    );

    logic [31:0] mem_array[1024];

    initial begin
        $readmemh("firmware.hex", mem_array);
    end

    always_ff @(posedge clk) begin
        if (sel_i) begin
            if (wr_en_i) begin
                if (wr_mask_i[0])
                    mem_array[address_in_i][7:0] <= data_in_i[7:0];
                if (wr_mask_i[1])
                    mem_array[address_in_i][15:8] <= data_in_i[15:8];
                if (wr_mask_i[2])
                    mem_array[address_in_i][23:16] <= data_in_i[23:16];
                if (wr_mask_i[3])
                    mem_array[address_in_i][31:24] <= data_in_i[31:24];
            end
            data_out_o = mem_array[address_in_i];
        end
    end

endmodule