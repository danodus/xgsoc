// graphite.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

/*
    0x00000000 - 0x00000FFF: block ram (4kB)
    0x10000000 - 0x1001FFFF: single port ram (128kB)
    0x20001000 - 0x00001FFF: display
    0x20002000 - 0x00002FFF: UART (BAUDS-N-8-1)
        0x20002000: Data Register (8 bits)
        0x20002004: Status Register (Read-only)
            bit 0: busy
            bit 1: valid
*/

module soc #(
    parameter FREQ_HZ = 12 * 1000000,
    parameter BAUDS    = 115200
    ) (
    input  wire logic       clk,
    input  wire logic       clk_pix,
    input  wire logic       reset_i,
    output      logic [7:0] display_o,

    input  wire logic       rx_i,
    output      logic       tx_o,

    output      logic       vga_hsync_o,
    output      logic       vga_vsync_o,
    output      logic [3:0] vga_r_o,
    output      logic [3:0] vga_g_o,
    output      logic [3:0] vga_b_o
    );

    // bus
    logic [31:0] addr;
    logic        mem_we, cpu_we;
    logic [31:0] mem_data_in, cpu_data_in;
    logic [31:0] bram_data_out, spram_data_out, mem_data_out, cpu_data_out;
    logic [3:0]  wr_mask;

    // display
    logic [7:0] display;
    logic display_we;

    // UART
    logic uart_tx_strobe;
    logic uart_rx_strobe;

    logic [7:0] uart_tx_data = 0;
    logic [7:0] uart_rx_data;
    logic uart_busy, uart_valid;
    logic uart_wr = 0;
    logic uart_rd = 0;

    bram bram(
        .clk(clk),
        .sel_i(addr[31:28] == 4'h0),
        .wr_en_i(mem_we),
        .wr_mask_i(wr_mask),
        .address_in_i(10'(addr[27:0] >> 2)),
        .data_in_i(mem_data_in), 
        .data_out_o(bram_data_out)
    );

    spram spram(
        .clk(clk),
        .sel_i(addr[31:28] == 4'h1),
        .wr_en_i(mem_we),
        .wr_mask_i(wr_mask),
        .address_in_i(15'(addr[27:0] >> 2)),
        .data_in_i(mem_data_in), 
        .data_out_o(spram_data_out)
    );

    processor cpu(
        .clk(clk),
        .reset_i(reset_i),
        .addr_o(addr),
        .we_o(cpu_we),
        .data_in_i(cpu_data_in),
        .data_out_o(cpu_data_out),
        .wr_mask_o(wr_mask)
    );

    uart #(
        .FREQ_HZ(FREQ_HZ),
        .BAUDS(BAUDS)
    ) uart(
        .clk(clk),
        .reset_i(reset_i),
        .tx_o(tx_o),
        .rx_i(rx_i),
        .wr_i(uart_wr),
        .rd_i(uart_rd),
        .tx_data_i(uart_tx_data),
        .rx_data_o(uart_rx_data),
        .busy_o(uart_busy),
        .valid_o(uart_valid)
    );

    always_comb begin
        mem_data_out = (addr[31:28] == 4'h1) ? spram_data_out : bram_data_out;
    end
    
    vga vga(
        .clk(clk_pix),
        .reset_i(reset_i),

        .vram_sel_o(),
        .vram_wr_o(),
        .vram_mask_o(),
        .vram_addr_o(),
        .vram_data_in_i(),
        .vram_data_out_o(),   

        .vga_hsync_o(vga_hsync_o),
        .vga_vsync_o(vga_vsync_o),
        .vga_r_o(vga_r_o),
        .vga_g_o(vga_g_o),
        .vga_b_o(vga_b_o)
    );

    // address decoding
    always_comb begin
        mem_we = 1'b0;
        display_we = 1'b0;
        mem_data_in = cpu_data_out;
        display = 8'd0;
        cpu_data_in = mem_data_out;
        uart_tx_strobe = 1'b0;
        uart_rx_strobe = 1'b0;
        if (cpu_we) begin
            // write
            if (addr[31:28] == 4'h2) begin
                // peripheral
                case (addr[13:12])
                    2'b01: begin
                        // display
                        display_we = 1'b1;
                    end
                    2'b10: begin
                        // UART
                        if (addr[11:0] == 12'd0) begin
                            // data
                            uart_tx_strobe = 1'b1;
                        end
                    end
                endcase
            end else begin
                // memory
                mem_we = 1'b1;
            end
        end else begin
            // read
            if (addr[31:28] == 4'h2) begin
                // peripheral
                case (addr[13:12])
                    2'b10: begin
                        // UART
                        if (addr[11:0] == 12'd0) begin
                            // data
                            uart_rx_strobe = 1'b1;
                            cpu_data_in = {24'd0, uart_rx_data};
                        end else if (addr[11:0] == 12'd4) begin
                            // status
                            cpu_data_in = {30'd0, uart_valid, uart_busy};
                        end
                    end
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (display_we)
            display_o <= cpu_data_out[7:0];
    end

    always @(posedge clk) begin
        if (uart_tx_strobe) begin
            uart_tx_data <= cpu_data_out[7:0];
            uart_wr <= 1'b1;
        end else begin
            uart_wr <= 1'b0;
        end

        if (uart_rx_strobe) begin
            uart_rd <= 1'b1;
        end else begin
            uart_rd <= 1'b0;
        end
    end
    

endmodule