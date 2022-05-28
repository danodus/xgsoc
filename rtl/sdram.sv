// sdram.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module sdram(
    input  wire logic        clk,
    input  wire logic        reset_i,
    input  wire logic        sel_i,
    input  wire logic        wr_en_i,
    input  wire logic [3:0]  wr_mask_i,
    input  wire logic [31:0] address_in_i,
    input  wire logic [31:0] data_in_i,
    output      logic [31:0] data_out_o,
    output      logic        ack_o,

    output      logic [42:0] writer_d_o,
    output      logic        writer_enq_o,
    input  wire logic        writer_full_i,
    input  wire logic        writer_alm_full_i,

    input  wire logic [15:0] reader_q_i,
    output      logic        reader_deq_o,
    input  wire logic        reader_empty_i,
    input  wire logic        reader_alm_empty_i
);

    enum { IDLE, WRITE0, WRITE1, WRITE2, READ0, READ1, READ2, READ3, READ4, READ5, READ6, READ7, WAIT_DESELECT } state;

    logic [31:0] address;
    logic [31:0] data;
    logic [3:0]  wr_mask;

    always_ff @(posedge clk) begin
        if (reset_i) begin
            state <= IDLE;
            ack_o <= 1'b0;
            writer_enq_o <= 1'b0;
            reader_deq_o <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (sel_i) begin
                        address <= address_in_i;
                        if (wr_en_i) begin
                            data <= data_in_i;
                            wr_mask <= wr_mask_i;
                            //$display("SDRAM write value %x with mask %x", data_in_i, wr_mask_i);
                            state <= WRITE0;
                        end else begin
                            state <= READ0;
                        end
                    end
                end

                WRITE0: begin
                    if (!writer_full_i) begin
                        writer_d_o <= {1'b1, wr_mask[3:2], {address[22:0], 1'b0}, data[31:16]};
                        writer_enq_o <= 1'b1;
                        state <= WRITE1;
                    end
                end

                WRITE1: begin
                    writer_enq_o <= 1'b0;
                    state <= WRITE2;
                end

                WRITE2: begin
                    if (!writer_full_i) begin
                        writer_d_o <= {1'b1, wr_mask[1:0], {address[22:0], 1'b1}, data[15:0]};
                        writer_enq_o <= 1'b1;
                        ack_o <= 1'b1;
                        state <= WAIT_DESELECT;
                    end
                end

                READ0: begin
                    if (!writer_full_i) begin
                        writer_d_o <= {1'b0, 2'b00, {address[22:0], 1'b0}, 16'd0};
                        writer_enq_o <= 1'b1;
                        //$display("Enq: %x", {address[22:0], 1'b0});
                        state <= READ1;
                    end
                end

                READ1: begin
                    writer_enq_o <= 1'b0;
                    state <= READ2;
                end

                READ2: begin
                    if (!writer_full_i) begin
                        writer_d_o <= {1'b0, 2'b00, {address[22:0], 1'b1}, 16'd0};
                        writer_enq_o <= 1'b1;
                        //$display("Enq: %x", {address[22:0], 1'b1});
                        state <= READ3;
                    end
                end

                READ3: begin
                    writer_enq_o <= 1'b0;
                    state <= READ4;
                end

                READ4: begin
                    if (!reader_empty_i) begin
                        // read MSW
                        reader_deq_o <= 1'b1;
                        state <= READ5;
                    end
                end

                READ5: begin
                    reader_deq_o <= 1'b0;
                    data_out_o[31:16] <= reader_q_i;
                    state <= READ6;
                end

                READ6: begin
                    if (!reader_empty_i) begin
                        // read LSW
                        reader_deq_o <= 1'b1;
                        state <= READ7;
                    end
                end

                READ7: begin
                    reader_deq_o <= 1'b0;
                    data_out_o[15:0] <= reader_q_i;
                    ack_o <= 1'b1;
                    state <= WAIT_DESELECT;
                end

                WAIT_DESELECT: begin
                    writer_enq_o <= 1'b0;
                    ack_o <= 1'b0;
                    if (!sel_i)
                        state <= IDLE;
                end

            endcase
        end
    end

endmodule