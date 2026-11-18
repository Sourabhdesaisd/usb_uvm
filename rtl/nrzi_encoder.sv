// file: nrzi_encoder_1.sv   (module usb_nrzi_encoder)
//
// NRZI:  0 -> toggle,  1 -> hold.   Output symbol: 1 = J, 0 = K.
//  * At SOP the reference state is forced to J (bus idle), so the first SYNC
//    bit is always K.  This replaces the old force_idle hack.
//  * One output register stage: nrzi_out / valid / last are what is on the
//    line during the current bit time.
//  * When no bit is presented (end of packet, EOP being sent) valid/last
//    drop and the encoder simply holds nrzi_out / nrzi_state.
//    nrzi_out is therefore still the LAST data symbol while EOP starts
//    (the EOP generator uses it for the HS EOP polarity).
module usb_nrzi_encoder (
    input  logic clk,
    input  logic rst_n,
    input  logic bit_tick,

    input  logic bit_in,
    input  logic bit_in_valid,
    input  logic bit_in_sop,
    input  logic bit_in_last,

    output logic nrzi_out,
    output logic nrzi_out_valid,
    output logic nrzi_out_last
);
    logic nrzi_state;            // 1 = J, 0 = K
    logic prev, nxt;

    assign prev = bit_in_sop ? 1'b1 : nrzi_state;
    assign nxt  = bit_in ? prev : ~prev;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nrzi_state     <= 1'b1;
            nrzi_out       <= 1'b1;
            nrzi_out_valid <= 1'b0;
            nrzi_out_last  <= 1'b0;
        end else if (bit_tick) begin
            nrzi_out_valid <= bit_in_valid;
            nrzi_out_last  <= bit_in_valid && bit_in_last;
            if (bit_in_valid) begin
                nrzi_state <= nxt;
                nrzi_out   <= nxt;
            end
        end
    end
endmodule

