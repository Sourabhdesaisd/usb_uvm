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
// Line states seen while a packet is active (samples that are neither J nor K):
//   FS/LS : SE0 is the EOP state (SE0 x EOP_SE0_MIN..EOP_SE0_MAX, then J, the detector
//           raises eop_det).  A longer SE0 is still the EOP / reset / detach state, not an
//           illegal line state.  SE1 is never legal.
//   HS    : SE0 is the IDLE state of the bus (no signal), not an invalid state.  SE1 is
//           the only invalid state.
//
// Symbol run (J/K samples only): number of consecutive identical symbols.  Valid data never
// has more than 6 identical symbols (the 7th is a stuff violation), so a longer run is not
// data.  In FS/LS a run of IDLE_J (= 8) closes the packet (J: bus idle and the EOP was lost,
// K: line stuck).  In HS the EOP itself is 8 identical symbols and the detector closes the
// packet with eop_det there; HS_RUN_LIM (> 8) is only a safety net for a missed EOP.
//
// ---------------------------------------------------------------------------------------
// ABORT (the packet is closed early through the normal eop path, so every pipeline stage
// finishes cleanly; the packet still ends with rx_eop on its last complete byte; the
// alignment check is skipped for an aborted packet)
//   cause                                      abort  rx_line_err  rx_stuff_err  drain
//   FS/LS / HS  SE1 sample                      yes      yes          no          yes
//   FS/LS  SE0 run ended by K (invalid EOP)     yes      yes          no          yes
//   FS/LS  SE0 run longer than EOP_SE0_MAX      yes      no           no          no
//   FS/LS  SE0 run shorter than EOP_SE0_MIN,
//          then J (only if MIN > 1)             yes      no           no          no
//   FS/LS  IDLE_J identical symbols in packet   yes      no           yes (*)     no
//          (J: bus idle, EOP lost; K: stuck)
//   HS     HS_RUN_LIM identical symbols, no EOP yes      no           yes         no
//   HS     SE0 for BAD_LIMIT samples (idle)     yes      no           no          no
//   bus_reset (usb2_rx_reset_detect)            yes      no           no          no
//   Normal EOP, normal idle                     no       no           no          no
//   (*) already set by the unstuffer at the 7th identical symbol
//
// DRAIN: after an abort that leaves the rest of the packet on the line (SE1 glitch, invalid
// EOP) the receiver ignores SYNC (sync_search_en = 0) until the line is idle again, so the
// tail of the aborted packet is not taken for a new packet.
//   starts : abort caused by SE1 (any speed) or by SE0 followed by K (FS/LS)
//   ends on the first of:
//     - eop_det (the real EOP of the aborted packet, if the detector reports it)
//     - an SE0 sample, any speed: SE0 is never data, it is the EOP (FS/LS) or the idle
//       (HS) that follows the tail, so this does not depend on eop_det
//     - FS/LS : IDLE_J (= 8) CONSECUTIVE J samples
//     - bus_reset
//
// ---------------------------------------------------------------------------------------
// ERRORS (flags are sticky until the next SYNC; rx_error = OR of them, visible only while
// rx_active = 1, UTMI RxError)
//   flag          set when
//   rx_stuff_err  - FS/LS: 7th consecutive identical symbol (from the unstuffer)
//                 - any speed: the identical-symbol run reached its limit without an EOP
//                 - NOT the bit-stuff violation that forms the HS EOP (7.1.13.2.2): that is
//                   the EOP, not an error
//   rx_line_err   - SE1 sample inside a packet (any speed)
//                 - FS/LS: SE0 run followed by K (invalid EOP)
//   rx_align_err  - end of a complete (not aborted) packet with bits left over in the SIPO
//                   (FS/LS: != 0, HS: != 7).  Status only by default: FS/LS hubs can add a
//                   "dribble" bit before the EOP (7.1.9.1, Fig. 7-33) and the receiver must
//                   accept such a packet; part of rx_error only if ALIGN_IN_RXERROR = 1
//   rx_sync_err   - 1-clk pulse, not part of rx_error: a SYNC-like start was broken while idle
//   No error at all: normal EOP, normal idle, long SE0, short SE0 then J, bus reset (the reset
//   detector reports it), HS idle SE0.  The upper layer decides with these flags and the CRC.
//
// Not supported on purpose: babble (packet longer than the maximum size) is not detectable
// in the PHY; the SIE / protocol layer checks the packet length.
module usb2_rx_ctrl
    import usb_phy_pkg::*;
#(
    parameter int WIDTH            = 8,
    parameter int BAD_LIMIT        = 8,     // HS: consecutive SE0 (idle) samples that close the packet
    parameter int EOP_SE0_MIN      = 1,     // FS/LS: SE0 samples that make a valid EOP (with J)
    parameter int EOP_SE0_MAX      = 3,     // FS/LS: SE0 samples above this close the packet
    parameter int HS_RUN_LIM       = 16,    // HS: identical symbols that close a packet whose EOP was missed (must be > 8)
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
    output logic             rx_sync_err
);
    localparam int CNT_W        = $clog2(WIDTH);                 // width of sipo_bit_count
    localparam int HS_JUNK_BITS = 7 % WIDTH;                     // 0 + six 1s of the HS EOP reach the SIPO
    localparam int IDLE_J       = 8;                             // FS/LS: identical symbols that cannot be data (J: idle)
    localparam int RUN_MAX      = (HS_RUN_LIM > IDLE_J) ? HS_RUN_LIM : IDLE_J; // run counter saturation value
    localparam int RUN_W        = $clog2(RUN_MAX + 1);           // width of the symbol run counter
    localparam int SE0_LIM_MAX  = (BAD_LIMIT > EOP_SE0_MAX + 1) ? BAD_LIMIT : (EOP_SE0_MAX + 1); // largest SE0 limit of both speeds
    localparam int SE0_W        = $clog2(SE0_LIM_MAX + 1);       // width of the SE0 run counter

    logic pkt_active;                // a packet is in progress (from sop_eff until eop_eff)
    logic abort_req;                 // registered abort request, closes the packet through eop_eff
    logic abort_dr;                  // registered: the aborted packet leaves a tail on the line (drain needed)
    logic drain;                     // ignoring SYNC until the line is idle again after an abort
    logic sop_eff;                   // accepted start of packet
    logic eop_eff;                   // accepted end of packet (real EOP or abort)
    logic jk;                        // the line sample is a J or a K

    logic [SE0_W-1:0] se0_run;       // consecutive SE0 samples inside the packet
    logic [SE0_W-1:0] se0_nxt;       // next value of se0_run
    logic [SE0_W-1:0] se0_lim;       // SE0 count that ends the packet (speed dependent)
    logic [RUN_W-1:0] run_cnt;       // consecutive identical J/K symbols, saturates at RUN_MAX
    logic [RUN_W-1:0] run_nxt;       // next value of run_cnt
    logic [RUN_W-1:0] run_lim;       // run length that closes a packet (speed dependent)
    logic             run_j;         // the current run is a run of J
    logic             run_j_nxt;     // next value of run_j
    logic             run_hit;       // this sample makes the run reach run_lim
    logic             stuff_set;     // stuff violation detected by the run limit in this clock
    logic abort_nxt;                 // abort cause detected in this clock
    logic abort_dr_nxt;              // that abort leaves a tail on the line
    logic line_set;                  // line error detected in this clock
    logic valid_eop_run;             // the SE0 run that ends on this J is a valid FS/LS EOP
    logic drain_clr;                 // the line is idle again

    logic sop_d1, sop_d2;            // sop_eff delayed 1 / 2 clocks
    logic eop_d1, eop_d2;            // eop_eff delayed 1 / 2 clocks
    logic ab_d1, ab_d2;              // "packet was aborted" aligned with eop_d1 / eop_d2
    logic fin_d1;                    // fin delayed 1 clock
    logic fin, fin_abort, align_bad;
    logic stuff_e, align_e, line_e;  // sticky error flags
    logic [WIDTH-1:0] hold_data;     // byte waiting for the next byte / the end of the packet
    logic             hold_vld;      // hold_data is valid
    logic             hold_first;    // hold_data is the first byte of the packet
    logic             first_pending; // next completed byte is the first of the packet
    logic             byte_in;       // SIPO delivers a byte inside a packet

    // line sample is a valid J or K symbol (anything else is SE0 or SE1)
    assign jk      = line_j | line_k;
    // a SIPO byte counts only while a packet is active at the SIE
    assign byte_in = sipo_valid & rx_active;

    // sop is ignored while a packet is active (data can contain KJKJKJKK) and while draining
    // after an abort
    assign sop_eff = sop_det & ~pkt_active & ~drain;
    // eop (or an abort) only counts while a packet is active
    assign eop_eff = pkt_active & (eop_det | abort_req);

    // SYNC is looked for only at the start of a packet: no packet in progress and not
    // draining after an abort
    assign sync_search_en = ~pkt_active & ~drain;

    // eop_eff / sop_eff drive the NRZI decoder directly; the later stages get them delayed
    assign dec_sop    = sop_eff;
    assign dec_eop    = eop_eff;
    assign unst_sop   = sop_d1;
    assign unst_eop   = eop_d1;
    assign sipo_clear = sop_d2;
    // end of packet at the SIPO output: the SIPO bit count is valid here
    assign fin        = eop_d2;
    assign fin_abort  = ab_d2;

    // packet is not byte aligned: HS leaves the 7 EOP bits in the SIPO, FS/LS leaves none
    assign align_bad = (speed == HS) ? (sipo_bit_count != CNT_W'(HS_JUNK_BITS))
                                     : (sipo_bit_count != '0);

    // number of consecutive SE0 samples that ends the packet:
    //   HS    : BAD_LIMIT samples of idle (debounce)
    //   FS/LS : one more than the longest valid EOP
    assign se0_lim = (speed == HS) ? SE0_W'(BAD_LIMIT) : SE0_W'(EOP_SE0_MAX + 1);

    // FS/LS: the J sample that ends an SE0 run of EOP_SE0_MIN..EOP_SE0_MAX samples is the
    // end of a valid EOP (same rule as the detector, which raises eop_det one clock later)
    assign valid_eop_run = (speed != HS) && line_j &&
                           (se0_run >= SE0_W'(EOP_SE0_MIN)) && (se0_run <= SE0_W'(EOP_SE0_MAX));

    // ---------------------------------------------------------------
    // symbol run counter: consecutive identical J/K symbols (SE0 / SE1 restart it)
    // ---------------------------------------------------------------
    always_comb begin
        run_nxt   = run_cnt;                              // hold between samples
        run_j_nxt = run_j;
        if (sample_valid) begin
            if (jk) begin
                if ((run_cnt != '0) && (run_j == line_j)) begin
                    if (run_cnt != RUN_W'(RUN_MAX))
                        run_nxt = run_cnt + 1'b1;         // same symbol: count, saturate
                end else begin
                    run_nxt = RUN_W'(1);                  // symbol changed: new run of length 1
                end
                run_j_nxt = line_j;
            end else begin
                run_nxt = '0;                             // SE0 / SE1: no run
            end
        end
    end

    // run length that cannot be data and closes the packet: IDLE_J in FS/LS, HS_RUN_LIM in HS
    assign run_lim = (speed == HS) ? RUN_W'(HS_RUN_LIM) : RUN_W'(IDLE_J);
    // this J/K sample makes the run reach that length
    assign run_hit = sample_valid & jk & (run_nxt >= run_lim);

    // line is idle / the tail of an aborted packet is over:
    //   - eop_det: the real EOP of the aborted packet
    //   - bus_reset
    //   - an SE0 sample (any speed): never data; the EOP (FS/LS) or the idle (HS) after the tail
    //   - FS/LS: 8 or more consecutive J samples (run of J reached IDLE_J)
    assign drain_clr = eop_det | bus_reset |
                       (sample_valid & line_se0) |
                       ((speed != HS) & run_j_nxt & (run_nxt >= RUN_W'(IDLE_J)));

    // ---------------------------------------------------------------
    // line supervision (only while a packet is active and not already closing)
    // ---------------------------------------------------------------
    always_comb begin
        line_set     = 1'b0;                              // default: no line error
        abort_nxt    = 1'b0;                              // default: no abort
        abort_dr_nxt = 1'b0;                              // default: no tail after the abort
        stuff_set    = 1'b0;                              // default: no run-limit stuff violation
        se0_nxt      = se0_run;                           // default: hold the SE0 run

        if (pkt_active && !eop_eff) begin
            // bus reset: packet is cut, nothing follows; not a line error (the reset
            // detector reports it)
            if (bus_reset) abort_nxt = 1'b1;

            if (sample_valid) begin
                if (line_se1) begin
                    // SE1 is an invalid state at every speed: abort, the rest of the
                    // packet may still follow, so drain
                    line_set     = 1'b1;
                    abort_nxt    = 1'b1;
                    abort_dr_nxt = 1'b1;
                end else if (line_se0) begin
                    // SE0: count the run (saturates at se0_lim)
                    if (se0_run != se0_lim)
                        se0_nxt = se0_run + 1'b1;
                    // run reached the limit: the packet is closed, no tail follows, no drain.
                    // Not a line error: SE0 is the EOP state in FS/LS (a long SE0 is EOP /
                    // reset / detach) and the idle state in HS.
                    if (se0_nxt == se0_lim) abort_nxt = 1'b1;
                end else if (jk) begin
                    // J or K ends the SE0 run
                    se0_nxt = '0;
                    // FS/LS only: an SE0 run that is not a valid EOP closes the packet.
                    //   followed by K: data goes on after the "EOP", so it was not an EOP:
                    //                  line error, and drain the rest of the packet
                    //   followed by J: the line is idle (truncated EOP): no error, no drain
                    // HS: a short SE0 gap is idle, not an error.
                    if ((se0_run != '0) && (speed != HS) && !valid_eop_run) begin
                        line_set     = line_k;
                        abort_nxt    = 1'b1;
                        abort_dr_nxt = line_k;
                    end
                    // identical-symbol run reached its limit without an EOP:
                    //   FS/LS: 8 identical symbols (J: bus idle and the EOP was lost, K: line
                    //          stuck) - can never be data, so the packet is closed
                    //   HS   : the detector missed the EOP (normal EOP = 8 symbols)
                    // Close the packet, otherwise it would never end.  This is a bit-stuff
                    // violation that was not an EOP: rx_stuff_err; not a line error; no tail
                    // follows, no drain.
                    if (run_hit) begin
                        abort_nxt = 1'b1;
                        stuff_set = 1'b1;
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
            sym_bit       <= 1'b0;
            sym_valid     <= 1'b0;
            pkt_active    <= 1'b0;
            abort_req     <= 1'b0;
            abort_dr      <= 1'b0;
            drain         <= 1'b0;
            se0_run       <= '0;
            run_cnt       <= '0;
            run_j         <= 1'b0;
            fin_d1        <= 1'b0;
            sop_d1 <= 1'b0; sop_d2 <= 1'b0;
            eop_d1 <= 1'b0; eop_d2 <= 1'b0;
            ab_d1  <= 1'b0; ab_d2  <= 1'b0;
            stuff_e <= 1'b0; align_e <= 1'b0; line_e <= 1'b0;
            rx_active     <= 1'b0;
            rx_sop        <= 1'b0;
            rx_eop        <= 1'b0;
            rx_valid      <= 1'b0;
            rx_data       <= '0;
            rx_sync_err   <= 1'b0;
            hold_data     <= '0;
            hold_vld      <= 1'b0;
            hold_first    <= 1'b0;
            first_pending <= 1'b0;
        end else begin
            // J/K symbol stream, one clock behind the line samples (matches detector latency)
            sym_valid <= sample_valid & jk;               // only J/K samples carry data
            sym_bit   <= line_j;                          // 1 = J, 0 = K

            // framing: packet starts at sop_eff and ends at eop_eff
            if (sop_eff)       pkt_active <= 1'b1;
            else if (eop_eff)  pkt_active <= 1'b0;

            // abort request and its drain flag are registered, so the packet is closed
            // one clock after the cause
            abort_req <= abort_nxt;
            abort_dr  <= abort_dr_nxt;

            // SE0 run: restarts at every new packet
            se0_run <= sop_eff ? '0 : se0_nxt;

            // identical-symbol run counter runs all the time
            run_cnt <= run_nxt;
            run_j   <= run_j_nxt;

            // drain: start when an abort closes the packet and a tail follows (not when the
            // real EOP arrives together with the abort); end when the line is idle again
            if (eop_eff && abort_req && abort_dr && !eop_det) drain <= 1'b1;
            else if (drain_clr)                               drain <= 1'b0;

            // alignment taps: delay sop / eop / abort to the unstuffer and SIPO stages
            fin_d1 <= fin;
            sop_d1 <= sop_eff;  sop_d2 <= sop_d1;
            eop_d1 <= eop_eff;  eop_d2 <= eop_d1;
            ab_d1  <= eop_eff & abort_req;                // this eop is an abort
            ab_d2  <= ab_d1;

            // error flags: cleared by the next SYNC, sticky until then
            if (sop_eff) begin
                stuff_e <= 1'b0;
                align_e <= 1'b0;
                line_e  <= 1'b0;
            end else begin
                if ((stuff_err && (speed != HS)) || stuff_set)     // FS/LS stuff error, or a run that never ended in an EOP;
                    stuff_e <= 1'b1;                               // the HS EOP violation is the EOP, not an error
                if (line_set)                   line_e  <= 1'b1;   // line error from the supervision
                if (fin && !fin_abort && align_bad) align_e <= 1'b1; // alignment is only valid for a complete packet
            end

            // SIE interface
            if (sop_eff)     rx_active <= 1'b1;
            else if (fin_d1) rx_active <= 1'b0;           // one clock after fin: RxError is visible while RxActive is high
            // SYNC-like start broken while idle (the detector is only enabled in sync_search_en)
            rx_sync_err <= sync_err_det & sync_search_en & ~rx_active;

            // byte output with first / last tagging (one-byte holding register)
            rx_valid <= 1'b0;                             // defaults: one-clock strobes
            rx_sop   <= 1'b0;
            rx_eop   <= 1'b0;
            if (fin) begin
                // end of packet: the held byte is the last one
                if (hold_vld) begin
                    rx_valid <= 1'b1;
                    rx_data  <= hold_data;
                    rx_sop   <= hold_first;               // 1-byte packet: first and last
                    rx_eop   <= 1'b1;
                end
                hold_vld <= 1'b0;                         // holding register is empty again
            end else if (byte_in) begin
                // a newer byte exists: the held byte was not the last one
                if (hold_vld) begin
                    rx_valid <= 1'b1;
                    rx_data  <= hold_data;
                    rx_sop   <= hold_first;
                end
                hold_vld      <= 1'b1;                    // the new byte is now held
                hold_data     <= sipo_data;
                hold_first    <= first_pending;
                first_pending <= 1'b0;
            end
            if (sop_eff) first_pending <= 1'b1;           // next completed byte is the first one
        end
    end

    // sticky status flags (valid until the next SYNC)
    assign rx_stuff_err = stuff_e;
    assign rx_align_err = align_e;
    assign rx_line_err  = line_e;
    // UTMI RxError: only while RxActive is high (the SIE samples it when RxActive falls).
    // The rx_*_err flags above stay latched until the next SYNC (optional status).
    assign rx_error     = (stuff_e | line_e | (ALIGN_IN_RXERROR & align_e)) & rx_active;

endmodule

