module vram(
    input wire logic        clk,
    input wire logic        sel_i,
    input wire logic        wr_en_i,
    input wire logic [3:0]  wr_mask_i,
    input wire logic [15:0] address_in_i,
    input wire logic [15:0] data_in_i,
    output     logic [15:0] data_out_o
);

`ifndef SYNTHESIS
    logic [15:0] memory[49152];

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

`else

    logic        select0, select1, select2;
    logic [15:0] data0, data1, data2;

    assign select0 = (address_in_i[15:14] == 2'b00);
    assign select1 = (address_in_i[15:14] == 2'b01);
    assign select2 = (address_in_i[15:14] == 2'b10);

    always_comb begin
        case (address_in_i[15:14])
            2'b00: data_out_o = data0;
            2'b01: data_out_o = data1;
            2'b10: data_out_o = data2;
            default: data_out_o = 16'd0;
        endcase
    end

    SB_SPRAM256KA mem0(
        .ADDRESS(address_in_i[13:0]),
        .DATAIN(data_in_i),
        .MASKWREN(wr_mask_i),
        .WREN(wr_en_i),
        .CHIPSELECT(select0),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data0)
    );

    SB_SPRAM256KA mem1(
        .ADDRESS(address_in_i[13:0]),
        .DATAIN(data_in_i),
        .MASKWREN(wr_mask_i),
        .WREN(wr_en_i),
        .CHIPSELECT(select1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data1)
    );

    SB_SPRAM256KA mem2(
        .ADDRESS(address_in_i[13:0]),
        .DATAIN(data_in_i),
        .MASKWREN(wr_mask_i),
        .WREN(wr_en_i),
        .CHIPSELECT(select2),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data2)
    );

`endif

endmodule