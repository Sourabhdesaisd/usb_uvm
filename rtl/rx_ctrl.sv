// file: rx_ctrl.sv   (module usb2_rx_ctrl)
//
// RX packet controller: framing, alignment of sop/eop to every pipeline stage,
// line supervision, error collection and the SIE-facing outputs.
//
// Pipeline timing (n = clock of the last SYNC sample, m = clock of the sample that
// completes the EOP; every stage is registered):
//   detector : sop_det / eop_det appear at n+1 / m+1
//   sym_*    : the J/K symbol stream is delayed by one clock so that it lines up with
//              sop_det / eop_det (sop with the last SYNC symbol, eop with the first
//              symbol that must not be decoded)
//   NRZI dec : dec_sop / dec_eop                        (clock n+1 / m+1)
//   unstuffer: unst_sop / unst_eop = dec_* delayed 1    (decoder output stream)
//   SIPO     : sipo_clear          = dec_sop delayed 2
//   finish   : fin                 = dec_eop delayed 2  (SIPO bit count is valid)
//   rx_active falls one clock after fin so RxError is visible while RxActive is high.
//
// First / last byte tagging (rx_sop, rx_eop):
//   rx_sop is high for one clock together with rx_valid / rx_data of the FIRST byte of a
//   packet, rx_eop together with the LAST byte (both on the same byte of a 1-byte packet).
//   The last byte is only known when the EOP arrives, which is after the byte was assembled,
//   so every assembled byte waits in a one-byte holding register:
//     - the next byte completes -> the held byte is released (rx_valid), it was not the last
//     - fin (end of packet)     -> the held byte is released with rx_eop, it is the last one
//   A packet without a complete byte (SYNC + EOP only, or a partial byte) gives no
//   rx_valid, no rx_sop and no rx_eop.  An aborted packet also ends with rx_eop on its
//   last complete byte (the abort is reported by rx_error / rx_*_err).
//   The last byte is released at m+4, while rx_active is still high (it falls at m+5).
//   Corner case: a byte that completes in the very clock of fin (possible only after an
//   abort, the packet is already flagged) is dropped.
//
// HS: the last 7 EOP bits (0 followed by six 1s) reach the SIPO, so a byte-aligned HS
// packet leaves 7 bits pending; FS/LS leaves 0.
//
// Line supervision while a packet is active (samples that are neither J nor K):
//   FS/LS : SE0 x EOP_SE0_MIN..EOP_SE0_MAX followed by J is the EOP (handled by the
//           detector).  Anything else is not a valid EOP:
//             - the SE0 run ends (J or K) outside that range, or contains SE1
//               -> rx_line_err, packet aborted
//             - the run exceeds EOP_SE0_MAX samples (SE0 too long: bus reset, detach or
//               fault) -> rx_line_err, packet aborted immediately, without waiting for J
//   HS    : any non-J/K sample is rx_line_err; BAD_LIMIT consecutive ones (squelch lost)
//           abort the packet.
//   bus_reset (SE0 > 2.5 us, from usb2_rx_reset_detect) also aborts an active packet.
//   After an abort caused by something that leaves the rest of the packet on the line
//   (a bad SE0/SE1 glitch inside the packet, babble) the receiver ignores SYNC until the
//   line is idle again ("drain"): an EOP is seen, or 8 consecutive J samples (FS/LS), or
//   an SE0 sample (HS).  This stops the tail of the aborted packet from being taken for a
//   new packet.  Aborts caused by a long SE0 (reset / detach) or squelch loss do not drain:
//   no packet tail follows, so the next SYNC is accepted immediately.
//
// Errors (the four flags are sticky until the next SYNC):
//   rx_stuff_err  seventh consecutive 1 (bit stuffing violation)
//   rx_align_err  packet did not end on a byte boundary.  Status only by default: FS/LS
//                 hubs can stretch the last bit (an extra "dribble" bit before the EOP,
//                 7.1.9.1, Fig. 7-33) and the receiver must accept such a packet, so it is
//                 not an RxError unless ALIGN_IN_RXERROR = 1; the SIE checks the CRC.
//   rx_line_err   illegal line state / invalid EOP / bus reset during packet
//   rx_babble_err no EOP within MAX_PKT_SYMBOLS symbols (packet aborted)
//   rx_error      OR of the flags (align only if ALIGN_IN_RXERROR = 1), visible only
//                 while rx_active = 1 (UTMI RxError).  HS never raises rx_stuff_err: any
//                 HS bit-stuff error is an EOP (7.1.13.2.2) and ends the packet.
//   rx_sync_err   1-clk pulse: a SYNC-like start was broken while idle
module usb2_rx_ctrl
    import usb_phy_pkg::*;
#(
    parameter int WIDTH            = 8,
    parameter int MAX_PKT_SYMBOLS  = 12288,
    parameter int BAD_LIMIT        = 8,     // HS: consecutive non-J/K samples before abort
    parameter int EOP_SE0_MIN      = 1,     // FS/LS: SE0 samples that make a valid EOP (with J)
    parameter int EOP_SE0_MAX      = 3,
    parameter bit ALIGN_IN_RXERROR = 1'b0
)(
    input  logic clk,
    input  logic rst_n,
    input  speed_t speed,
    input  logic bus_reset,      // from usb2_rx_reset_detect

    // line samples (same clock as sample_valid)
    input  logic sample_valid,
    input  logic line_j,
    input  logic line_k,
    input  logic line_se0,
    input  logic line_se1,

    // from sync / eop detector
    input  logic sop_det,
    input  logic eop_det,
    input  logic sync_err_det,

    // from bit unstuffer
    input  logic stuff_err,

    // from SIPO
    input  logic [$clog2(WIDTH)-1:0] sipo_bit_count,
    input  logic [WIDTH-1:0]         sipo_data,
    input  logic                     sipo_valid,

    // to sync / eop detector
    output logic sync_search_en, // SYNC is searched only while this is 1

    // to datapath
    output logic sym_bit,        // -> nrzi_enc_in   (1 = J, 0 = K)
    output logic sym_valid,      // -> nrzi_enc_valid
    output logic dec_sop,        // -> nrzi decoder sop
    output logic dec_eop,        // -> nrzi decoder eop
    output logic unst_sop,       // -> unstuffer sop
    output logic unst_eop,       // -> unstuffer eop
    output logic sipo_clear,     // -> SIPO clear

    // to SIE
    output logic             rx_active,
    output logic             rx_sop,
    output logic             rx_eop,
    output logic             rx_valid,
    output logic [WIDTH-1:0] rx_data,
    output logic             rx_error,
    output logic             rx_stuff_err,
    output logic             rx_align_err,
    output logic             rx_line_err,
    output logic             rx_babble_err,
    output logic             rx_sync_err
);
    localparam int CNT_W        = $clog2(WIDTH);
    localparam int SYM_W        = $clog2(MAX_PKT_SYMBOLS + 1);
    localparam int RUN_LIM      = (BAD_LIMIT > EOP_SE0_MAX + 1) ? BAD_LIMIT : (EOP_SE0_MAX + 1);
    localparam int BAD_W        = $clog2(RUN_LIM + 1);
    localparam int HS_JUNK_BITS = 7 % WIDTH;       // 0 + six 1s of the HS EOP reach the SIPO
    localparam int IDLE_J       = 8;               // J samples that mean "line idle" (FS/LS)

    logic pkt_active, abort_req, abort_dr, drain;
    logic sop_eff, eop_eff;
    logic jk;

    logic [BAD_W-1:0] bad_run, bad_nxt, abort_lim;
    logic             run_se1, run_se1_nxt;
    logic [SYM_W-1:0] sym_cnt;
    logic [3:0]       j_run;
    logic abort_nxt, abort_dr_nxt, line_set, babble_set, cnt_inc, valid_eop_run;

    logic sop_d1, sop_d2, eop_d1, eop_d2, ab_d1, ab_d2, fin_d1;
    logic fin, fin_abort, align_bad;
    logic stuff_e, align_e, line_e, babble_e;
    logic drain_clr;
    logic [WIDTH-1:0] hold_data;     // byte waiting for the next byte / the end of the packet
    logic             hold_vld;      // hold_data is valid
    logic             hold_first;    // hold_data is the first byte of the packet
    logic             first_pending; // next completed byte is the first of the packet
    logic             byte_in;       // SIPO delivers a byte inside a packet

    assign jk = line_j | line_k;
    assign byte_in = sipo_valid & rx_active;

    // sop is ignored while a packet is active (data can contain KJKJKJKK), while draining
    // after an abort, and when decoding is disabled; eop (or an abort) only counts while
    // a packet is active
    assign sop_eff = sop_det & ~pkt_active & ~drain;
    assign eop_eff = pkt_active & (eop_det | abort_req);

    // SYNC is looked for only at the start of a packet: idle bus, no packet in progress,
    // not draining after an abort, decoding enabled
    assign sync_search_en = ~pkt_active & ~drain;

    assign dec_sop    = sop_eff;
    assign dec_eop    = eop_eff;
    assign unst_sop   = sop_d1;
    assign unst_eop   = eop_d1;
    assign sipo_clear = sop_d2;
    assign fin        = eop_d2;
    assign fin_abort  = ab_d2;

    assign align_bad = (speed == HS) ? (sipo_bit_count != CNT_W'(HS_JUNK_BITS))
                                     : (sipo_bit_count != '0);

    assign abort_lim = (speed == HS) ? BAD_W'(BAD_LIMIT) : BAD_W'(EOP_SE0_MAX + 1);

    // the SE0 run that ended on a J is a valid FS/LS EOP (same rule as the detector)
    assign valid_eop_run = (speed != HS) && !run_se1 && line_j &&
                           (bad_run >= BAD_W'(EOP_SE0_MIN)) && (bad_run <= BAD_W'(EOP_SE0_MAX));

    // line is idle again after an abort
    assign drain_clr = eop_det |
                       (sample_valid && ((speed == HS) ? !jk : (j_run >= 4'(IDLE_J))));

    // ---------------------------------------------------------------
    // line-quality / babble supervision (while a packet is active)
    // ---------------------------------------------------------------
    always_comb begin
        line_set    = 1'b0;
        babble_set  = 1'b0;
        abort_nxt   = 1'b0;
        abort_dr_nxt = 1'b0;
        cnt_inc     = 1'b0;
        bad_nxt     = bad_run;
        run_se1_nxt = run_se1;

        if (pkt_active && !eop_eff) begin
            if (bus_reset) begin
                line_set  = 1'b1;
                abort_nxt = 1'b1;
            end
            if (sample_valid) begin
                if (!jk) begin
                    if (bad_run != BAD_W'(RUN_LIM))
                        bad_nxt = bad_run + 1'b1;
                    if (line_se1) run_se1_nxt = 1'b1;
                    if (line_se1 || (speed == HS))
                        line_set = 1'b1;
                    if (bad_nxt == abort_lim) begin
                        line_set  = 1'b1;
                        abort_nxt = 1'b1;
                    end
                end else begin
                    cnt_inc = 1'b1;
                    if (bad_run != '0) begin
                        bad_nxt     = '0;
                        run_se1_nxt = 1'b0;
                        if (!valid_eop_run) begin
                            line_set = 1'b1;
                            if (speed != HS) begin
                                abort_nxt    = 1'b1;
                                // a K (or SE1 inside the run) means data is still coming: drain.
                                // A J looks like the idle after a truncated EOP: no drain.
                                abort_dr_nxt = line_k | run_se1;
                            end
                        end
                    end
                    if (sym_cnt == SYM_W'(MAX_PKT_SYMBOLS - 1)) begin
                        babble_set   = 1'b1;
                        abort_nxt    = 1'b1;
                        abort_dr_nxt = 1'b1;
                    end
                end
            end
        end
    end

    // ---------------------------------------------------------------
    // sequential part
    // ---------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sym_bit     <= 1'b0;
            sym_valid   <= 1'b0;
            pkt_active  <= 1'b0;
            abort_req   <= 1'b0;
            abort_dr    <= 1'b0;
            drain       <= 1'b0;
            bad_run     <= '0;
            run_se1     <= 1'b0;
            sym_cnt     <= '0;
            j_run       <= '0;
            fin_d1      <= 1'b0;
            sop_d1 <= 1'b0; sop_d2 <= 1'b0;
            eop_d1 <= 1'b0; eop_d2 <= 1'b0;
            ab_d1  <= 1'b0; ab_d2  <= 1'b0;
            stuff_e <= 1'b0; align_e <= 1'b0; line_e <= 1'b0; babble_e <= 1'b0;
            rx_active   <= 1'b0;
            rx_sop      <= 1'b0;
            rx_eop      <= 1'b0;
            rx_valid    <= 1'b0;
            rx_data     <= '0;
            rx_sync_err <= 1'b0;
            hold_data     <= '0;
            hold_vld      <= 1'b0;
            hold_first    <= 1'b0;
            first_pending <= 1'b0;
        end else begin
            // J/K symbol stream, one clock behind the line samples (matches detector latency)
            sym_valid <= sample_valid & jk;
            sym_bit   <= line_j;

            // framing
            if (sop_eff)       pkt_active <= 1'b1;
            else if (eop_eff)  pkt_active <= 1'b0;

            abort_req <= abort_nxt;
            abort_dr  <= abort_dr_nxt;
            bad_run   <= sop_eff ? '0 : bad_nxt;
            run_se1   <= sop_eff ? 1'b0 : run_se1_nxt;
            if (sop_eff)       sym_cnt <= '0;
            else if (cnt_inc)  sym_cnt <= sym_cnt + 1'b1;

            // drain after an abort until the line is idle again
            if (eop_eff && abort_req && abort_dr) drain <= 1'b1;
            else if (drain_clr)       drain <= 1'b0;

            if (sample_valid)
                j_run <= line_j ? ((j_run == 4'd15) ? 4'd15 : j_run + 1'b1) : 4'd0;

            // alignment taps
            fin_d1 <= fin;
            sop_d1 <= sop_eff;  sop_d2 <= sop_d1;
            eop_d1 <= eop_eff;  eop_d2 <= eop_d1;
            ab_d1  <= pkt_active & abort_req;
            ab_d2  <= ab_d1;

            // error flags: cleared by the next SYNC, sticky until then
            if (sop_eff) begin
                stuff_e  <= 1'b0;
                align_e  <= 1'b0;
                line_e   <= 1'b0;
                babble_e <= 1'b0;
            end else begin
                if (stuff_err)  stuff_e  <= 1'b1;
                if (line_set)   line_e   <= 1'b1;
                if (babble_set) babble_e <= 1'b1;
                if (fin && !fin_abort && align_bad) align_e <= 1'b1;
            end

            // SIE interface
            if (sop_eff)     rx_active <= 1'b1;
            else if (fin_d1) rx_active <= 1'b0;   // one clock after fin: RxError is visible while RxActive is high
            rx_sync_err <= sync_err_det & ~pkt_active & ~rx_active;

            // byte output with first / last tagging (one-byte holding register)
            rx_valid <= 1'b0;
            rx_sop   <= 1'b0;
            rx_eop   <= 1'b0;
            if (fin) begin
                // end of packet: the held byte is the last one
                if (hold_vld) begin
                    rx_valid <= 1'b1;
                    rx_data  <= hold_data;
                    rx_sop   <= hold_first;
                    rx_eop   <= 1'b1;
                end
                hold_vld <= 1'b0;
            end else if (byte_in) begin
                // a newer byte exists: the held byte was not the last one
                if (hold_vld) begin
                    rx_valid <= 1'b1;
                    rx_data  <= hold_data;
                    rx_sop   <= hold_first;
                end
                hold_vld      <= 1'b1;
                hold_data     <= sipo_data;
                hold_first    <= first_pending;
                first_pending <= 1'b0;
            end
            if (sop_eff) first_pending <= 1'b1;
        end
    end

    assign rx_stuff_err  = stuff_e;
    assign rx_align_err  = align_e;
    assign rx_line_err   = line_e;
    assign rx_babble_err = babble_e;
    // UTMI RxError: only while RxActive is high (the SIE samples it when RxActive falls).
    // The four rx_*_err flags above stay latched until the next SYNC (optional status).
    assign rx_error      = (stuff_e | line_e | babble_e | (ALIGN_IN_RXERROR & align_e)) & rx_active;

endmodule


