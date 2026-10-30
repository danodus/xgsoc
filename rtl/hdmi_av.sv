// hdmi_av.sv
// Copyright (c) 2026 Daniel Cliche
// SPDX-License-Identifier: MIT

// HDMI transmitter wrapper around ecp5_hdmi_audio_video.
// Timing matches the framebuffer modes in soc_top. cx/cy are the timing master.
// DVI_OUTPUT drops the audio packets so a build without PCM still has a picture.

module hdmi_av #(
    parameter CLK_HZ = 25_000_000,
    parameter DVI_OUTPUT = 1'b0
) (
    input  wire logic        clk_pixel,
    input  wire logic        clk_pixel_x5,
    input  wire logic        reset,
    input  wire logic [23:0] rgb,
    input  wire logic [15:0] audio_left,
    input  wire logic [15:0] audio_right,
    output wire logic [3:0]  gpdi_dp,
    output wire logic        sample_strobe,
    output wire logic [11:0] cx,
    output wire logic [11:0] cy
);
`ifdef VIDEO_480P
    localparam VIDEO_ID_CODE = 0;
    localparam FRAME_WIDTH = 1088;
    localparam FRAME_HEIGHT = 517;
    localparam SCREEN_WIDTH = 848;
    localparam SCREEN_HEIGHT = 480;
    localparam HSYNC_PULSE_START = 16;
    localparam HSYNC_PULSE_SIZE = 112;
    localparam VSYNC_PULSE_START = 6;
    localparam VSYNC_PULSE_SIZE = 8;
    localparam INVERT_POLARITY = 0;
`elsif VIDEO_720P
    localparam VIDEO_ID_CODE = 4;
    localparam FRAME_WIDTH = 1650;
    localparam FRAME_HEIGHT = 750;
    localparam SCREEN_WIDTH = 1280;
    localparam SCREEN_HEIGHT = 720;
    localparam HSYNC_PULSE_START = 110;
    localparam HSYNC_PULSE_SIZE = 40;
    localparam VSYNC_PULSE_START = 5;
    localparam VSYNC_PULSE_SIZE = 5;
    localparam INVERT_POLARITY = 0;
`elsif VIDEO_1080P
    localparam VIDEO_ID_CODE = 34;
    localparam FRAME_WIDTH = 2200;
    localparam FRAME_HEIGHT = 1125;
    localparam SCREEN_WIDTH = 1920;
    localparam SCREEN_HEIGHT = 1080;
    localparam HSYNC_PULSE_START = 88;
    localparam HSYNC_PULSE_SIZE = 44;
    localparam VSYNC_PULSE_START = 4;
    localparam VSYNC_PULSE_SIZE = 5;
    localparam INVERT_POLARITY = 0;
`else
    // VGA, and QVGA displayed in a doubled 640x480 raster.
    localparam VIDEO_ID_CODE = 1;
    localparam FRAME_WIDTH = 800;
    localparam FRAME_HEIGHT = 525;
    localparam SCREEN_WIDTH = 640;
    localparam SCREEN_HEIGHT = 480;
    localparam HSYNC_PULSE_START = 16;
    localparam HSYNC_PULSE_SIZE = 96;
    localparam VSYNC_PULSE_START = 10;
    localparam VSYNC_PULSE_SIZE = 2;
    localparam INVERT_POLARITY = 1;
`endif

    localparam COUNTER_WIDTH = 12;

    wire [3:0] tmds_p;
    wire [3:0] tmds_n;
    wire [2:0] tmds;
    wire tmds_clock;
    wire [COUNTER_WIDTH-1:0] frame_width, frame_height, screen_width, screen_height;

    generate
        if (!DVI_OUTPUT) begin : audio_clk
            hdmi_audio_clk_gen #(
                .CLK_HZ(CLK_HZ),
                .AUDIO_HZ(48000)
            ) u_audio_clk (
                .clk_pixel(clk_pixel),
                .reset(reset),
                .sample_strobe(sample_strobe)
            );
        end else begin : no_audio
            assign sample_strobe = 1'b0;
        end
    endgenerate

    hdmi #(
        .VIDEO_ID_CODE(VIDEO_ID_CODE),
        .IT_CONTENT(1'b1),
        .DVI_OUTPUT(DVI_OUTPUT),
        .AUDIO_RATE(48000),
        .AUDIO_BIT_WIDTH(16),
        .TMDS_CLOCK_DDR(0),
        .TMDS_DIFFERENTIAL(0),
        .FRAME_WIDTH(FRAME_WIDTH),
        .FRAME_HEIGHT(FRAME_HEIGHT),
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .HSYNC_PULSE_START(HSYNC_PULSE_START),
        .HSYNC_PULSE_SIZE(HSYNC_PULSE_SIZE),
        .VSYNC_PULSE_START(VSYNC_PULSE_START),
        .VSYNC_PULSE_SIZE(VSYNC_PULSE_SIZE),
        .INVERT_POLARITY(INVERT_POLARITY),
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) u_hdmi (
        .clk_pixel_x5(clk_pixel_x5),
        .clk_pixel(clk_pixel),
        .sample_strobe(sample_strobe),
        .reset(reset),
        .rgb(rgb),
        .audio_sample_word_0(audio_left),
        .audio_sample_word_1(audio_right),
        .frame_height_i({COUNTER_WIDTH{1'b0}}),
        .tmds(tmds),
        .tmds_clock(tmds_clock),
        .tmds_p(tmds_p),
        .tmds_n(tmds_n),
        .cx(cx),
        .cy(cy),
        .frame_width(frame_width),
        .frame_height(frame_height),
        .screen_width(screen_width),
        .screen_height(screen_height)
    );

    assign gpdi_dp = tmds_p;

endmodule
