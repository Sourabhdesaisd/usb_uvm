// file: sync_eop_detector.sv   (module usb2_rx_sync_eop_detector)
//
// SYNC and EOP detector.  Inputs are examined only in a clock where sample_valid = 1
// (one sample per received bit time; every clock in HS).  Outputs are registered
// 1-clk pulses, one clock AFTER the sample that caused them.
//
//  sop        : SYNC complete
//  eop        : EOP detected
//  sync_error : a SYNC-like start (>= SYNC_ERR_MIN matching symbols) was broken
//
// ---------------------------------------------------------------------------------
// SYNC  (USB 2.0 7.1.10)
//   FS/LS : K J K J K J K K                        8 symbols
//   HS    : (K J) x 15, K K                       32 symbols at the source.  Every hub
//           repeater may truncate up to 4 bits, so a device can see as few as 12
//           SYNC bits.  The detector therefore accepts any SYNC of at least
//           HS_SYNC_MIN_ALT + 1 = 12 symbols (11 alternating symbols, then the final K).
//   Matching: sync_count = number of alternating symbols matched (K J K J ...).
//             odd count : a J is expected, a K here is the final "KK" -> SYNC done
//                         (only if sync_count >= minimum for the speed)
//             even count: a K is expected
//   Extra pairs: the SYNC is accepted with any number of alternating symbols between the
//             minimum and the maximum for the speed.
//                         minimum (alt. symbols)   maximum (alt. symbols)
//               FS / LS   FSLS_SYNC_MIN_ALT = 7    FSLS_SYNC_MAX_ALT = 15  (3 pairs, up to 4 extra pairs)
//               HS        HS_SYNC_MIN_ALT   = 11   HS_SYNC_MAX_ALT   = 31  (full 15-pair SYNC)
//             The spec SYNC is never longer than its nominal length (hubs only remove bits),
//             so the maximum only tolerates noise.  A longer alternating run raises
//             sync_error and the detector ignores that run (lock-out) until the pattern stops
//             alternating (two equal symbols in a row) or the line shows SE0 / SE1.
//             Set the maximum to 63 for "no limit".  Both values must be odd.
//
// EOP FS/LS (USB 2.0 7.1.13.2.1) :  SE0, SE0, J   (source SE0 = 2 bit times)
//   Detected when EOP_SE0_MIN .. EOP_SE0_MAX consecutive SE0 samples are followed by
//   a J sample.  The nominal EOP gives 2 SE0 samples, but the spec says a receiver
//   must accept any valid EOP, with the SE0 as short as 82 ns (FS) / 670 ns (LS), about
//   one bit time, so EOP_SE0_MIN defaults to 1 (the samples are taken mid-bit, so a
//   14 ns SE0 glitch at a J/K transition is never sampled).  Set EOP_SE0_MIN = 2 for a
//   strict "SE0, SE0, J" receiver.  More than EOP_SE0_MAX SE0 samples is NOT an EOP: it
//   is a longer SE0 (bus reset >2.5 us, detach, fault) and no eop is produced, even if
//   a J follows.
//
// EOP HS (USB 2.0 7.1.13.2)     :  NRZ 0111_1111  (8 identical J/K symbols)
//   A data run is at most 7 identical symbols (bit stuffing), so the 8th identical
//   symbol is an EOP.  The SOF EOP (40 symbols) is reported once, at the 8th symbol.
//
// EOP is only reported INSIDE a packet: eop_hit is qualified with sync_search_en = 0 (a
//   packet is in progress, or the receiver is draining after an abort / disabled).  On an
//   idle bus nothing can be an EOP: a run of identical J/K symbols in HS (chirp, resume K,
//   dribble after the EOP), or an SE0-J glitch / LS keep-alive EOP in FS/LS, no longer
//   produces an eop pulse.  Legal packet data cannot look like an HS EOP anyway: bit
//   stuffing limits a run of identical symbols to 7 (six 1s plus the symbol before them,
//   the last SYNC 1 counting as the first one), so only the 8th identical symbol is an EOP.
//   In FS/LS an EOP needs an SE0 sample, which data never contains.
//
// HS dribble : hub repeaters can add up to 4 random bits per hub after the EOP (up to 20
//   seen by a device), and the SOF EOP is 40 symbols long.  After an HS EOP the SYNC
//   search stays disabled until the line returns to the HS idle state (an SE0 sample), so
//   dribble can never be taken for a new SYNC.  HS_HOLDOFF_MAX (J/K symbols) is only a
//   safety limit (longer than the longest packet) in case the line never shows SE0.
//
// SYNC is searched ONLY at the start of a packet: the search runs while sync_search_en = 1
// (bus idle, not inside a packet, not draining after an error) and is switched off, with
// its partial match cleared, during data, during the EOP and after an HS EOP.
//
// sync_search_en comes from usb2_rx_ctrl.  The detector also blocks the search by itself
// in the clock after it issued sop (the first data symbol).
module usb2_rx_sync_eop_detector
    import usb_phy_pkg::*;
#(
    parameter int HS_SYNC_MIN_ALT   = 11,   // HS : min alternating symbols before final K (12-symbol SYNC)
    parameter int HS_SYNC_MAX_ALT   = 31,   // HS : max alternating symbols (31 -> full 32-symbol SYNC)
    parameter int FSLS_SYNC_MIN_ALT = 7,    // FS/LS : 7 -> 8-symbol SYNC
    parameter int FSLS_SYNC_MAX_ALT = 15,   // FS/LS : max alternating symbols (up to 4 extra KJ pairs tolerated)
    parameter int SYNC_ERR_MIN      = 5,
    parameter int EOP_SE0_MIN       = 1,
    parameter int EOP_SE0_MAX       = 3,
    parameter int HS_HOLDOFF_MAX    = 16384
)(
    input  logic clk,
    input  logic rst_n,

    // 2'b00 = Low-Speed, 2'b01 = Full-Speed, 2'b10 = High-Speed
    input  speed_t speed,

    // one pulse per received bit/symbol (mid-bit); HS: every clock
    input  logic sample_valid,

    // 1 = a new SYNC may be searched (idle bus, outside a packet)
    input  logic sync_search_en,

    input  logic line_j,
    input  logic line_k,
    input  logic line_se0,
    input  logic line_se1,

    output logic sop,
    output logic eop,
    output logic sync_error
);
    localparam int SE0_W  = $clog2(EOP_SE0_MAX + 2);
    localparam int HOLD_W = $clog2(HS_HOLDOFF_MAX + 1);

    logic [5:0]        sync_count;
    logic              sync_active;
    logic [SE0_W-1:0]  se0_count;          // saturates at EOP_SE0_MAX + 1 ("too long")
    logic              previous_valid;
    logic              previous_line;
    logic [3:0]        hs_repeat_count;
    logic [HOLD_W-1:0] hs_hold;            // dribble hold-off (symbols)
    logic              sync_dead;          // lock-out after a SYNC-like run that was too long
    logic              last_valid;         // previous sample was J or K
    logic              last_sym;           // previous J/K symbol (1 = J)

    logic       is_jk, current_line;
    logic [5:0] sync_min, sync_max;
    logic       eop_hit_fsls, eop_hit_hs, eop_hit;

    always_comb begin
        is_jk        = line_j || line_k;
        current_line = line_j;                                   // J = 1, K = 0
        sync_min     = (speed == HS) ? 6'(HS_SYNC_MIN_ALT) : 6'(FSLS_SYNC_MIN_ALT);
        sync_max     = (speed == HS) ? 6'(HS_SYNC_MAX_ALT) : 6'(FSLS_SYNC_MAX_ALT);

        eop_hit_fsls = ((speed == FS) || (speed == LS)) && sample_valid && line_j &&
                       (se0_count >= SE0_W'(EOP_SE0_MIN)) &&
                       (se0_count <= SE0_W'(EOP_SE0_MAX)) &&
                       !sync_search_en;                  // only inside a packet / drain

        eop_hit_hs   = (speed == HS) && sample_valid && is_jk && previous_valid &&
                       (current_line == previous_line) && (hs_repeat_count == 4'd6) &&
                       !sync_search_en;                  // only inside a packet / drain

        eop_hit      = eop_hit_fsls | eop_hit_hs;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_count      <= 6'd0;
            sync_active     <= 1'b0;
            se0_count       <= '0;
            previous_valid  <= 1'b0;
            previous_line   <= 1'b0;
            hs_repeat_count <= 4'd0;
            hs_hold         <= '0;
            sync_dead       <= 1'b0;
            last_valid      <= 1'b0;
            last_sym        <= 1'b0;
            sop             <= 1'b0;
            eop             <= 1'b0;
            sync_error      <= 1'b0;
        end else begin
            sop        <= 1'b0;
            eop        <= 1'b0;
            sync_error <= 1'b0;

            if (sample_valid) begin
                eop <= eop_hit;

                // ----- FS / LS : count consecutive SE0 samples -----
                if ((speed == FS) || (speed == LS)) begin
                    if (line_se0) begin
                        if (se0_count != SE0_W'(EOP_SE0_MAX + 1))
                            se0_count <= se0_count + 1'b1;
                    end else
                        se0_count <= '0;
                end else
                    se0_count <= '0;

                // ----- HS : run of identical J/K symbols -----
                if (speed == HS) begin
                    if (is_jk) begin
                        if (previous_valid && (current_line == previous_line)) begin
                            if (hs_repeat_count < 4'd7)
                                hs_repeat_count <= hs_repeat_count + 1'b1;
                        end else
                            hs_repeat_count <= 4'd0;
                        previous_line  <= current_line;
                        previous_valid <= 1'b1;
                    end else begin
                        previous_valid  <= 1'b0;
                        hs_repeat_count <= 4'd0;
                    end
                end else begin
                    previous_valid  <= 1'b0;
                    hs_repeat_count <= 4'd0;
                end

                // ----- HS : no SYNC search after an EOP until the line is idle -----
                if (speed == HS) begin
                    if (line_se0)
                        hs_hold <= '0;                           // line idle: armed again
                    else if (hs_hold != '0)
                        hs_hold <= hs_hold - 1'b1;
                    if (eop_hit_hs)
                        hs_hold <= HOLD_W'(HS_HOLDOFF_MAX);
                end else
                    hs_hold <= '0;

                // ----- previous J/K symbol (for the lock-out below) -----
                last_valid <= is_jk;
                if (is_jk) last_sym <= current_line;

                // ----- SYNC search -----
                if (!sync_search_en || sop) begin
                    // inside a packet (data / EOP), draining, or the first data symbol:
                    // no SYNC search, any partial match is dropped
                    sync_count  <= 6'd0;
                    sync_active <= 1'b0;
                    sync_dead   <= 1'b0;
                end else if (line_se1 || line_se0) begin
                    if (sync_active && (sync_count >= 6'(SYNC_ERR_MIN)))
                        sync_error <= 1'b1;
                    sync_count  <= 6'd0;
                    sync_active <= 1'b0;
                    sync_dead   <= 1'b0;
                end else if (is_jk) begin
                    if (sync_dead) begin
                        // lock-out: ignore the rest of an alternating run that was too long;
                        // it ends when two equal symbols follow each other
                        if (last_valid && (current_line == last_sym))
                            sync_dead <= 1'b0;
                    end else if ((speed == HS) && (hs_hold != '0)) begin
                        // after an HS EOP and before the line is idle again: do not look for SYNC
                        sync_count  <= 6'd0;
                        sync_active <= 1'b0;
                    end else if (!sync_active) begin
                        if (line_k) begin
                            sync_active <= 1'b1;
                            sync_count  <= 6'd1;
                        end
                    end else if (sync_count[0]) begin
                        // odd count: next expected symbol is J
                        if (line_j) begin
                            if (sync_count >= sync_max) begin
                                // too many alternating symbols: not a SYNC
                                sync_error  <= 1'b1;
                                sync_count  <= 6'd0;
                                sync_active <= 1'b0;
                                sync_dead   <= 1'b1;
                            end else
                                sync_count <= sync_count + 1'b1;
                        end else if (sync_count >= sync_min) begin
                            // K after K: end of SYNC
                            sop         <= 1'b1;
                            sync_active <= 1'b0;
                            sync_count  <= 6'd0;
                        end else begin
                            // K too early: SYNC broken, this K may start a new SYNC
                            if (sync_count >= 6'(SYNC_ERR_MIN))
                                sync_error <= 1'b1;
                            sync_count <= 6'd1;
                        end
                    end else begin
                        // even count: next expected symbol is K
                        if (line_k) begin
                            sync_count <= sync_count + 1'b1;
                        end else begin
                            if (sync_count >= 6'(SYNC_ERR_MIN))
                                sync_error <= 1'b1;
                            sync_count  <= 6'd0;
                            sync_active <= 1'b0;
                        end
                    end
                end
                // an EOP always ends any partial SYNC match
                if (eop_hit) begin
                    sync_count  <= 6'd0;
                    sync_active <= 1'b0;
                end
            end
        end
    end
endmodule


