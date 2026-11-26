// file: piso.sv   (module usb_piso)
//
// Packet sequencer + parallel-in/phy_bfm-out.
//   IDLE -> SYNC -> DATA -> HOLD -> IDLE
//
//  * Starts only on a bit_tick, when the FIFO head is a SOP byte.
//  * SYNC (NRZ, LSB first, then NRZI-encoded downstream):
//        LS/FS : 0000_0001            -> KJKJKJKK            ( 8 bits)
//        HS    : 31 x 0 then 1        -> (KJ)x15 KK          (32 bits)
//  * SYNC and DATA are emitted back-to-back, one bit per bit_tick, with no
//    bubble.  The only thing that may pause the PISO is the bit stuffer
//    (stuff_ready = 0 while a stuffed '0' is being inserted).
//  * phy_bfm_sop  : tags the first SYNC bit
//    phy_bfm_last : tags the last real data bit of the packet
//  * After the last bit the PISO goes to HOLD and stays there until the
//    downstream EOP generator reports eop_done.  Nothing new can start
//    while the EOP is on the line.
//  * Underrun (FIFO empty / next byte is a SOP at a byte boundary and the
//    current byte was not flagged EOP) -> packet is terminated cleanly at
//    that byte boundary and 'underrun' pulses.
module usb_piso
#(
    parameter int WIDTH = 8
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             bit_tick,
    input  speed_t           usb_speed,

    // FIFO head
    input  logic             fifo_valid,
    input  logic [WIDTH-1:0] fifo_data,
    input  logic             fifo_sop,
    input  logic             fifo_eop,
    output logic             fifo_pop,        // 1-clk 

    // bit stuffer / EOP generator handshake
    input  logic             stuff_ready,     // 0 = stuffer inserting a 0
    input  logic             eop_done,        // EOP (+gap) finished

    // phy_bfm side (valid for the whole bit time, consumed on bit_tick)
    output logic             phy_bfm_out,
    output logic             phy_bfm_valid,
    output logic             phy_bfm_sop,
    output logic             phy_bfm_last,

    output logic             busy,
    output logic             underrun
);
    typedef enum logic [1:0] { IDLE, SYNC, DATA, HOLD } state_t;
    state_t state;

    localparam int CNT_W = $clog2(WIDTH);

    logic [5:0]       sync_cnt;
    logic [5:0]       sync_len;
    logic [WIDTH-1:0] sh;
    logic [CNT_W-1:0] bit_cnt;
    logic             cur_last;

    logic byte_end, adv, no_next;

    assign sync_len = (usb_speed == HS) ? 6'd32 : 6'd8;
    assign byte_end = (bit_cnt == CNT_W'(WIDTH-1));
    assign adv      = bit_tick && stuff_ready;
    // current byte is the last one of the packet, or the SIE ran dry
    assign no_next  = cur_last || !fifo_valid || fifo_sop;

    assign busy = (state != IDLE);

    //---------------- combinational phy_bfm outputs ----------------
    always_comb begin
        phy_bfm_out   = 1'b0;
        phy_bfm_valid = 1'b0;
        phy_bfm_sop   = 1'b0;
        phy_bfm_last  = 1'b0;
        unique case (state)
            SYNC: begin
                phy_bfm_valid = 1'b1;
                phy_bfm_out   = (sync_cnt == sync_len - 1'b1);  // last sync bit = 1
                phy_bfm_sop   = (sync_cnt == '0);
            end
            DATA: begin
                phy_bfm_valid = 1'b1;
                phy_bfm_out   = sh[0];
                phy_bfm_last  = byte_end && no_next;
            end
            default: ;
        endcase
    end

    //---------------- FIFO pop strobe ----------------
    always_comb begin
        fifo_pop = 1'b0;
        if (bit_tick && state == IDLE && fifo_valid)
            fifo_pop = 1'b1;                                   // start / flush stale byte
        else if (adv && state == DATA && byte_end && !no_next)
            fifo_pop = 1'b1;                                   // next byte of same packet
    end

    //---------------- sequencer ----------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            sync_cnt <= '0;
            sh       <= '0;
            bit_cnt  <= '0;
            cur_last <= 1'b0;
            underrun <= 1'b0;
        end else begin
            underrun <= 1'b0;

            if (bit_tick) begin
                unique case (state)
                    IDLE: begin
                        if (fifo_valid && fifo_sop) begin
                            sh       <= fifo_data;      // first data byte pre-loaded
                            cur_last <= fifo_eop;
                            bit_cnt  <= '0;
                            sync_cnt <= '0;
                            state    <= SYNC;
                        end
                        // a non-SOP head is simply popped (discarded) above
                    end

                    SYNC: if (stuff_ready) begin
                        if (sync_cnt == sync_len - 1'b1) begin
                            bit_cnt <= '0;
                            state   <= DATA;
                        end else
                            sync_cnt <= sync_cnt + 1'b1;
                    end

                    DATA: if (stuff_ready) begin
                        sh      <= sh >> 1;
                        bit_cnt <= bit_cnt + 1'b1;
                        if (byte_end) begin
                            if (no_next) begin
                                underrun <= !cur_last;
                                state    <= HOLD;      // last bit consumed
                            end else begin
                                sh       <= fifo_data;
                                cur_last <= fifo_eop;
                                bit_cnt  <= '0;
                            end
                        end
                    end

                    HOLD: if (eop_done)
                        state <= IDLE;
                endcase
            end
        end
    end
endmodule

