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

// NW 4.5.09 / 15.11.10
// RS232 receiver for 8 bit data


module uart_rx #(
  parameter FREQ_HZ = 25_000_000,
  parameter BAUD_RATE = 115_200
) (
    input clk, rst,
	  input RxD,
    input fsel,
    input done,   // "byte has been read"
    output rdy,
    output [7:0] data);

wire endtick, midtick, endbit;
wire [11:0] limit;
reg run, stat;
reg Q0, Q1;  // synchronizer and edge detector
reg [11:0] tick;
reg [3:0] bitcnt;
reg [7:0] shreg;
reg [3:0] inptr, outptr;
reg [7:0] fifo [15:0];  // 16 byte buffer

assign limit = fsel ? FREQ_HZ / (BAUD_RATE * 2) : FREQ_HZ / BAUD_RATE;
assign endtick = tick == limit;
assign midtick = tick == {1'b0, limit[11:1]};  // limit/2
assign endbit = bitcnt == 8;
assign data = fifo[outptr];
assign rdy = ~(inptr == outptr);

always @ (posedge clk) begin
  Q0 <= RxD; Q1 <= Q0;
  run <= (Q1 & ~Q0) | ~(~rst | endtick & endbit) & run;
  tick <= (run & ~endtick) ? tick+1 : 0;
  bitcnt <= (endtick & ~endbit) ? bitcnt + 1 :
  (endtick & endbit) ? 0 : bitcnt;
  shreg <= midtick ? {Q1, shreg[7:1]} : shreg;
  stat <= ~(inptr == outptr) | ~(~rst | done) & stat;
  outptr <= ~rst ? 0 : rdy & done ? outptr+1 : outptr;
  inptr <= ~rst ? 0 : (endtick & endbit) ? inptr+1 : inptr;
  if (endtick & endbit) fifo[inptr] <= shreg;  
end
endmodule
