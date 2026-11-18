//============ NRZI Decoder ========================|
// File   : usb_nrzi_decoder.sv
// Author : Santosh Bhosale
// Data   : 25/09/2026
//====== design description ========================|
// decodes the encoded data at receiver side
// means the output will be:
// 1 --> same level
// 0 --> level changes
//
// Input convention : nrzi_enc_in = 1 for J, 0 for K  (only J/K symbols are
//                    presented; SE0/SE1 are never fed to this block).
// sop / eop timing : sop must be presented in the SAME clock as the LAST
//                    SYNC symbol (a K).  That symbol is not decoded; it only
//                    loads the reference level (K = 0).  The first data
//                    symbol that follows is therefore decoded against K.
//                    eop must be presented in the same clock as the first
//                    symbol that must NOT be decoded.
//                    (phy_rx_top / usb2_rx_ctrl guarantee this alignment.)
//==================================================|
module usb2_nrzi_decoder (
    input  logic clk,
    input  logic rst_n,
    input  logic sop,
    input  logic eop,

    input  logic nrzi_enc_in,
    input  logic nrzi_enc_valid,

    output logic nrzi_dec_out,
    output logic data_valid
);

    logic nrzi_prev;
    logic packet_active;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nrzi_prev     <= 1'b0;
            packet_active <= 1'b0;
            nrzi_dec_out  <= 1'b0;
            data_valid    <= 1'b0;
        end
        else begin
            data_valid <= 1'b0;

            if (sop) begin
                nrzi_prev     <= 1'b0; // reference = last SYNC symbol = K (J=1, K=0)
                packet_active <= 1'b1;
            end
            else if (eop) begin
                packet_active <= 1'b0;
            end
            else if (packet_active && nrzi_enc_valid) begin
                // Same level = 1, transition = 0
                nrzi_dec_out <= ~(nrzi_enc_in ^ nrzi_prev);

                nrzi_prev  <= nrzi_enc_in;
                data_valid <= 1'b1;
            end
        end
    end

endmodule

 
