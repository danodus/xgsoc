// CPU register interface with PHY+SIE. Modelled after the registers of the
// ultra-embedded usb host example: https://github.com/ultraembedded/core_usb_host
//
// The CPU port stays on clk_cpu. The PHY, SIE, SOF timer and the USB side of
// the data FIFOs run on clk_usb (60 MHz).

`default_nettype none

module REGS (
  input          clk_cpu,
  input          clk_usb,
  input          rst_i,
  input          rst_usb_i,
  output [7:0]   led_o,

  // CPU memory interface (clk_cpu)
  input           m_sel,
  input   [3:0]   m_addr,
  input  [31:0]   m_data_i,
  output [31:0]   m_data_o,
  input           m_rd,
  input           m_wr,
  output          m_intr_o,

  // UTMI+ level 3 PHY interface (clk_usb)
  input  [7:0]   utmi_data_in_i,
  input          utmi_rxvalid_i,
  input          utmi_rxactive_i,
  input          utmi_rxerror_i,

  output [7:0]   utmi_data_out_o,
  output         utmi_txvalid_o,
  input          utmi_txready_i,

  output [1:0]   utmi_op_mode_o,
  output [1:0]   utmi_xcvrselect_o,
  output         utmi_termselect_o,
  output         utmi_dppulldown_o,
  output         utmi_dmpulldown_o,
  input  [1:0]   utmi_linestate_i
  );

  wire reg_wr = m_wr & m_sel;
  wire reg_rd = m_rd & m_sel;

  wire irq_done, irq_sof, irq_err, irq_det;

  //-----------------------------------------------------------------
  // CPU-visible copies. Reads complete in the CPU clock domain.
  //-----------------------------------------------------------------

  reg  [ 8:0] reg_ctrl_cpu;
  reg  [ 3:0] reg_irq;
  reg  [ 3:0] reg_irq_mask;
  reg  [15:0] reg_tx_len_cpu;
  reg  [31:0] reg_tx_token_cpu;

  wire        token_ack_cpu;
  wire        irq_sof_cpu, irq_done_cpu, irq_err_cpu, irq_det_cpu;
  wire [31:0] stat_cpu;
  wire [31:0] rx_stat_cpu;
  wire [7:0]  rx_data;

  reg [3:0] irq_next;
  always @(*) begin
    irq_next = reg_irq;
    if (reg_wr && (m_addr == 4'd2))
      irq_next = reg_irq & ~m_data_i[3:0];
    if (irq_sof_cpu)  irq_next[0] = 1'b1;
    if (irq_done_cpu) irq_next[1] = 1'b1;
    if (irq_err_cpu)  irq_next[2] = 1'b1;
    if (irq_det_cpu)  irq_next[3] = 1'b1;
  end

  always @(posedge clk_cpu or posedge rst_i) begin
    if (rst_i) begin
      reg_ctrl_cpu     <=  9'h0;
      reg_irq          <=  4'h0;
      reg_irq_mask     <=  4'h0;
      reg_tx_len_cpu   <= 16'h0;
      reg_tx_token_cpu <= 32'h0;
    end else begin
      reg_irq <= irq_next;
      if (reg_wr && (m_addr == 4'd0))
        reg_ctrl_cpu <= m_data_i[8:0];
      if (reg_wr && (m_addr == 4'd4))
        reg_irq_mask <= m_data_i[3:0];
      if (reg_wr && (m_addr == 4'd5))
        reg_tx_len_cpu <= m_data_i[15:0];
      if (reg_wr && (m_addr == 4'd6))
        reg_tx_token_cpu <= m_data_i;
      else if (token_ack_cpu)
        reg_tx_token_cpu[31] <= 1'b0;
    end
  end

  assign m_data_o = (m_addr==4'd0) ? { 23'h0, reg_ctrl_cpu } :
                    (m_addr==4'd1) ? stat_cpu               :
                    (m_addr==4'd3) ? { 28'h0, reg_irq }     :
                    (m_addr==4'd4) ? { 28'h0, reg_irq_mask } :
                    (m_addr==4'd5) ? { 16'h0, reg_tx_len_cpu } :
                    (m_addr==4'd6) ? reg_tx_token_cpu        :
                    (m_addr==4'd7) ? rx_stat_cpu             :
                    (m_addr==4'd8) ? { 24'h0, rx_data }      : 32'h0;

  assign m_intr_o = |(reg_irq & reg_irq_mask);

  //-----------------------------------------------------------------
  // Register writes cross into the USB domain one word at a time.
  // The queue absorbs back-to-back stores; the toggle handshake moves
  // a stable word. Address 8 is the data FIFO, not a register write.
  //-----------------------------------------------------------------

  wire cmd_push = reg_wr && (m_addr==4'd0 || m_addr==4'd2 || m_addr==4'd5 || m_addr==4'd6);
  wire [35:0] cmd_push_data = {m_addr, m_data_i};

  reg [35:0] cmd_q [0:7];
  reg [2:0]  cmd_wptr, cmd_rptr;
  reg [3:0]  cmd_count;
  wire       cmd_empty = (cmd_count == 4'd0);
  wire       cmd_full  = (cmd_count == 4'd8);

  reg        req_toggle;
  reg        req_busy;
  reg [35:0] req_data;
  reg        ack_toggle;
  (* async_reg *) reg [2:0] ack_sync;

  wire ack_edge = ack_sync[2] ^ ack_sync[1];
  wire launch   = !cmd_empty && (!req_busy || ack_edge);

  always @(posedge clk_cpu or posedge rst_i) begin
    if (rst_i) begin
      cmd_wptr   <= 3'd0;
      cmd_rptr   <= 3'd0;
      cmd_count  <= 4'd0;
      req_toggle <= 1'b0;
      req_busy   <= 1'b0;
      req_data   <= 36'h0;
      ack_sync   <= 3'b0;
    end else begin
      ack_sync <= {ack_sync[1:0], ack_toggle};

      if (launch) begin
        req_data   <= cmd_q[cmd_rptr];
        req_toggle <= ~req_toggle;
        req_busy   <= 1'b1;
      end else if (req_busy && ack_edge)
        req_busy <= 1'b0;

      if (cmd_push && !cmd_full && launch) begin
        cmd_q[cmd_wptr] <= cmd_push_data;
        cmd_wptr <= cmd_wptr + 3'd1;
        cmd_rptr <= cmd_rptr + 3'd1;
      end else if (cmd_push && !cmd_full) begin
        cmd_q[cmd_wptr] <= cmd_push_data;
        cmd_wptr  <= cmd_wptr + 3'd1;
        cmd_count <= cmd_count + 4'd1;
      end else if (launch) begin
        cmd_rptr  <= cmd_rptr + 3'd1;
        cmd_count <= cmd_count - 4'd1;
      end
    end
  end

  // Hold TX-FIFO reset across the pointer synchronizers. Software asserts
  // the flush bit on its own, then fills the FIFO later.
  reg [3:0] tx_flush_cnt;
  wire tx_flush_pulse = reg_wr && (m_addr==4'd0) && m_data_i[8];
  always @(posedge clk_cpu or posedge rst_i) begin
    if (rst_i)
      tx_flush_cnt <= 4'd0;
    else if (tx_flush_pulse)
      tx_flush_cnt <= 4'd8;
    else if (tx_flush_cnt != 4'd0)
      tx_flush_cnt <= tx_flush_cnt - 4'd1;
  end
  wire tx_flush_cpu = tx_flush_pulse | (tx_flush_cnt != 4'd0);

  (* async_reg *) reg [2:0] req_sync;
  wire cmd_stb = req_sync[2] ^ req_sync[1];

  //-----------------------------------------------------------------
  // USB-domain control registers
  //-----------------------------------------------------------------

  reg  [ 8:0] reg_ctrl;
  reg  [15:0] reg_tx_len;
  reg  [31:0] reg_tx_token;
  reg         token_ack_usb;

  wire [31:0] rx_stat_w;
  wire        start_ack;
  wire        crc_err, timeout, sie_idle;

  always @(posedge clk_usb or posedge rst_usb_i) begin
    if (rst_usb_i) begin
      req_sync      <= 3'b0;
      ack_toggle    <= 1'b0;
      reg_ctrl      <= 9'h0;
      reg_tx_len    <= 16'h0;
      reg_tx_token  <= 32'h0;
      token_ack_usb <= 1'b0;
    end else begin
      req_sync <= {req_sync[1:0], req_toggle};
      token_ack_usb <= 1'b0;
      if (cmd_stb) begin
        ack_toggle <= ~ack_toggle;
        case (req_data[35:32])
          4'd0: reg_ctrl     <= req_data[8:0];
          4'd5: reg_tx_len   <= req_data[15:0];
          4'd6: reg_tx_token <= req_data[31:0];
          default: ;
        endcase
      end else if (start_ack && !send_sof) begin
        reg_tx_token[31] <= 1'b0;
        token_ack_usb    <= 1'b1;
      end
    end
  end

  pulse_sync token_ack_sync (
    .src_clk(clk_usb),
    .src_rst(rst_usb_i),
    .src_pulse(token_ack_usb),
    .dst_clk(clk_cpu),
    .dst_rst(rst_i),
    .dst_pulse(token_ack_cpu)
  );

  assign utmi_op_mode_o    = reg_ctrl[2:1];
  assign utmi_xcvrselect_o = reg_ctrl[4:3];
  assign utmi_termselect_o = reg_ctrl[5];
  assign utmi_dppulldown_o = reg_ctrl[6];
  assign utmi_dmpulldown_o = reg_ctrl[7];

  //-----------------------------------------------------------------
  // SIE + data FIFOs
  //-----------------------------------------------------------------

  wire [3:0] dump;
  assign led_o[7:4] = rx_stat_w[31:28];

  wire [7:0] sie_tx_data, sie_rx_data;
  wire       sie_tx_pop,  sie_rx_push;
  wire       tx_done, rx_done;

  localparam PID_SOF = 8'hA5;

  wire [7:0] token_pid = send_sof ? PID_SOF         : reg_tx_token[23:16];
  wire [6:0] token_dev = send_sof ? sof_frame[6:0]  : reg_tx_token[15: 9];
  wire [3:0] token_ep  = send_sof ? sof_frame[10:7] : reg_tx_token[ 8: 5];

  SIE u_sie (
    .clk_i(clk_usb),
    .rst_i(rst_usb_i),
    .led_o({dump, led_o[3:0]}),

    .start_i         (start_req),
    .in_transfer_i   (in_transfer),
    .sof_transfer_i  (send_sof),
    .resp_expected_i (resp_expected),
    .ack_o           (start_ack),

    .token_pid_i (token_pid),
    .token_dev_i (token_dev),
    .token_ep_i  (token_ep),
    .data_len_i  (reg_tx_len),
    .data_idx_i  (reg_tx_token[28]),

    .tx_data_i   (sie_tx_data),
    .tx_pop_o    (sie_tx_pop),
    .rx_data_o   (sie_rx_data),
    .rx_push_o   (sie_rx_push),

    .rx_done_o   (rx_done),
    .tx_done_o   (tx_done),
    .crc_err_o   (crc_err),
    .timeout_o   (timeout),
    .response_o  (rx_stat_w[23:16]),
    .rx_count_o  (rx_stat_w[15: 0]),
    .idle_o      (sie_idle),

    .utmi_xcvrselect_i (utmi_xcvrselect_o),
    .utmi_data_o       (utmi_data_out_o),
    .utmi_txvalid_o    (utmi_txvalid_o),
    .utmi_txready_i    (utmi_txready_i),
    .utmi_data_i       (utmi_data_in_i),
    .utmi_rxvalid_i    (utmi_rxvalid_i),
    .utmi_rxactive_i   (utmi_rxactive_i),
    .utmi_rxerror_i    (utmi_rxerror_i)
  );

  wire tx_sts30 = crc_err  & ~reg_tx_token[31];
  wire tx_sts29 = timeout  & ~reg_tx_token[31];
  wire tx_sts28 = sie_idle & ~reg_tx_token[31];
  assign rx_stat_w[31:24] = { start_req, tx_sts30, tx_sts29, tx_sts28, 4'b0 };

  wire tx_flush_usb;
  level_sync tx_flush_sync (
    .dst_clk(clk_usb),
    .dst_rst(rst_usb_i),
    .src_level(tx_flush_cpu),
    .dst_level(tx_flush_usb)
  );

  wire rx_flush_cpu;
  AFIFO #(.DW(8), .AW(6)) fifo_tx (
    .wr_clk   (clk_cpu),
    .wr_rst   (rst_i),
    .wr_flush (tx_flush_cpu),
    .wr_data  (m_data_i[7:0]),
    .wr_push  ((m_addr==4'h8) && reg_wr),
    .wr_full  (),

    .rd_clk   (clk_usb),
    .rd_rst   (rst_usb_i),
    .rd_flush (tx_flush_usb),
    .rd_data  (sie_tx_data),
    .rd_pop   (sie_tx_pop),
    .rd_empty ()
  );

  AFIFO #(.DW(8), .AW(6)) fifo_rx (
    .wr_clk   (clk_usb),
    .wr_rst   (rst_usb_i),
    .wr_flush (rx_flush_hold),
    .wr_data  (sie_rx_data),
    .wr_push  (sie_rx_push),
    .wr_full  (),

    .rd_clk   (clk_cpu),
    .rd_rst   (rst_i),
    .rd_flush (rx_flush_cpu),
    .rd_data  (rx_data),
    .rd_pop   ((m_addr==4'h8) && reg_rd),
    .rd_empty ()
  );

  //-----------------------------------------------------------------
  // SOF timer, frame counter. 60 MHz: 60000 clocks per millisecond.
  // Guard points are the 48 MHz counts scaled by 60/48.
  //-----------------------------------------------------------------

  localparam SOF_GUARD_LOW   =    16'd200;   // was 160
  localparam SOF_GUARD_HIGH  = 16'd51_250;   // was 41000
  localparam SOF_THRESHOLD   = 16'd59_999;   // 1 ms - 1 clock

  wire sof_enable   = reg_ctrl[0];
  wire tx_sof       = (sof_timer == SOF_THRESHOLD) & sof_enable & sie_idle;
  wire in_guardband = (sof_timer <= SOF_GUARD_LOW || sof_timer >= SOF_GUARD_HIGH);

  reg [15:0] sof_timer;
  reg [10:0] sof_frame;
  reg        sof_irq;

  always @(posedge clk_usb or posedge rst_usb_i) begin
    sof_irq <= 1'b0;
    if (rst_usb_i) begin
      sof_frame <= 11'd0;
      sof_timer <= 16'd0;
    end else if (tx_sof) begin
      sof_timer <= 16'd0;
      sof_frame <= sof_frame + 11'd1;
      sof_irq   <= 1'b1;
    end else if (sof_timer != SOF_THRESHOLD)
      sof_timer <= sof_timer + 16'd1;
  end

  //-----------------------------------------------------------------
  // SIE transaction controller
  //-----------------------------------------------------------------

  reg  rx_flush, start_req, send_sof, in_transfer, resp_expected;
  wire can_send = ~(in_guardband & sof_enable) & sie_idle;

  always @(posedge clk_usb or posedge rst_usb_i) begin
    if (rst_usb_i) begin
      rx_flush      <= 1'b0;
      in_transfer   <= 1'b0;
      resp_expected <= 1'b0;
      send_sof      <= 1'b0;
      start_req     <= 1'b0;
    end else begin
      if (start_req) begin
        if (start_ack) start_req <= 1'b0;
        rx_flush <= 1'b0;
      end else if (tx_sof) begin
        in_transfer   <= 1'b0;
        resp_expected <= 1'b0;
        send_sof      <= 1'b1;
        start_req     <= 1'b1;
      end else if (can_send & reg_tx_token[31]) begin
        rx_flush      <= 1'b1;
        in_transfer   <= reg_tx_token[30];
        resp_expected <= reg_tx_token[29];
        send_sof      <= 1'b0;
        start_req     <= 1'b1;
      end
    end
  end

  // rx_flush is one USB clock. Stretch it so the CPU-side read pointer
  // resets before any byte of the new transfer is pushed (~267 ns).
  reg [4:0] rx_flush_cnt;
  always @(posedge clk_usb or posedge rst_usb_i) begin
    if (rst_usb_i)
      rx_flush_cnt <= 5'd0;
    else if (rx_flush)
      rx_flush_cnt <= 5'd16;
    else if (rx_flush_cnt != 5'd0)
      rx_flush_cnt <= rx_flush_cnt - 5'd1;
  end
  wire rx_flush_hold = rx_flush | (rx_flush_cnt != 5'd0);

  level_sync rx_flush_sync (
    .dst_clk(clk_cpu),
    .dst_rst(rst_i),
    .src_level(rx_flush_hold),
    .dst_level(rx_flush_cpu)
  );

  //-----------------------------------------------------------------
  // Status and interrupts back to the CPU
  //-----------------------------------------------------------------

`ifdef __ICARUS__
  localparam SPEED = 8;
`else
  localparam SPEED = 22;
`endif

  reg [SPEED:0] dt_ctr;
  wire          dt_up   = (dt_ctr[SPEED:SPEED-1] == 2'b11);
  wire          dt_down = (dt_ctr[SPEED:SPEED-1] == 2'b00);

  reg phy_err, sie_err, detect;

  always @(posedge clk_usb or posedge rst_usb_i) begin
    if (rst_usb_i) begin
      phy_err <= 1'b0;
      sie_err <= 1'b0;
      detect  <= 1'b0;
      dt_ctr  <= 'd0;
    end else begin
      if (cmd_stb && (req_data[35:32] == 4'd0))
        phy_err <= 1'b0;
      else if (utmi_rxerror_i)
        phy_err <= 1'b1;

      if (crc_err | timeout)
        sie_err <= 1'b1;
      else if (cmd_stb && (req_data[35:32] == 4'd2) && req_data[2])
        sie_err <= 1'b0;

      if (utmi_linestate_i != 2'b0 && !(&dt_ctr))
        dt_ctr <= dt_ctr + 1'b1;
      else if (utmi_linestate_i == 2'b0 && |dt_ctr)
        dt_ctr <= dt_ctr - 1'b1;
      if (dt_up)
        detect <= 1'b1;
      else if (dt_down)
        detect <= 1'b0;
    end
  end

  assign irq_done = (rx_done | tx_done);
  assign irq_sof  = sof_irq;
  assign irq_err  = (crc_err | timeout) && (!sie_err);
  assign irq_det  = (dt_up & ~detect) | (dt_down & detect);

  reg irq_sof_d, irq_done_d, irq_err_d, irq_det_d;
  always @(posedge clk_usb or posedge rst_usb_i) begin
    if (rst_usb_i) begin
      irq_sof_d  <= 1'b0;
      irq_done_d <= 1'b0;
      irq_err_d  <= 1'b0;
      irq_det_d  <= 1'b0;
    end else begin
      irq_sof_d  <= irq_sof;
      irq_done_d <= irq_done;
      irq_err_d  <= irq_err;
      irq_det_d  <= irq_det;
    end
  end

  pulse_sync sof_ps  (.src_clk(clk_usb), .src_rst(rst_usb_i), .src_pulse(irq_sof  & ~irq_sof_d),
                      .dst_clk(clk_cpu), .dst_rst(rst_i), .dst_pulse(irq_sof_cpu));
  pulse_sync done_ps (.src_clk(clk_usb), .src_rst(rst_usb_i), .src_pulse(irq_done & ~irq_done_d),
                      .dst_clk(clk_cpu), .dst_rst(rst_i), .dst_pulse(irq_done_cpu));
  pulse_sync err_ps  (.src_clk(clk_usb), .src_rst(rst_usb_i), .src_pulse(irq_err  & ~irq_err_d),
                      .dst_clk(clk_cpu), .dst_rst(rst_i), .dst_pulse(irq_err_cpu));
  pulse_sync det_ps  (.src_clk(clk_usb), .src_rst(rst_usb_i), .src_pulse(irq_det  & ~irq_det_d),
                      .dst_clk(clk_cpu), .dst_rst(rst_i), .dst_pulse(irq_det_cpu));

  // Frame timer is gray-coded so the free-running count crosses safely.
  // The other status bits change only when the bus is idle.
  reg [15:0] sof_gray;
  reg [3:0]  stat_flags;
  reg [31:0] rx_stat_usb;
  always @(posedge clk_usb or posedge rst_usb_i) begin
    if (rst_usb_i) begin
      sof_gray    <= 16'h0;
      stat_flags  <= 4'h0;
      rx_stat_usb <= 32'h0;
    end else begin
      sof_gray    <= sof_timer ^ {1'b0, sof_timer[15:1]};
      stat_flags  <= {detect, phy_err, utmi_linestate_i};
      rx_stat_usb <= rx_stat_w;
    end
  end

  (* async_reg *) reg [15:0] sof_gray_s1, sof_gray_s2;
  (* async_reg *) reg [3:0]  stat_s1, stat_s2;
  (* async_reg *) reg [31:0] rx_s1, rx_s2;
  always @(posedge clk_cpu or posedge rst_i) begin
    if (rst_i) begin
      sof_gray_s1 <= 16'h0;
      sof_gray_s2 <= 16'h0;
      stat_s1     <= 4'h0;
      stat_s2     <= 4'h0;
      rx_s1       <= 32'h0;
      rx_s2       <= 32'h0;
    end else begin
      sof_gray_s1 <= sof_gray;
      sof_gray_s2 <= sof_gray_s1;
      stat_s1     <= stat_flags;
      stat_s2     <= stat_s1;
      rx_s1       <= rx_stat_usb;
      rx_s2       <= rx_s1;
    end
  end

  function [15:0] gray2bin16(input [15:0] g);
    integer i;
    begin
      gray2bin16[15] = g[15];
      for (i = 14; i >= 0; i = i - 1)
        gray2bin16[i] = gray2bin16[i+1] ^ g[i];
    end
  endfunction

  assign stat_cpu    = { gray2bin16(sof_gray_s2), 12'b0, stat_s2 };
  assign rx_stat_cpu = rx_s2;

endmodule

// One-cycle source pulse to a one-cycle destination pulse.
module pulse_sync (
  input  src_clk,
  input  src_rst,
  input  src_pulse,
  input  dst_clk,
  input  dst_rst,
  output dst_pulse
  );

  reg src_toggle;
  always @(posedge src_clk or posedge src_rst) begin
    if (src_rst)
      src_toggle <= 1'b0;
    else if (src_pulse)
      src_toggle <= ~src_toggle;
  end

  (* async_reg *) reg [2:0] dst_sync;
  always @(posedge dst_clk or posedge dst_rst) begin
    if (dst_rst)
      dst_sync <= 3'b0;
    else
      dst_sync <= {dst_sync[1:0], src_toggle};
  end

  assign dst_pulse = dst_sync[2] ^ dst_sync[1];

endmodule

// Level synchronizer. The level must stay high long enough to be sampled.
module level_sync (
  input  dst_clk,
  input  dst_rst,
  input  src_level,
  output dst_level
  );

  (* async_reg *) reg [1:0] sync;
  always @(posedge dst_clk or posedge dst_rst) begin
    if (dst_rst)
      sync <= 2'b0;
    else
      sync <= {sync[0], src_level};
  end

  assign dst_level = sync[1];

endmodule

// Dual-clock FIFO. A pop registers the head byte, matching the original
// single-clock FIFO: the byte is visible on the cycle after pop.
module AFIFO #(
  parameter DW = 8,
  parameter AW = 6
  ) (
  input              wr_clk,
  input              wr_rst,
  input              wr_flush,
  input  [DW-1:0]    wr_data,
  input              wr_push,
  output             wr_full,

  input              rd_clk,
  input              rd_rst,
  input              rd_flush,
  output [DW-1:0]    rd_data,
  input              rd_pop,
  output             rd_empty
  );

  reg [AW:0] wbin, rbin;
  reg [2:0]  wr_quiet, rd_quiet;

  wire wr_hold = wr_flush | (wr_quiet != 3'b0);
  wire rd_hold = rd_flush | (rd_quiet != 3'b0);

  wire [AW:0] wgray = wbin ^ {1'b0, wbin[AW:1]};
  wire [AW:0] rgray = rbin ^ {1'b0, rbin[AW:1]};

  (* async_reg *) reg [AW:0] rgray_s1, rgray_sync;
  (* async_reg *) reg [AW:0] wgray_s1, wgray_sync;

  always @(posedge wr_clk or posedge wr_rst) begin
    if (wr_rst) begin
      rgray_s1   <= {(AW+1){1'b0}};
      rgray_sync <= {(AW+1){1'b0}};
    end else begin
      rgray_s1   <= rgray;
      rgray_sync <= rgray_s1;
    end
  end

  always @(posedge rd_clk or posedge rd_rst) begin
    if (rd_rst) begin
      wgray_s1   <= {(AW+1){1'b0}};
      wgray_sync <= {(AW+1){1'b0}};
    end else begin
      wgray_s1   <= wgray;
      wgray_sync <= wgray_s1;
    end
  end

  // Full when every slot is occupied (64 bytes: one full-speed packet).
  // Comparing the current gray pointer, not the next one, accepts that last write.
  wire wr_full_cmp = (wgray == {~rgray_sync[AW:AW-1], rgray_sync[AW-2:0]});
  wire rd_empty_cmp = (rgray == wgray_sync);
  wire wr_do = wr_push & ~wr_full_cmp & ~wr_hold;
  wire rd_do = rd_pop  & ~rd_empty_cmp & ~rd_hold;

  always @(posedge wr_clk or posedge wr_rst) begin
    if (wr_rst) begin
      wbin     <= {(AW+1){1'b0}};
      wr_quiet <= 3'b111;
    end else begin
      wr_quiet <= {wr_quiet[1:0], wr_flush};
      if (wr_hold)
        wbin <= {(AW+1){1'b0}};
      else if (wr_do)
        wbin <= wbin + {{AW{1'b0}}, 1'b1};
    end
  end

  always @(posedge rd_clk or posedge rd_rst) begin
    if (rd_rst) begin
      rbin     <= {(AW+1){1'b0}};
      rd_quiet <= 3'b111;
    end else begin
      rd_quiet <= {rd_quiet[1:0], rd_flush};
      if (rd_hold)
        rbin <= {(AW+1){1'b0}};
      else if (rd_do)
        rbin <= rbin + {{AW{1'b0}}, 1'b1};
    end
  end

  assign wr_full  = wr_hold | wr_full_cmp;
  assign rd_empty = rd_hold | rd_empty_cmp;

  bram_true2p_2clk #(
    .data_width(DW),
    .addr_width(AW)
  ) ram (
    .data_in_a (wr_data),
    .data_in_b ({DW{1'b0}}),
    .addr_a    (wbin[AW-1:0]),
    .addr_b    (rbin[AW-1:0]),
    .we_a      (wr_do),
    .we_b      (1'b0),
    .clk_a     (wr_clk),
    .clk_b     (rd_clk),
    .clken_a   (1'b1),
    .clken_b   (rd_do),
    .data_out_a(),
    .data_out_b(rd_data)
  );

endmodule

`default_nettype wire
