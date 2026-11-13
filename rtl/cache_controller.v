//////////////////////////////////////////////////////////////////////////////////
//
// This file is part of the Next186 Soc PC project
// http://opencores.org/project,next186
//
// Filename: cache_controller.v
// Description: Part of the Next186 SoC PC project, cache controller
// Version 1.0
// Creation date: Jan2012
//
// Author: Nicolae Dumitrache 
// e-mail: ndumitrache@opencores.org
//
/////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (C) 2012 Nicolae Dumitrache
// 
// This source file may be used and distributed without 
// restriction provided that this copyright statement is not 
// removed from the file and that any derivative work contains 
// the original copyright notice and the associated disclaimer.
// 
// This source file is free software; you can redistribute it 
// and/or modify it under the terms of the GNU Lesser General 
// Public License as published by the Free Software Foundation;
// either version 2.1 of the License, or (at your option) any 
// later version. 
// 
// This source is distributed in the hope that it will be 
// useful, but WITHOUT ANY WARRANTY; without even the implied 
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR 
// PURPOSE. See the GNU Lesser General Public License for more 
// details. 
// 
// You should have received a copy of the GNU Lesser General 
// Public License along with this source; if not, download it 
// from http://www.opencores.org/lgpl.shtml 
// 
///////////////////////////////////////////////////////////////////////////////////
// Additional Comments: 
//
// adapted for Lattice Diamond, which does not support array initialization
//////////////////////////////////////////////////////////////////////////////////

`define WAYS	2	// 2^ways
`define SETS	4	// 2^sets

module cache_controller(
     input [25:0] addr,
     output [31:0] dout,
     input [31:0]din,
     input clk,	
     input mreq,
     input [3:0]wmask,
     output ce,	// clock enable for CPU
     input [15:0]ddr_din,
     output reg[15:0]ddr_dout,
     input ddr_clk,
     input cache_write_data, // 1 when data must be written to cache, on posedge ddr_clk
     input cache_read_data, // 1 when data must be read from cache, on posedge ddr_clk
     output reg ddr_rd = 0,
     output reg ddr_wr = 0,
     output reg [17:0] waddr,
     input flush,
     input clear
    );
    
    reg flushreq = 1'b0;
    reg [`WAYS+`SETS:0]flushcount = 0;
    wire r_flush = flushcount[`WAYS+`SETS];
    wire [`SETS-1:0]index = r_flush ? flushcount[`SETS-1:0] : addr[8+`SETS-1:8];
    wire [(1<<`WAYS)-1:0]fit;
    wire [(1<<`WAYS)-1:0]free;
    wire wr = |wmask;
    
    reg [(1<<`WAYS)-1:0]cache_dirty[0:(1<<`SETS)-1];

    reg [`WAYS-1:0]cache_lru0[0:(1<<`SETS)-1];
    reg [`WAYS-1:0]cache_lru1[0:(1<<`SETS)-1];
    reg [`WAYS-1:0]cache_lru2[0:(1<<`SETS)-1];
    reg [`WAYS-1:0]cache_lru3[0:(1<<`SETS)-1];

    // MSB is cache valid
    reg [1+17-`SETS:0]cache_addr0[0:(1<<`SETS)-1];
    reg [1+17-`SETS:0]cache_addr1[0:(1<<`SETS)-1];
    reg [1+17-`SETS:0]cache_addr2[0:(1<<`SETS)-1];
    reg [1+17-`SETS:0]cache_addr3[0:(1<<`SETS)-1];

    integer i;
    initial begin
        for(i = 0; i < 1 << `SETS; i = i + 1) begin
            cache_dirty[i] = 'd0;
            cache_lru0[i]  = 'd0;
            cache_lru1[i]  = 'd1;
            cache_lru2[i]  = 'd2;
            cache_lru3[i]  = 'd3;
            cache_addr0[i] = 'd0;
            cache_addr1[i] = 'd1;
            cache_addr2[i] = 'd2;
            cache_addr3[i] = 'd3;
        end
    end
    
    reg [2:0]STATE = 0;
    reg [6:0]lowaddr = 0; //cache mem address
    reg s_lowaddr5 = 0;
    wire [31:0]cache_QA;
    wire [`WAYS-1:0]lru[(1<<`WAYS)-1:0];

    // Tag match is on the half-cycle path into the cache data RAM (clk_b is ~clk).
    // A plain == on the async tag RAM is mapped to a LUT ripple. Compare on a
    // CCU2C carry chain instead, which is short enough for the 20 ns half cycle.
    localparam TAG_MSB = 1 + 17 - `SETS;
    wire [TAG_MSB:0] tag_cmp = {1'b1, addr[25:8+`SETS]};
    wire [TAG_MSB:0] tag0 = cache_addr0[index];
    wire [TAG_MSB:0] tag1 = cache_addr1[index];
    wire [TAG_MSB:0] tag2 = cache_addr2[index];
    wire [TAG_MSB:0] tag3 = cache_addr3[index];
    wire tag_eq0, tag_eq1, tag_eq2, tag_eq3;
    tag_eq_carry #(.WIDTH(TAG_MSB+1)) tag_cmp0 (.a(tag0), .b(tag_cmp), .eq(tag_eq0));
    tag_eq_carry #(.WIDTH(TAG_MSB+1)) tag_cmp1 (.a(tag1), .b(tag_cmp), .eq(tag_eq1));
    tag_eq_carry #(.WIDTH(TAG_MSB+1)) tag_cmp2 (.a(tag2), .b(tag_cmp), .eq(tag_eq2));
    tag_eq_carry #(.WIDTH(TAG_MSB+1)) tag_cmp3 (.a(tag3), .b(tag_cmp), .eq(tag_eq3));
    assign fit[0] = ~r_flush && tag_eq0;
    assign fit[1] = ~r_flush && tag_eq1;
    assign fit[2] = ~r_flush && tag_eq2;
    assign fit[3] = ~r_flush && tag_eq3;
    assign free[0] = r_flush ? (flushcount[`WAYS+`SETS-1:`SETS] == 0) : ~|cache_lru0[index];
    assign free[1] = r_flush ? (flushcount[`WAYS+`SETS-1:`SETS] == 1) : ~|cache_lru1[index];
    assign free[2] = r_flush ? (flushcount[`WAYS+`SETS-1:`SETS] == 2) : ~|cache_lru2[index];
    assign free[3] = r_flush ? (flushcount[`WAYS+`SETS-1:`SETS] == 3) : ~|cache_lru3[index];
    assign lru[0] = {`WAYS{fit[0]}} & cache_lru0[index];
    assign lru[1] = {`WAYS{fit[1]}} & cache_lru1[index];
    assign lru[2] = {`WAYS{fit[2]}} & cache_lru2[index];
    assign lru[3] = {`WAYS{fit[3]}} & cache_lru3[index];

    wire hit = |fit;
    wire st0 = STATE == 3'b000;
    assign ce = st0 && (~mreq || hit);
    wire dirty = |(free & cache_dirty[index]);	

    wire [`WAYS-1:0]blk = flushcount[`WAYS+`SETS-1:`SETS] | {|fit[3:2], fit[3] | fit[1]};
    wire [`WAYS-1:0]fblk = {|free[3:2], free[3] | free[1]};
    wire [`WAYS-1:0]csblk = lru[0] | lru[1] | lru[2] | lru[3];

    always @(posedge ddr_clk) begin
        if(cache_write_data || cache_read_data) lowaddr <= lowaddr + 1;
        ddr_dout <= lowaddr[0] ? cache_QA[15:0] : cache_QA[31:16];
    end

        bram32bit
        #(
          .addr_width(12)
        )
        bram32bit_inst
        (
          .clk_a(ddr_clk),
          .clken_a(cache_write_data | cache_read_data),
          .addr_a({blk, ~index[`SETS-1:2], index[1:0], lowaddr[6:1]}),
          .we_a({{2{lowaddr[0]}}, {2{~lowaddr[0]}}} & {4{cache_write_data}}),
          .data_in_a({ddr_din, ddr_din}),
          .data_out_a(cache_QA),
          .clk_b(~clk),
          .clken_b(mreq & hit & st0),
          .addr_b({blk, ~index[`SETS-1:2], index[1:0], addr[7:2]}),
          .we_b(wmask & {4{wr}}),
          .data_in_b(din),
          .data_out_b(dout)
        );

        always @(posedge clk)
            if(st0 && mreq)
                if(hit) begin
                    cache_lru0[index] <= fit[0] ? {`WAYS{1'b1}} : cache_lru0[index] - (cache_lru0[index] > csblk); 
                    cache_lru1[index] <= fit[1] ? {`WAYS{1'b1}} : cache_lru1[index] - (cache_lru1[index] > csblk); 
                    cache_lru2[index] <= fit[2] ? {`WAYS{1'b1}} : cache_lru2[index] - (cache_lru2[index] > csblk); 
                    cache_lru3[index] <= fit[3] ? {`WAYS{1'b1}} : cache_lru3[index] - (cache_lru3[index] > csblk); 
                    if(fit[0]) cache_dirty[index][0] <= cache_dirty[index][0] | wr;
                    if(fit[1]) cache_dirty[index][1] <= cache_dirty[index][1] | wr;
                    if(fit[2]) cache_dirty[index][2] <= cache_dirty[index][2] | wr;
                    if(fit[3]) cache_dirty[index][3] <= cache_dirty[index][3] | wr;
                end else begin
                    if(free[0]) cache_dirty[index][0] <= 1'b0;
                    if(free[1]) cache_dirty[index][1] <= 1'b0;
                    if(free[2]) cache_dirty[index][2] <= 1'b0;
                    if(free[3]) cache_dirty[index][3] <= 1'b0;
                end

        
    always @(posedge clk) begin
        s_lowaddr5 <= lowaddr[6];
        flushreq <= ~flushcount[`WAYS+`SETS] & (flushreq | flush);
        
        case(STATE)
            3'b000: begin
                if(mreq && !hit) begin	// cache miss
                    case(fblk)
                        0: begin waddr <= {tag0[17-`SETS:0], index}; if(!r_flush) cache_addr0[index] <= tag_cmp; end
                        1: begin waddr <= {tag1[17-`SETS:0], index}; if(!r_flush) cache_addr1[index] <= tag_cmp; end
                        2: begin waddr <= {tag2[17-`SETS:0], index}; if(!r_flush) cache_addr2[index] <= tag_cmp; end
                        3: begin waddr <= {tag3[17-`SETS:0], index}; if(!r_flush) cache_addr3[index] <= tag_cmp; end
                    endcase
                    ddr_rd <= ~dirty & ~r_flush;
                    ddr_wr <= dirty;
                    STATE <= dirty ? 3'b011 : 3'b100;
                end else flushcount[`WAYS+`SETS] <= flushcount[`WAYS+`SETS] | flushreq;
            end
            3'b011: begin	// write cache to ddr
                ddr_rd <= ~r_flush;
                if(s_lowaddr5) begin
                    ddr_wr <= 1'b0;
                    if (clear) begin
                        STATE <= 3'b100;
                    end else begin
                        STATE <= 3'b111;
                    end
                end
            end
            3'b111: begin // read cache from ddr
                if(~s_lowaddr5) STATE <= 3'b100;
            end
            3'b100: begin	
                if(r_flush) begin
                    flushcount <= flushcount + 1;
                    STATE <= 3'b000;
                end else if(s_lowaddr5) STATE <= 3'b101;
            end
            3'b101: begin
                ddr_rd <= 1'b0;
                if(~s_lowaddr5) STATE <= 3'b000;
            end
            default: begin
            end
        endcase
    end
    
endmodule

// Equality comparator mapped onto the ECP5 carry chain.
// Each slice propagates carry only while the two bits match.
module tag_eq_carry #(
    parameter WIDTH = 15
) (
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output eq
);
    localparam SLICES = (WIDTH + 1) / 2;
    localparam PADDED = SLICES * 2;

    wire [PADDED-1:0] aa = {{(PADDED-WIDTH){1'b0}}, a};
    wire [PADDED-1:0] bb = {{(PADDED-WIDTH){1'b0}}, b};
    wire [SLICES:0] carry;
    assign carry[0] = 1'b1;

    genvar i;
    generate
        for (i = 0; i < SLICES; i = i + 1) begin : slice
            CCU2C #(
                .INIT0(16'h9999),
                .INIT1(16'h9999),
                .INJECT1_0("NO"),
                .INJECT1_1("NO")
            ) cmp (
                .CIN(carry[i]),
                .A0(aa[2*i]),   .B0(bb[2*i]),   .C0(1'b0), .D0(1'b0),
                .A1(aa[2*i+1]), .B1(bb[2*i+1]), .C1(1'b0), .D1(1'b0),
                .S0(), .S1(),
                .COUT(carry[i+1])
            );
        end
    endgenerate

    assign eq = carry[SLICES];
endmodule
