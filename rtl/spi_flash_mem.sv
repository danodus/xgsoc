/*
 *  kianv.v - a simple RISC-V rv32im
 *
 *  copyright (c) 2021 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */

// January 2022, Daniel Cliche: Conversion to SV

module spi_flash_mem(
    input  wire logic        clk,
    input  wire logic        reset_i,

    input  wire logic        cs_i,
    input  wire logic        rd_i,
    input  wire logic [21:0] addr_i,     // 4 MWord

    output      logic [31:0] data_out_o,
    output      logic        ready_o,
    output      logic        valid_o,

    // external
    output      logic        spi_cs_o,
    input  wire logic        spi_miso_i,
    output      logic        spi_mosi_o,
    output      logic        spi_sclk_o
    );

    function [31:0] adjust_word (
            input [31:0] data
        );
        adjust_word[31:24] = data[7:0];
        adjust_word[23:16] = data[15:8];
        adjust_word[15:8]  = data[23:16];
        adjust_word[7:0]   = data[31:24];
    endfunction

    assign data_out_o = adjust_word(rcv_buff);

    logic [2:0]  state;
    logic [4:0]  shift_cnt;
    logic [31:0] shift_reg;

    assign spi_sclk_o = !clk && !spi_cs_o;
    assign spi_mosi = shift_reg[31];

    logic [31:0] rcv_buff;

    enum {IDLE, SPI_WRITE, SPI_READ} state;

    always_ff @(posedge clk) begin
        if (reset_i) begin
            rcv_buff  <= 0;
            state     <= IDLE;
            shift_reg <= 0;
            spi_cs_o  <= 1'b1;
            ready_o   <= 1'b0;
            valid_o   <= 1'b0;
        end else begin

            case (state)
                IDLE: begin
                    spi_cs_o <= 1'b1;
                    ready    <= 1'b1;
                    valid    <= 1'b0;

                    if (cs_i && rd_i) begin
                        shift_cnt <= 31;
                        shift_reg <= {8h03, addr_i[21:0], 2'b00}; // Read 0x03
                        spi_cs_o  <= 1'0;
                        ready     <= 1'b0;
                        state     <= 1;
                    end
                end

                SPI_WRITE: begin
                    shift_cnt <= shift_cnt - 1;
                    shift_reg <= {shift_reg[30:0], 1'b0};

                    if (shift_cnt == 0) begin
                        shift_cnt <= 31;
                        state     <= 2;
                    end
                end

                SPI_READ: begin
                    shift_cnt <= shift_cnt - 1;
                    rcv_buff  <= {rcv_buff[30:0], spi_miso};

                    if (shift_cnt == 0) begin
                        valid <= 1'b1;
                        state <= IDLE;
                    end
                end

                default:
                    state <= IDLE;

            endcase
        end
    end
endmodule

