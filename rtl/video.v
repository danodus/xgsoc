`timescale 1ns / 1ps

/*Project Oberon, Revised Edition 2013

Book copyright (C)2013 Niklaus Wirth and Juerg Gutknecht;
software copyright (C)2013 Niklaus Wirth (NW), Juerg Gutknecht (JG), Paul
Reed (PR/PDR).

Permission to use, copy, modify, and/or distribute this software and its
accompanying documentation (the "Software") for any purpose with or
without fee is hereby granted, provided that the above copyright notice
and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHORS DISCLAIM ALL WARRANTIES
WITH REGARD TO THE SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY, FITNESS AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS BE LIABLE FOR ANY CLAIM, SPECIAL, DIRECT, INDIRECT, OR
CONSEQUENTIAL DAMAGES OR ANY DAMAGES OR LIABILITY WHATSOEVER, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE DEALINGS IN OR USE OR PERFORMANCE OF THE SOFTWARE.*/

// 1024x768 display controller NW/PR 24.1.2014
// OberonStation (externally-clocked) ver PR 7.8.15/03.10.15
// Modified for SDRAM - Nicolae Dumitrache 2016

module video #(
    parameter CORDW=11,   // signed coordinate width (bits)
    parameter H_RES=640,  // horizontal resolution (pixels)
    parameter V_RES=480,  // vertical resolution (lines)
    parameter H_FP=16,    // horizontal front porch
    parameter H_SYNC=96,  // horizontal sync
    parameter H_BP=48,    // horizontal back porch
    parameter V_FP=10,    // vertical front porch
    parameter V_SYNC=2,   // vertical sync
    parameter V_BP=33     // vertical back porch
) (
    input clk, pclk, ce,
    input [1:0] zoom,
    input [31:0] viddata,
`ifdef HDMI
    // Transmitter beam. rgb during cycle cx is what the encoder emits as
    // screen pixel cx-1, so the line is prefetched one pixel early.
    input [CORDW-1:0] cx,
    input [CORDW-1:0] cy,
    input vid_ready,       // pixel FIFO has a word
`endif
    output reg req,  // SRAM read request
    output hsync, vsync,  // to display
    output de,
    output [15:0] RGB
);

  localparam H_TOTAL = H_RES + H_FP + H_SYNC + H_BP;
  localparam V_TOTAL = V_RES + V_FP + V_SYNC + V_BP;

`ifdef HDMI
wire [CORDW-1:0] hcnt = cx;
wire [CORDW-1:0] vcnt = cy;
`else
reg [CORDW-1:0] hcnt;
reg [CORDW-1:0] vcnt;
`endif
reg hword;  // from hcnt, but latched in the clk domain
reg [31:0] vidbuf, pixbuf;
reg hblank;
wire hend, vend, vblank, xfer;
wire [15:0] vid;
`ifndef HDMI
reg [1:0] init_req_counter;
`endif

assign de = !(hblank|vblank);

assign hend = (hcnt == H_TOTAL-1), vend = (vcnt == V_TOTAL-1);
assign vblank = (vcnt >= V_RES);
assign hsync = (hcnt >= H_RES+H_FP) & (hcnt < H_RES+H_FP+H_BP);
assign vsync = (vcnt >= V_RES+V_FP) & (vcnt < V_RES+V_FP+V_BP);
// zoom is the log2 of the pixel repeat: 0 native, 1 is 2x2, 2 is 4x4.
// A FIFO word is two RGB565 pixels, so it covers 2, 4, or 8 output clocks.
assign xfer = (zoom == 2'd2) ? (hcnt[2:0] == 3'b111) :
              (zoom == 2'd1) ? (hcnt[1:0] == 2'b11) : hcnt[0];
assign vid = (~hblank & ~vblank) ? pixbuf[15:0] : 16'd0;
assign RGB = vid;

`ifdef HDMI
// The beam free-runs. An empty FIFO repeats the last pixel instead of
// stalling, which would unlock the transmitter. The FIFO is refilled from
// framebuffer address 0 during vertical blank (see soc_top), and the first
// word of each line is popped on the last blanking pixel so screen pixel 0
// is framebuffer pixel 0.
wire next_line_active = (vcnt == V_TOTAL-1) || (vcnt < V_RES-1);
wire prefetch = (hcnt == H_TOTAL-2) && next_line_active;
// Pop the next word at the start of the word's second pixel, and not past
// the last word of the line. The blanking prefetch supplies word 0.
wire pair = (zoom == 2'd2) ? (~vblank && (hcnt[2:0] == 3'b100) && (hcnt <= H_RES-12)) :
            (zoom == 2'd1) ? (~vblank && (hcnt[1:0] == 2'b10) && (hcnt <= H_RES-6)) :
                             (~vblank && ~hcnt[0] && (hcnt <= H_RES-4));
wire want = prefetch || pair;

always @(posedge pclk) begin
  hblank <= (hcnt == 0) ? 1'b0 : ((hcnt >= H_RES) ? 1'b1 : hblank);
  hword <= xfer;
  if (want && !vid_ready) begin
    req <= 1'b0;
  end else begin
    req <= want;
    vidbuf <= req ? viddata : vidbuf;
    if (zoom == 2'd2) begin
      if (hcnt[2:0] == 3'b000)
        pixbuf <= vidbuf;
      else if (hcnt[2:0] == 3'b100)
        pixbuf <= {16'd0, pixbuf[31:16]};
    end else if (zoom == 2'd1) begin
      if (hcnt[1:0] == 2'b00)
        pixbuf <= vidbuf;
      else if (hcnt[1:0] == 2'b10)
        pixbuf <= {16'd0, pixbuf[31:16]};
    end else
      pixbuf <= hcnt[0] ? {16'd0, pixbuf[31:16]} : vidbuf;
  end
end
`else
always @(posedge pclk) if(ce && init_req_counter == 2'd0) begin  // pixel clock domain
  hcnt <= hend ? 0 : hcnt+1;
  vcnt <= hend ? (vend ? 0 : (vcnt+1)) : vcnt;
  if (zoom == 2'd0) begin
    hblank <= xfer ? (hcnt >= H_RES) : hblank;
    pixbuf <= xfer ? vidbuf : {16'd0, pixbuf[31:16]};
  end else if (zoom == 2'd1) begin
    // The first word is prefetched during the preceding line's blanking interval.
    // Each half-word is kept for two output clocks while the image is doubled.
    hblank <= (hcnt == H_TOTAL-1) ? 1'b0 : (xfer ? (hcnt >= H_RES-1) : hblank);
    pixbuf <= ((hcnt[1:0] == 2'b11) || (hcnt[1:0] == 2'b00)) ? vidbuf : {pixbuf[31:16], pixbuf[31:16]};
  end else begin
    hblank <= (hcnt == H_TOTAL-1) ? 1'b0 : (xfer ? (hcnt >= H_RES-1) : hblank);
    if ((hcnt[2:0] == 3'b111) || (hcnt[2:0] == 3'b000))
      pixbuf <= vidbuf;
    else if (hcnt[2:0] == 3'b100)
      pixbuf <= {16'd0, pixbuf[31:16]};
  end
end

always @(posedge pclk) if(ce) begin  // CPU (SRAM) clock domain
  if (init_req_counter == 2'd0) begin
    hword <= xfer;
    req <= ~vblank & (hcnt < H_RES) & hword;  // i.e. adr changed
    vidbuf <= req ? viddata : vidbuf;
  end else begin
    req <= 1;
    init_req_counter <= init_req_counter - 1;
  end
end else begin
  req <= 0;
  init_req_counter <= 2'd2;
end
`endif

endmodule
