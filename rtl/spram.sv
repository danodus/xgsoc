// spram.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module spram(
    input wire logic        clk,
    input wire logic        sel_i,
    input wire logic        wr_en_i,
    input wire logic [3:0]  wr_mask_i,
    input wire logic [14:0] address_in_i,
    input wire logic [31:0] data_in_i,
    output     logic [31:0] data_out_o
);

`ifndef SYNTHESIS
    logic [31:0] memory[32768];

    initial begin
        $readmemh("program.hex", memory);
    end

    always_ff @(posedge clk) begin
        if (sel_i) begin
            if (wr_en_i) begin
                if (wr_mask_i[0]) memory[address_in_i][7:0]    <= data_in_i[7:0];
                if (wr_mask_i[1]) memory[address_in_i][15:8]   <= data_in_i[15:8];
                if (wr_mask_i[2]) memory[address_in_i][23:16]  <= data_in_i[23:16];
                if (wr_mask_i[3]) memory[address_in_i][31:24]  <= data_in_i[31:24];
            end
            data_out_o <= memory[address_in_i];
        end
    end

`else

    logic [15:0] data0, data1, data2, data3;

    always_comb begin
        case (address_in_i[14])
            1'b0: data_out_o = {data1, data0};
            1'b1: data_out_o = {data3, data2};
        endcase
    end

    SB_SPRAM256KA mem0(
        .ADDRESS(address_in_i[13:0]),
        .DATAIN(data_in_i[15:0]),
        .MASKWREN({wr_mask_i[1], wr_mask_i[1], wr_mask_i[0], wr_mask_i[0]}),
        .WREN(wr_en_i),
        .CHIPSELECT(address_in_i[14] == 1'b0),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data0)
    );

    SB_SPRAM256KA mem1(
        .ADDRESS(address_in_i[13:0]),
        .DATAIN(data_in_i[31:16]),
        .MASKWREN({wr_mask_i[3], wr_mask_i[3], wr_mask_i[2], wr_mask_i[2]}),
        .WREN(wr_en_i),
        .CHIPSELECT(address_in_i[14] == 1'b0),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data1)
    );

    SB_SPRAM256KA mem2(
        .ADDRESS(address_in_i[13:0]),
        .DATAIN(data_in_i[15:0]),
        .MASKWREN({wr_mask_i[1], wr_mask_i[1], wr_mask_i[0], wr_mask_i[0]}),
        .WREN(wr_en_i),
        .CHIPSELECT(address_in_i[14] == 1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data2)
    );

    SB_SPRAM256KA mem3(
        .ADDRESS(address_in_i[13:0]),
        .DATAIN(data_in_i[31:16]),
        .MASKWREN({wr_mask_i[3], wr_mask_i[3], wr_mask_i[2], wr_mask_i[2]}),
        .WREN(wr_en_i),
        .CHIPSELECT(address_in_i[14] == 1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data3)
    );

`endif

endmodule
