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

    input  wire logic        clk_sdram,

    // SDRAM
    output      logic        sdram_clk_o,
    output      logic        sdram_cke_o,
    output      logic        sdram_cs_n_o,
    output      logic        sdram_we_n_o,
    output      logic        sdram_ras_n_o,
    output      logic        sdram_cas_n_o,
    output      logic [12:0] sdram_a_o,
    output      logic [1:0]  sdram_ba_o,
    output      logic [1:0]  sdram_dqm_o,
    inout       logic [15:0] sdram_dq_io,

    input  wire logic         xosera_bus_cs_n_i,           // register select strobe (active low)
    input  wire logic         xosera_bus_rd_nwr_i,         // 0 = write, 1 = read
    input  wire logic [3:0]   xosera_bus_reg_num_i,        // register number
    input  wire logic         xosera_bus_bytesel_i,        // 0 = even byte, 1 = odd byte
    input  wire logic [7:0]   xosera_bus_data_i,           // 8-bit data bus input
    output logic      [7:0]   xosera_bus_data_o,           // 8-bit data bus output
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

    localparam  FB_WIDTH = 640;
    localparam  FB_HEIGHT = 480;

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

    logic [3:0] xosera_r, xosera_g, xosera_b;

    assign sdram_clk_o = clk_sdram;
    
    // VGA output
    
    logic [11:0] line_counter, col_counter;

    always_comb begin
        graphite_vga_r = 4'h0;
        graphite_vga_g = 4'h0;
        graphite_vga_b = 4'h0;
        if (xosera_vga_de) begin
            graphite_vga_r = stream_data[11:8];
            graphite_vga_g = stream_data[7:4];
            graphite_vga_b = stream_data[3:0];
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

    logic        vram_ack;
    logic        vram_sel;
    logic        vram_wr;
    logic [3:0]  vram_mask;
    logic [31:0] vram_address;
    logic [15:0] vram_data_out;

    logic [15:0] vram_data, stream_data;
    logic stream_preloading;

    logic [31:0] front_addr;

    framebuffer #(
        .SDRAM_CLK_FREQ_MHZ(SDRAM_CLK_FREQ_MHZ),
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT)
    ) framebuffer(
        .clk_pix(clk),
        .reset_i(reset_i),

        // SDRAM interface
        .sdram_rst(reset_i),
        .sdram_clk(clk_sdram),
        .sdram_ba_o(sdram_ba_o),
        .sdram_a_o(sdram_a_o),
        .sdram_cs_n_o(sdram_cs_n_o),
        .sdram_ras_n_o(sdram_ras_n_o),
        .sdram_cas_n_o(sdram_cas_n_o),
        .sdram_we_n_o(sdram_we_n_o),
        .sdram_dq_io(sdram_dq_io),
        .sdram_dqm_o(sdram_dqm_o),
        .sdram_cke_o(sdram_cke_o),

        // Framebuffer access
        .ack_o(vram_ack),
        .sel_i(vram_sel),
        .wr_i(vram_wr),
        .mask_i(vram_mask),
        .address_i(vram_address[23:0]),
        .data_in_i(vram_data_out),
        .data_out_o(vram_data),

        // Framebuffer output data stream
        .stream_start_frame_i(frame),
        .stream_base_address_i(front_addr[23:0]),
        .stream_ena_i(xosera_vga_de),
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
        .vram_wr_o(vram_wr),
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
        .bus_intr_o(),                            // Xosera CPU interrupt strobe
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
