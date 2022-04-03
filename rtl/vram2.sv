module vram2(
    input wire logic        clk,
    input wire logic        sel_i,
    input wire logic        wr_en_i,
    input wire logic [3:0]  wr_mask_i,
    input wire logic [15:0] address_in_i,
    input wire logic [15:0] data_in_i,
    output     logic [15:0] data_out_o
);

    logic [15:0] memory[65536];

    always_ff @(posedge clk) begin
        if (sel_i) begin
            if (wr_en_i) begin
                if (wr_mask_i[0]) memory[address_in_i][ 3: 0]   <= data_in_i[ 3: 0];
                if (wr_mask_i[1]) memory[address_in_i][ 7: 4]   <= data_in_i[ 7: 4];
                if (wr_mask_i[2]) memory[address_in_i][11: 8]   <= data_in_i[11: 8];
                if (wr_mask_i[3]) memory[address_in_i][15:12]   <= data_in_i[15:12];
            end
            data_out_o <= memory[address_in_i];
        end
    end

endmodule