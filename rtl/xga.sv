// xga.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module xga #(
    parameter SDRAM_CLK_FREQ_MHZ = 100
) (
    input wire  logic        clk,
    input wire  logic        reset_i,

    input wire  logic        ena_graphite_i,

    // AXI stream command interface (slave)
    input  wire logic                        cmd_axis_tvalid_i,
    output      logic                        cmd_axis_tready_o,
    input  wire logic [31:0]                 cmd_axis_tdata_i,

    // Memory interface
    
    // Writer (input commands)
    output      logic [59:0]           writer_d_o,
    output      logic                  writer_enq_o,
    input  wire logic                  writer_full_i,
    input  wire logic                  writer_alm_full_i,

    output      logic [31:0]           writer_burst_d_o,
    output      logic                  writer_burst_enq_o,
    input  wire logic                  writer_burst_full_i,
    input  wire logic                  writer_burst_alm_full_i,

    // Reader single word (output)
    input  wire logic [15:0]           reader_q_i,
    output      logic                  reader_deq_o,
    input  wire logic                  reader_empty_i,
    input  wire logic                  reader_alm_empty_i,

    // Reader burst (output)
    input  wire logic [127:0]          reader_burst_q_i,
    output      logic                  reader_burst_deq_o,
    input  wire logic                  reader_burst_empty_i,
    input  wire logic                  reader_burst_alm_empty_i,

    // Xosera
    input  wire logic         xosera_bus_cs_n_i,           // register select strobe (active low)
    input  wire logic         xosera_bus_rd_nwr_i,         // 0 = write, 1 = read
    input  wire logic [3:0]   xosera_bus_reg_num_i,        // register number
    input  wire logic         xosera_bus_bytesel_i,        // 0 = even byte, 1 = odd byte
    input  wire logic [7:0]   xosera_bus_data_i,           // 8-bit data bus input
    output logic      [7:0]   xosera_bus_data_o,           // 8-bit data bus output
    output logic              xosera_bus_intr_o,           // Xosera CPU interrupt strobe
    output      logic         xosera_audio_l_o,
    output      logic         xosera_audio_r_o,

    output      logic        vga_hsync_o,
    output      logic        vga_vsync_o,
    output      logic [3:0]  vga_r_o,
    output      logic [3:0]  vga_g_o,
    output      logic [3:0]  vga_b_o,
    output      logic        vga_de_o,

    output      logic        stream_err_underflow_o
);

    localparam  FB_WIDTH = 320;
    localparam  FB_HEIGHT = 240;

    logic       xosera_vga_hsync;
    logic       xosera_vga_vsync;
    logic [3:0] xosera_vga_r;
    logic [3:0] xosera_vga_g;
    logic [3:0] xosera_vga_b;
    logic       xosera_vga_de;

    logic [3:0] graphite_vga_r;
    logic [3:0] graphite_vga_g;
    logic [3:0] graphite_vga_b;

    always_comb begin
        vga_hsync_o = xosera_vga_hsync;
        vga_vsync_o = xosera_vga_vsync;
        vga_de_o    = xosera_vga_de;
        if (xosera_vga_de) begin
            if (ena_graphite_i) begin
                if (xosera_vga_r != 4'd0 || xosera_vga_g != 4'd0 || xosera_vga_b != 4'd0) begin
                    vga_r_o     = xosera_vga_r;
                    vga_g_o     = xosera_vga_g;
                    vga_b_o     = xosera_vga_b;
                end else begin
                    vga_r_o     = graphite_vga_r;
                    vga_g_o     = graphite_vga_g;
                    vga_b_o     = graphite_vga_b;
                end
            end else begin
                vga_r_o     = xosera_vga_r;
                vga_g_o     = xosera_vga_g;
                vga_b_o     = xosera_vga_b;
            end
        end else begin
            vga_r_o = 4'd0;
            vga_g_o = 4'd0;
            vga_b_o = 4'd0;
        end
    end

    // --------------------------------------------------------------------------------------
    // Graphite
    //

    // VGA output
    
    always_comb begin
        graphite_vga_r = 4'h0;
        graphite_vga_g = 4'h0;
        graphite_vga_b = 4'h0;
        if (xosera_vga_de) begin
            graphite_vga_r = sd_stream_data[11:8];
            graphite_vga_g = sd_stream_data[7:4];
            graphite_vga_b = sd_stream_data[3:0];
        end
    end

    logic prev_xosera_vga_vsync, frame;
    always_ff @(posedge clk) begin
        if (reset_i) begin
            frame <= 1'b0;
        end else begin
            prev_xosera_vga_vsync <= xosera_vga_vsync;
            frame <= 1'b0;
            if (prev_xosera_vga_vsync && !xosera_vga_vsync)
                frame <= 1'b1;
        end
    end

    logic sd_stream_ena;
    logic [15:0] sd_stream_data;

    scan_doubler #(
        .VGA_WIDTH(640)
    ) scan_doubler(
        .clk(clk),
        .reset_i(reset_i || !ena_graphite_i),
        .vga_vsync_i(xosera_vga_vsync),
        .vga_de_i(xosera_vga_de),
        .fb_stream_data_i(stream_data),
        .fb_stream_ena_o(sd_stream_ena),
        .stream_data_o(sd_stream_data)
    );

    logic        vram_ack;
    logic        vram_sel;
    logic [19:0] vram_wr_cnt;
    logic [3:0]  vram_mask;
    logic [31:0] vram_address;
    logic [15:0] vram_data_out;

    logic [15:0] vram_data, stream_data;
    logic stream_preloading;

    logic [31:0] front_addr;

    framebuffer #(
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT),
        .FB_BASE_ADDR(24'h800000) // 16*1024*1024/2
    ) framebuffer(
        .clk_pix(clk),
        .reset_i(reset_i || !ena_graphite_i),

        // Memory interface
    
        // Writer (input commands)
        .writer_d_o,
        .writer_enq_o,
        .writer_full_i,
        .writer_alm_full_i,

        .writer_burst_d_o,
        .writer_burst_enq_o,
        .writer_burst_full_i,
        .writer_burst_alm_full_i,

        // Reader single word (output)
        .reader_q_i,
        .reader_deq_o,
        .reader_empty_i,
        .reader_alm_empty_i,

        // Reader burst (output)
        .reader_burst_q_i,
        .reader_burst_deq_o,
        .reader_burst_empty_i,
        .reader_burst_alm_empty_i,

        // Framebuffer access
        .ack_o(vram_ack),
        .sel_i(vram_sel),
        .wr_cnt_i(vram_wr_cnt),
        .mask_i(vram_mask),
        .address_i(vram_address[23:0]),
        .data_in_i(vram_data_out),
        .data_out_o(vram_data),

        // Framebuffer output data stream
        .stream_start_frame_i(frame),
        .stream_base_address_i(front_addr[23:0]),
        .stream_ena_i(sd_stream_ena),
        .stream_data_o(stream_data),
        .stream_preloading_o(stream_preloading),
        .stream_err_underflow_o(stream_err_underflow_o),
        .dbg_state_o()
    );

    graphite #(
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT)
    ) graphite(
        .clk(clk),
        .reset_i(reset_i),
        .cmd_axis_tvalid_i(cmd_axis_tvalid_i),
        .cmd_axis_tready_o(cmd_axis_tready_o),
        .cmd_axis_tdata_i(cmd_axis_tdata_i),
        .vram_ack_i(vram_ack),
        .vram_sel_o(vram_sel),
        .vram_wr_cnt_o(vram_wr_cnt),
        .vram_mask_o(vram_mask),
        .vram_addr_o(vram_address),
        .vram_data_in_i(vram_data),
        .vram_data_out_o(vram_data_out),
        .vsync_i(xosera_vga_vsync),
        .swap_o(),
        .front_addr_o(front_addr)
    );

    // --------------------------------------------------------------------------------------
    // Xosera
    //

    xosera_main xosera(
        .bus_cs_n_i(xosera_bus_cs_n_i),           // register select strobe (active low)
        .bus_rd_nwr_i(xosera_bus_rd_nwr_i),       // 0 = write, 1 = read
        .bus_reg_num_i(xosera_bus_reg_num_i),     // register number
        .bus_bytesel_i(xosera_bus_bytesel_i),     // 0 = even byte, 1 = odd byte
        .bus_data_i(xosera_bus_data_i),           // 8-bit data bus input
        .bus_data_o(xosera_bus_data_o),           // 8-bit data bus output
        .bus_intr_o(xosera_bus_intr_o),           // Xosera CPU interrupt strobe
        .red_o(xosera_vga_r),                     // red color gun output
        .green_o(xosera_vga_g),                   // green color gun output
        .blue_o(xosera_vga_b),                    // blue color gun output
        .hsync_o(xosera_vga_hsync),
        .vsync_o(xosera_vga_vsync),               // horizontal and vertical sync
        .dv_de_o(xosera_vga_de),                  // pixel visible (aka display enable)
        .audio_l_o(xosera_audio_l_o),
        .audio_r_o(xosera_audio_r_o),             // left and right audio PWM output
        .reconfig_o(),                            // reconfigure iCE40 from flash
        .boot_select_o(),                         // reconfigure congigureation number (0-3)
        .reset_i(reset_i),                        // reset signal
        .clk(clk)                                 // pixel clock        
    );

endmodule
