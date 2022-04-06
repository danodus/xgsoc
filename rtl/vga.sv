module vga(
    input wire  logic        clk,
    input wire  logic        reset_i,

`ifdef GRAPHITE
    // AXI stream command interface (slave)
    input  wire logic                        cmd_axis_tvalid_i,
    output      logic                        cmd_axis_tready_o,
    input  wire logic [31:0]                 cmd_axis_tdata_i,
`endif 

`ifdef XOSERA
    input  wire logic         xosera_bus_cs_n_i,           // register select strobe (active low)
    input  wire logic         xosera_bus_rd_nwr_i,         // 0 = write, 1 = read
    input  wire logic [3:0]   xosera_bus_reg_num_i,        // register number
    input  wire logic         xosera_bus_bytesel_i,        // 0 = even byte, 1 = odd byte
    input  wire logic [7:0]   xosera_bus_data_i,           // 8-bit data bus input
    output logic      [7:0]   xosera_bus_data_o,           // 8-bit data bus output
    output      logic         xosera_audio_l_o,
    output      logic         xosera_audio_r_o,
`endif

    output      logic        vga_hsync_o,
    output      logic        vga_vsync_o,
    output      logic [3:0]  vga_r_o,
    output      logic [3:0]  vga_g_o,
    output      logic [3:0]  vga_b_o,
    output      logic        vga_de_o
);


`ifdef GRAPHITE

    // display timings
    localparam CORDW = 16;
    logic signed [CORDW-1:0] sx, sy;
    logic hsync, vsync, de, frame, line;

    logic [3:0] xosera_r, xosera_g, xosera_b;
    
    vga_timings #(.CORDW(CORDW)) vga_timings(
        .clk_pix(clk),
        .rst(reset_i),
        .sx(sx),
        .sy(sy),
        .hsync(hsync),
        .vsync(vsync),
        .de(de),
        .frame(frame),
        .line(line)
    );

    // VGA output
    // 128x128: 14 bits to address 16-bit values
    logic [13:0] vga_read_addr;
    logic [11:0] line_counter, col_counter;
    always_ff @(posedge clk) begin
        vga_hsync_o <= hsync;
        vga_vsync_o <= vsync;
        vga_de_o    <= de;

        if (frame) begin
            col_counter <= 12'd0;
            line_counter <= 12'd0;
            vga_read_addr <= 14'd0;
        end else begin
            if (line) begin
                col_counter  <= 12'd0;
                line_counter <= line_counter + 1;
            end
        end
        

        if (de) begin
            col_counter <= col_counter + 1;
            if (line_counter < 12'd128 && col_counter < 12'd128) begin
                vga_read_addr <= vga_read_addr + 1;
                vga_r_o <= vram_data_out[11:8];
                vga_g_o <= vram_data_out[7:4];
                vga_b_o <= vram_data_out[3:0];
            end else begin
                vga_r_o <= 4'h1;
                vga_g_o <= 4'h1;
                vga_b_o <= 4'h1;
            end
        end else begin
            vga_r_o <= 4'h0;
            vga_g_o <= 4'h0;
            vga_b_o <= 4'h0;
        end

        if (reset_i) begin
            vga_read_addr <= 14'd0;
            line_counter  <= 12'd0;
            col_counter   <= 12'd0;
        end
    end

    // video ram

    logic        vram_wr;
    logic [3:0]  vram_mask;
    logic [15:0] vram_address;
    logic [15:0] vram_data_in;
    logic [15:0] vram_data_out;

    logic        graphite_vram_sel;
    logic        graphite_vram_wr;
    logic [3:0]  graphite_vram_mask;
    logic [31:0] graphite_vram_address;
    logic [15:0] graphite_vram_data_out;    

    assign vram_wr = graphite_vram_sel ? graphite_vram_wr : 1'b0;
    assign vram_mask = graphite_vram_sel ? graphite_vram_mask : 4'hF;
    assign vram_address = graphite_vram_sel ? graphite_vram_address[15:0] : {2'd0, vga_read_addr};
    assign vram_data_in = graphite_vram_sel ? graphite_vram_data_out : 16'd0;

    vram2 vram(
        .clk(clk),
        .sel_i(1'b1),
        .wr_en_i(vram_wr),
        .wr_mask_i(vram_mask),
        .address_in_i(vram_address),
        .data_in_i(vram_data_in),
        .data_out_o(vram_data_out)
    );

    graphite graphite(
        .clk(clk),
        .reset_i(reset_i),
        .cmd_axis_tvalid_i(cmd_axis_tvalid_i),
        .cmd_axis_tready_o(cmd_axis_tready_o),
        .cmd_axis_tdata_i(cmd_axis_tdata_i),
        .vram_sel_o(graphite_vram_sel),
        .vram_wr_o(graphite_vram_wr),
        .vram_mask_o(graphite_vram_mask),
        .vram_addr_o(graphite_vram_address),
        .vram_data_in_i(vram_data_out),
        .vram_data_out_o(graphite_vram_data_out),
        .swap_o()
    );

`endif // GRAPHITE

`ifdef XOSERA

    xosera_main xosera(
        .bus_cs_n_i(xosera_bus_cs_n_i),           // register select strobe (active low)
        .bus_rd_nwr_i(xosera_bus_rd_nwr_i),       // 0 = write, 1 = read
        .bus_reg_num_i(xosera_bus_reg_num_i),     // register number
        .bus_bytesel_i(xosera_bus_bytesel_i),     // 0 = even byte, 1 = odd byte
        .bus_data_i(xosera_bus_data_i),           // 8-bit data bus input
        .bus_data_o(xosera_bus_data_o),           // 8-bit data bus output
        .bus_intr_o(),                            // Xosera CPU interrupt strobe
        .red_o(vga_r_o),                          // red color gun output
        .green_o(vga_g_o),                        // green color gun output
        .blue_o(vga_b_o),                         // blue color gun output
        .hsync_o(vga_hsync_o),
        .vsync_o(vga_vsync_o),                    // horizontal and vertical sync
        .dv_de_o(vga_de_o),                       // pixel visible (aka display enable)
        .audio_l_o(xosera_audio_l_o),
        .audio_r_o(xosera_audio_r_o),             // left and right audio PWM output
        .reconfig_o(),                            // reconfigure iCE40 from flash
        .boot_select_o(),                         // reconfigure congigureation number (0-3)
        .reset_i(reset_i),                        // reset signal
        .clk(clk)                                 // pixel clock        
    );

`endif // XOSERA

endmodule
