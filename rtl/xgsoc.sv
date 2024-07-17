// xgsoc.sv
// Copyright (c) 2022-2024 Daniel Cliche
// SPDX-License-Identifier: MIT

/*
    0x00000000 - 0x00001FFF: rom (8kB)
    0x10000000 - 0x1FFFFFFF: ram (max: 256MB)
    0x20000000 - 0x20000FFF: system
        0x20000000: timer interrupt enable
        0x20000004: clock value (ms)
    0x20001000 - 0x20001FFF: display
    0x20002000 - 0x20002FFF: UART (BAUDS-N-8-1)
        0x20002000: Data Register (8 bits)
        0x20002004: Status Register (Read-only)
            bit 0: busy
            bit 1: valid
    0x20003000 - 0x20003FFF: XGA
        0x20003000  // Xosera even byte
        0x20003100  // Xosera odd byte
    0x20004000 - 0x20004FFF: USB
        0x20004000: report valid
        0x20004004: 64-bit report MSW (32-bit)
        0x20004008: 64-bit report LSW (32-bit)
    0x20005000 - 0x20005FFF: PS/2 Keyboard and Mouse
        0x20005000: Keyboard status
            bit 0: strobe
            bit 1: error
        0x20005004: Keyboard code
        0x20005008: Mouse buttons
        0x2000500C: Mouse x
        0x20005010: Mouse y
    0x20006000 - 0x20006FFF: SD Card (SPI)
        0x20006000:
            Write:
                bit 0: mosi
                bit 1: cs
                bit 2: sclk
            Read:
                bit 0: miso
    0x20007000 - 0x20007FFF: Flash (SPI)
        0x20007000:
            Write:
                bit 0: mosi
                bit 1: cs
                bit 2: sclk
            Read:
                bit 0: miso
    0x30000000 - 0x33FFFFFF: VGA (128kB)
*/

`ifdef SDRAM
`define CPU_SDRAM
`endif

`ifdef XGA
`define VIDEO
`define AUDIO
`elsif VGA
`define VIDEO
`endif

module xgsoc #(
    parameter FREQ_HZ = 12 * 1000000,
    parameter BAUDS    = 115200,
    parameter ROM_SIZE = 8*1024,
    parameter RAM_SIZE = 128*1024,
    parameter SDRAM_CLK_FREQ_MHZ = 100
    ) (
    input  wire logic       clk,
    input  wire logic       clk_sdram,
`ifdef VIDEO    
    input  wire logic       clk_pix,
`endif
    input  wire logic       reset_i,
    output      logic [7:0] display_o,

    input  wire logic       rx_i,
    output      logic       tx_o,

`ifdef VIDEO
    output      logic       vga_hsync_o,
    output      logic       vga_vsync_o,
    output      logic [3:0] vga_r_o,
    output      logic [3:0] vga_g_o,
    output      logic [3:0] vga_b_o,
    output      logic       vga_de_o,
`endif
`ifdef AUDIO
    output      logic       audio_l_o,
    output      logic       audio_r_o,
`endif

`ifdef USB
    input  wire logic [63:0] usb_report_i,
    input  wire logic        usb_report_valid_i,
`endif

`ifdef PS2
    input  wire logic [7:0]  ps2_kbd_code_i,
    input  wire logic        ps2_kbd_strobe_i,
    input  wire logic        ps2_kbd_err_i,
    input  wire logic [2:0]  ps2_mouse_btn_i,
    input  wire logic [15:0] ps2_mouse_x_i,
    input  wire logic [15:0] ps2_mouse_y_i,
`endif

`ifdef SD_CARD
    output      logic        sd_csn_o,
    output      logic        sd_sclk_o,
    input  wire logic        sd_miso_i,
    output      logic        sd_mosi_o,
`endif

`ifdef FLASH
    output      logic        flash_csn_o,
    output      logic        flash_sclk_o,
    input  wire logic        flash_miso_i,
    output      logic        flash_mosi_o,
`endif

`ifdef SDRAM
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
`endif
    );

    localparam TIMER_FREQ_HZ = 1000;

    // interrupts (2)
    logic [1:0] irq;   // interrupt request
    logic [1:0] eoi;   // end of interrupt

    // bus
    logic        sel;
    logic [31:0] addr;
    logic        mem_we, cpu_we;
    logic [31:0] mem_data_in, cpu_data_in;
    logic [31:0] rom_data_out, ram_data_out, mem_data_out, cpu_data_out;
`ifdef VGA
    logic [31:0] vga_data_out;
`endif // VGA
    logic [3:0]  wr_mask;
    logic        rom_ack, ram_ack, device_ack;
`ifdef VGA
    logic        vga_ack;
`endif // VGA

    // display
    logic [7:0] display;
    logic display_we;

    //
    // UART
    //

    logic uart_tx_strobe;
    logic [7:0] uart_tx_data;
    logic [7:0] uart_rx_data;
    logic uart_busy, uart_valid;
    logic uart_wr;

    logic uart_enq;
    logic uart_deq;
    logic uart_fifo_empty;

    fifo #(
        .ADDR_LEN(10),
        .DATA_WIDTH(8)
    ) uart_fifo(
        .clk(clk),
        .reset_i(reset_i),
        .reader_q_o(uart_code),
        .reader_deq_i(uart_deq),
        .reader_empty_o(uart_fifo_empty),
        .reader_alm_empty_o(),

        .writer_d_i(uart_rx_data),
        .writer_enq_i(uart_enq),
        .writer_full_o(),
        .writer_alm_full_o()
    );
    
    uart #(
        .FREQ_HZ(FREQ_HZ),
        .BAUDS(BAUDS)
    ) uart(
        .clk(clk),
        .reset_i(reset_i),
        .tx_o(tx_o),
        .rx_i(rx_i),
        .wr_i(uart_wr),
        .rd_i(1'b1),
        .tx_data_i(uart_tx_data),
        .rx_data_o(uart_rx_data),
        .busy_o(uart_busy),
        .valid_o(uart_valid)
    );

    logic       uart_req_deq;
    logic [7:0] uart_code, uart_code_r;
    always_ff @(posedge clk) begin
        if (reset_i) begin
            uart_enq     <= 1'b0;
            uart_deq     <= 1'b0;
            uart_tx_data <= 8'd0;
            uart_wr      <= 1'b0;
        end begin
            uart_enq <= 1'b0;
            if (uart_deq) begin
                uart_deq <= 1'b0;
                uart_code_r <= uart_code; 
            end
            if (uart_req_deq) begin
                if (!uart_fifo_empty) begin
                    uart_deq <= 1'b1;
                end
            end
            if (uart_valid) begin
                uart_enq <= 1'b1;
            end
        end

        if (uart_tx_strobe) begin
            uart_tx_data <= cpu_data_out[7:0];
            uart_wr <= 1'b1;
        end else begin
            uart_wr <= 1'b0;
        end


    end

`ifdef XGA

    logic         xga_we;

    // Xosera
    logic         xosera_bus_cs_n, xosera_bus_cs_n_r;           // register select strobe (active low)
    logic         xosera_bus_rd_nwr, xosera_bus_rd_nwr_r;         // 0 = write, 1 = read
    logic [3:0]   xosera_bus_reg_num, xosera_bus_reg_num_r;        // register number
    logic         xosera_bus_bytesel, xosera_bus_bytesel_r;        // 0 = even byte, 1 = odd byte
    logic [7:0]   xosera_bus_data_in, xosera_bus_data_in_r;        // 8-bit data bus input
    logic [7:0]   xosera_bus_data_out;       // 8-bit data bus output    
    logic         xosera_bus_intr;
    logic         xosera_ack;
    logic [1:0]   xosera_state;


    logic stream_err_underflow;

    always_ff @(posedge clk) begin
        if (reset_i) begin
            xosera_bus_cs_n_r <= 1'b1;
            xosera_ack <= 1'b0;
            xosera_state <= 0;
        end else begin
            case (xosera_state)
                0: begin
                    if (sel && !xosera_bus_cs_n) begin
                        xosera_bus_rd_nwr_r <= xosera_bus_rd_nwr;
                        xosera_bus_reg_num_r <= xosera_bus_reg_num;
                        xosera_bus_bytesel_r <= xosera_bus_bytesel;
                        xosera_bus_data_in_r <= xosera_bus_data_in;
                        xosera_state <= 1;
                    end
                end
                1: begin
                    xosera_bus_cs_n_r <= 1'b0;
                    xosera_state <= 2;
                end
                2: begin
                    xosera_ack <= 1'b1;
                    xosera_state <= 3;
                end
                3: begin
                    // wait deselect
                    xosera_bus_cs_n_r <= 1'b1;
                    xosera_ack <= 1'b0;
                    if (!sel)
                        xosera_state <= 0;
                end
            endcase
           
        end
    end

`endif

`ifdef PS2

    logic ps2_kbd_enq;
    logic ps2_kbd_deq;
    logic ps2_kbd_fifo_empty, ps2_kbd_fifo_full;

    fifo #(
        .ADDR_LEN(5),
        .DATA_WIDTH(8)
    ) ps2_kbd_fifo(
        .clk(clk),
        .reset_i(reset_i),
        .reader_q_o(ps2_kbd_code),
        .reader_deq_i(ps2_kbd_deq),
        .reader_empty_o(ps2_kbd_fifo_empty),
        .reader_alm_empty_o(),

        .writer_d_i(ps2_kbd_code_i),
        .writer_enq_i(ps2_kbd_enq),
        .writer_full_o(ps2_kbd_fifo_full),
        .writer_alm_full_o()
    );

    logic       ps2_kbd_req_deq;
    logic [7:0] ps2_kbd_code, ps2_kbd_code_r;
    always_ff @(posedge clk) begin
        if (reset_i) begin
            ps2_kbd_enq <= 1'b0;
            ps2_kbd_deq <= 1'b0;
        end begin
            ps2_kbd_enq <= 1'b0;
            if (ps2_kbd_deq) begin
                ps2_kbd_deq <= 1'b0;
                ps2_kbd_code_r <= ps2_kbd_code; 
            end
            if (ps2_kbd_req_deq) begin
                if (!ps2_kbd_fifo_empty) begin
                    ps2_kbd_deq <= 1'b1;
                end
            end
            if (ps2_kbd_strobe_i) begin
                if (!ps2_kbd_fifo_full) begin
                    ps2_kbd_enq <= 1'b1;
                end
            end
        end
    end
`endif

`ifdef SD_CARD
    logic sd_card_we;
    always @(posedge clk) begin     
        if (reset_i) begin
            {sd_sclk_o, sd_csn_o, sd_mosi_o} <= 3'b010;
        end else begin
            if (sd_card_we)
                {sd_sclk_o, sd_csn_o, sd_mosi_o} <= {cpu_data_out[2], ~cpu_data_out[1], cpu_data_out[0]};
        end
    end
`endif

`ifdef FLASH
    logic flash_we;
    always @(posedge clk) begin     
        if (reset_i) begin
            {flash_sclk_o, flash_csn_o, flash_mosi_o} <= 3'b010;
        end else begin
            if (flash_we)
                {flash_sclk_o, flash_csn_o, flash_mosi_o} <= {cpu_data_out[2], ~cpu_data_out[1], cpu_data_out[0]};
        end
    end
`endif

    bram #(
        .SIZE(ROM_SIZE/4),
        .INIT_FILE("firmware.hex")
    ) rom(
        .clk(clk),
        .sel_i(sel && (addr[31:28] == 4'h0)),
        .wr_en_i(1'b0),
        .wr_mask_i(wr_mask),
        .address_in_i(32'(addr[27:0] >> 2)),
        .data_in_i(mem_data_in), 
        .data_out_o(rom_data_out),
        .ack_o(rom_ack)
    );

`ifdef SPRAM
    spram #(
        .SIM_INIT_FILE("program.hex")
    ) ram(
        .clk(clk),
        .sel_i(sel && (addr[31:28] == 4'h1)),
        .address_in_i(15'(addr[27:0] >> 2)),
        .wr_en_i(mem_we),
        .wr_mask_i(wr_mask),
        .data_in_i(mem_data_in), 
        .data_out_o(ram_data_out),
        .ack_o(ram_ack)
    );
`else


`ifndef CPU_SDRAM

    bram #(.SIZE(RAM_SIZE/4)
`ifndef SYNTHESIS
        ,.INIT_FILE("program.hex")
`endif
        ) ram(
        .clk(clk),
        .sel_i(sel && (addr[31:28] == 4'h1)),
        .address_in_i(32'(addr[27:0] >> 2)),
        .wr_en_i(mem_we),
        .wr_mask_i(wr_mask),
        .data_in_i(mem_data_in), 
        .data_out_o(ram_data_out),
        .ack_o(ram_ack)
    );

`else
    sdram ram(
        .clk(clk),
        .reset_i(reset_i),
        .sel_i(sel && (addr[31:28] == 4'h1)),
        .address_in_i(32'(addr[27:0] >> 2)),
        .wr_en_i(mem_we),
        .wr_mask_i(wr_mask),
        .data_in_i(mem_data_in), 
        .data_out_o(ram_data_out),
        .ack_o(ram_ack),

        // SDRAM interface
        .sdram_clk(clk_sdram),
        .ba_o(sdram_ba_o),
        .a_o(sdram_a_o),
        .cs_n_o(sdram_cs_n_o),
        .ras_n_o(sdram_ras_n_o),
        .cas_n_o(sdram_cas_n_o),
        .we_n_o(sdram_we_n_o),
        .dq_io(sdram_dq_io),
        .dqm_o(sdram_dqm_o),
        .cke_o(sdram_cke_o),
        .sdram_clk_o(sdram_clk_o)
    );

`endif // CPU_SDRAM

`endif

    always_ff @(posedge clk) begin
        if (reset_i) begin
            device_ack <= 1'b0;
        end else begin
            device_ack <= 1'b0;
            if (sel) begin
                if ((addr[31:28] == 4'h2) && (addr[31:8] != 24'h200030) && (addr[31:8] != 24'h200031))
                    device_ack <= 1'b1;
            end
        end
    end

    // timer
    logic [31:0] timer_value;
    logic [31:0] clock_value;
    logic timer_intr_ena_we;
    logic timer_intr_ena;
    logic timer_irq;
    logic timer_wait_irq_handling;
    always_ff @(posedge clk) begin
        if (reset_i) begin
            timer_value <= FREQ_HZ / TIMER_FREQ_HZ - 1;
            clock_value <= 32'd0;
            timer_intr_ena <= 1'b0;
            timer_irq <= 1'b0;
            timer_wait_irq_handling <= 1'b0;
        end else begin
            if (timer_intr_ena_we)
                timer_intr_ena <= cpu_data_out[0];
            if (timer_wait_irq_handling) begin
                if (!eoi[0])
                    timer_wait_irq_handling <= 1'b0;
            end else if (timer_irq && eoi[0]) begin
                timer_irq <= 1'b0;
                //$display("Timer interrupt released");
            end
            timer_value <= timer_value - 1;
            if (timer_value == 32'd0) begin
                clock_value <= clock_value + 1;
                if (timer_intr_ena) begin
                    if (!timer_wait_irq_handling && eoi[0]) begin
                        //$display("Timer interrupt");
                        timer_irq <= 1'b1;
                        timer_wait_irq_handling <= 1'b1;
                    end else begin
`ifndef SYNTHESIS                        
                        $display("Timer interrupt lost");
`endif
                    end
                end
                timer_value <= FREQ_HZ / TIMER_FREQ_HZ - 1;
            end
        end
    end

`ifdef XGA
    logic xosera_irq;
    logic xosera_wait_irq_handling;
    always_ff @(posedge clk) begin
        if (reset_i) begin
            xosera_irq <= 1'b0;
            xosera_wait_irq_handling <= 1'b0;
        end else begin
            if (xosera_wait_irq_handling) begin
                if (!eoi[1])
                    xosera_wait_irq_handling <= 1'b0;
            end else if (xosera_irq && eoi[1]) begin
                xosera_irq <= 1'b0;
                //$display("Xosera interrupt released");
            end            
            if (xosera_bus_intr) begin
                if (!xosera_wait_irq_handling && eoi[1]) begin
                    //$display("Xosera interrupt");
                    xosera_irq <= 1'b1;
                    xosera_wait_irq_handling <= 1'b1;
                end else begin
`ifndef SYNTHESIS                    
                    $display("Xosera interrupt lost");
`endif
                end
            end
        end
    end

`endif

    always_comb irq = { 
`ifdef XGA
    xosera_irq,
`else
    1'b0,
`endif
    timer_irq};

    processor #(
        .IRQ_VEC_ADDR(32'h10000010)   // IRQ vector in RAM
    ) cpu(
        .clk(clk),
        .reset_i(reset_i),
        .ce_i(1'b1),
        .irq_i(irq),
        .eoi_o(eoi),
        .sel_o(sel),
        .addr_o(addr),
        .we_o(cpu_we),
        .data_in_i(cpu_data_in),
        .data_out_o(cpu_data_out),
        .wr_mask_o(wr_mask),
        .ack_i(rom_ack || ram_ack || device_ack
`ifdef XGA
        || xosera_ack
`endif
`ifdef VGA
        || vga_ack
`endif
        )
    );

    always_comb begin
        case (addr[31:28])
            4'h1:
                mem_data_out = ram_data_out;
`ifdef VGA
            4'h3:
                mem_data_out = vga_data_out;
`endif // VGA
            default:
                mem_data_out = rom_data_out;
        endcase
    end

`ifdef VGA
    vga vga(
        .clk(clk_pix),
        .reset_i(reset_i),
        .sel_i(sel && (addr[31:28] == 4'h3)),
        .address_in_i(16'(addr[27:0] >> 2)),
        .wr_en_i(mem_we),
        .wr_mask_i(wr_mask),
        .data_in_i(mem_data_in), 
        .data_out_o(vga_data_out),
        .ack_o(vga_ack),
        .vga_hsync_o(vga_hsync_o),
        .vga_vsync_o(vga_vsync_o),
        .vga_r_o(vga_r_o),
        .vga_g_o(vga_g_o),
        .vga_b_o(vga_b_o),
        .vga_de_o(vga_de_o)
    );
`endif

`ifdef XGA    
    xga xga(
        .clk(clk_pix),
        .reset_i(reset_i),

        .xosera_bus_cs_n_i(xosera_bus_cs_n_r),
        .xosera_bus_rd_nwr_i(xosera_bus_rd_nwr_r),
        .xosera_bus_reg_num_i(xosera_bus_reg_num_r),
        .xosera_bus_bytesel_i(xosera_bus_bytesel_r),
        .xosera_bus_data_i(xosera_bus_data_in_r),
        .xosera_bus_data_o(xosera_bus_data_out),
        .xosera_bus_intr_o(xosera_bus_intr),
        .xosera_audio_l_o(audio_l_o),
        .xosera_audio_r_o(audio_r_o),

        .vga_hsync_o(vga_hsync_o),
        .vga_vsync_o(vga_vsync_o),
        .vga_r_o(vga_r_o),
        .vga_g_o(vga_g_o),
        .vga_b_o(vga_b_o),
        .vga_de_o(vga_de_o)
    );
`endif

    // address decoding
    always_comb begin
        mem_we = 1'b0;
        timer_intr_ena_we = 1'b0;
        display_we = 1'b0;
        mem_data_in = cpu_data_out;
        display = 8'd0;
        cpu_data_in = mem_data_out;
        uart_tx_strobe = 1'b0;
        uart_req_deq = 1'b0;
`ifdef XGA
        xga_we = 1'b0;
        xosera_bus_cs_n = 1'b1;
        xosera_bus_rd_nwr = 1'b1;
        xosera_bus_data_in = cpu_data_out[7:0];
        xosera_bus_bytesel = addr[8];
        xosera_bus_reg_num = addr[7:4];
`endif
`ifdef PS2
        ps2_kbd_req_deq = 1'b0;
`endif
`ifdef SD_CARD
        sd_card_we = 1'b0;
`endif
`ifdef FLASH
        flash_we = 1'b0;
`endif
        if (cpu_we) begin
            // write
            if (addr[31:28] == 4'h2) begin
                if (!device_ack) begin
                    // peripheral
                    case (addr[15:12])
                        4'h0: begin
                            // system
                            if (addr[11:0] == 12'd0)
                                timer_intr_ena_we = 1'b1;
                        end
                        4'h1: begin
                            // display
                            display_we = 1'b1;
                        end
                        4'h2: begin
                            // UART
                            if (addr[11:0] == 12'd0) begin
                                // data
                                uart_tx_strobe = 1'b1;
                            end else if (addr[11:0] == 12'd4) begin
                                if (!uart_fifo_empty)
                                    uart_req_deq = 1'b1;
                            end
                        end
    `ifdef XGA
                        4'h3: begin
                            // XGA
                            if (addr[11] == 1'b0) begin
                                if (addr[10] == 1'b0) begin
                                    // xosera
                                    xosera_bus_rd_nwr = 1'b0;
                                    xosera_bus_cs_n = 1'b0;
                                end
                            end else begin
                                xga_we = 1'b1;
                            end
                        end
    `endif
    `ifdef PS2
                        4'h5: begin
                            // PS/2 Keyboard
                            if (addr[11:0] == 12'd0) begin
                                if (!ps2_kbd_fifo_empty)
                                    ps2_kbd_req_deq = 1'b1;
                            end
                        end
    `endif // PS2
    `ifdef SD_CARD
                        4'h6: begin
                            // SD Card
                            if (addr[11:0] == 12'd0) begin
                                sd_card_we = 1'b1;
                            end
                        end
    `endif
    `ifdef FLASH
                        4'h7: begin
                            // Flash
                            if (addr[11:0] == 12'd0) begin
                                flash_we = 1'b1;
                            end
                        end
    `endif
                    endcase
                end
            end else begin
                // memory
                mem_we = 1'b1;
            end
        end else begin
            // read
            if (addr[31:28] == 4'h2) begin
                // peripheral
                case (addr[15:12])
                    4'h0: begin
                        if (addr[11:0] == 12'd0) begin
                            cpu_data_in = {31'd0, timer_intr_ena};
                        end else if (addr[11:0] == 12'd4) begin
                            cpu_data_in = clock_value;
                        end
                    end

                    4'h1: begin
                        cpu_data_in = {24'd0, display_o};
                    end

                    4'h2: begin
                        // UART
                        if (addr[11:0] == 12'd0) begin
                            // data
                            cpu_data_in = {24'd0, uart_code_r};
                        end else if (addr[11:0] == 12'd4) begin
                            // status
                            cpu_data_in = {30'd0, ~uart_fifo_empty, uart_busy};
                        end
                    end
`ifdef XGA                    
                    4'h3: begin
                        // XGA
                        if (addr[11] == 1'b0) begin
                            if (addr[10] == 1'b0) begin
                                // xosera
                                xosera_bus_cs_n = 1'b0;
                                cpu_data_in = {24'd0, xosera_bus_data_out};
                            end
                        end
                    end
`endif                    
`ifdef USB
                    4'h4: begin
                        // USB
                        if (addr[11:0] == 12'd0) begin
                            // report valid
                            cpu_data_in = {31'd0, usb_report_valid_i};
                        end else if (addr[11:0] == 12'd4) begin
                            // report MSW
                            cpu_data_in = usb_report_i[63:32];
                        end else if (addr[11:0] == 12'd8) begin
                            // report LSW
                            cpu_data_in = usb_report_i[31:0];
                        end
                    end
`endif // USB
`ifdef PS2
                    4'h5: begin
                        // PS/2 keyboard and mouse
                        if (addr[11:0] == 12'd0) begin
                            // keyboard status
                            cpu_data_in = {31'd0, ~ps2_kbd_fifo_empty};
                        end else if (addr[11:0] == 12'd4) begin
                            // keyboard code
                            cpu_data_in = {24'd0, ps2_kbd_code_r};
                        end else if (addr[11:0] == 12'd8) begin
                            // mouse buttons
                            cpu_data_in = {29'd0, ps2_mouse_btn_i};
                        end else if (addr[11:0] == 12'd12) begin
                            // mouse x
                            cpu_data_in = {16'd0, ps2_mouse_x_i};
                        end else if (addr[11:0] == 12'd16) begin
                            // mouse y
                            cpu_data_in = {16'd0, ps2_mouse_y_i};
                        end
                    end
`endif // PS2
`ifdef SD_CARD
                    4'h6: begin
                        // SD Card
                        if (addr[11:0] == 12'd0) begin
                            cpu_data_in = {31'd0, sd_miso_i};
                        end
                    end

`endif // SD_CARD
`ifdef FLASH
                    4'h7: begin
                        // Flash
                        if (addr[11:0] == 12'd0) begin
                            cpu_data_in = {31'd0, flash_miso_i};
                        end
                    end
`endif // FLASH
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (reset_i) begin
            display_o <= 8'd0;
        end else begin
            if (display_we)
                display_o <= cpu_data_out[7:0];
        end
    end

endmodule