// xga.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module xga #(
    parameter SDRAM_CLK_FREQ_MHZ = 100
) (
    input wire  logic        clk,
    input wire  logic        reset_i,

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
    output      logic        vga_de_o
);

`ifdef MODE_848x480
    localparam  SCREEN_WIDTH = 848;
`else
    localparam  SCREEN_WIDTH = 640;
`endif
    localparam  SCREEN_HEIGHT = 480;

    localparam  FB_WIDTH = SCREEN_WIDTH / 2;
    localparam  FB_HEIGHT = SCREEN_HEIGHT / 2;

    logic       xosera_vga_hsync;
    logic       xosera_vga_vsync, xosera_vga_vsync_p;
    logic [3:0] xosera_vga_r;
    logic [3:0] xosera_vga_g;
    logic [3:0] xosera_vga_b;
    logic       xosera_vga_de;

    logic [3:0] graphite_vga_r;
    logic [3:0] graphite_vga_g;
    logic [3:0] graphite_vga_b;

`ifdef MODE_848x480
    assign xosera_vga_vsync_p = ~xosera_vga_vsync;
`else
    assign xosera_vga_vsync_p = xosera_vga_vsync;
`endif

    always_comb begin
        vga_hsync_o = xosera_vga_hsync;
        vga_vsync_o = xosera_vga_vsync;
        vga_de_o    = xosera_vga_de;
        if (xosera_vga_de) begin
            vga_r_o     = xosera_vga_r;
            vga_g_o     = xosera_vga_g;
            vga_b_o     = xosera_vga_b;
        end else begin
            vga_r_o = 4'd0;
            vga_g_o = 4'd0;
            vga_b_o = 4'd0;
        end
    end

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
