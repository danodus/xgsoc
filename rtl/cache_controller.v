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

`timescale 1ns / 1ps
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
            cache_dirty[i] = `WAYS'd0;
            cache_lru0[i]  = `WAYS'd0;
            cache_lru1[i]  = `WAYS'd1;
            cache_lru2[i]  = `WAYS'd2;
            cache_lru3[i]  = `WAYS'd3;
            cache_addr0[i] = 19-`SETS'd0;
            cache_addr1[i] = 19-`SETS'd1;
            cache_addr2[i] = 19-`SETS'd2;
            cache_addr3[i] = 19-`SETS'd3;
        end
    end
    
    reg [2:0]STATE = 0;
    reg [6:0]lowaddr = 0; //cache mem address
    reg s_lowaddr5 = 0;
    wire [31:0]cache_QA;
    wire [`WAYS-1:0]lru[(1<<`WAYS)-1:0];

    assign fit[0] = ~r_flush && (cache_addr0[index] == {1'b1, addr[25:8+`SETS]});
    assign fit[1] = ~r_flush && (cache_addr1[index] == {1'b1, addr[25:8+`SETS]});
    assign fit[2] = ~r_flush && (cache_addr2[index] == {1'b1, addr[25:8+`SETS]});
    assign fit[3] = ~r_flush && (cache_addr3[index] == {1'b1, addr[25:8+`SETS]});
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
                        0: begin waddr <= {cache_addr0[index], index}; if(!r_flush) cache_addr0[index] <= {1'b1, addr[25:8+`SETS]}; end
                        1: begin waddr <= {cache_addr1[index], index}; if(!r_flush) cache_addr1[index] <= {1'b1, addr[25:8+`SETS]}; end
                        2: begin waddr <= {cache_addr2[index], index}; if(!r_flush) cache_addr2[index] <= {1'b1, addr[25:8+`SETS]}; end
                        3: begin waddr <= {cache_addr3[index], index}; if(!r_flush) cache_addr3[index] <= {1'b1, addr[25:8+`SETS]}; end
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
        endcase
    end
    
endmodule
