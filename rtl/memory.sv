module memory(
    input  wire logic        clk,
    input  wire logic [31:0] addr_i,
    input  wire logic        we_i,
    input  wire logic [3:0]  wr_mask_i,
    input  wire logic [31:0] data_in_i,
    output      logic [31:0] data_out_o
    );

    logic [31:0] mem_array[1023:0];

    logic [9:0] addr;

    initial begin
        $readmemh("firmware.hex", mem_array);
    end

    assign addr = addr_i[9:0];

    always_ff @(posedge clk) begin
        if (we_i) begin
            if (wr_mask_i[0])
                mem_array[addr][7:0] <= data_in_i[7:0];
            if (wr_mask_i[1])
                mem_array[addr][15:8] <= data_in_i[15:8];
            if (wr_mask_i[2])
                mem_array[addr][23:16] <= data_in_i[23:16];
            if (wr_mask_i[3])
                mem_array[addr][31:24] <= data_in_i[31:24];
        end
        data_out_o = mem_array[addr];
    end

endmodule