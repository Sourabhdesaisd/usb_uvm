//======================= bit unstuffer ==============================|
// file   : bit_unstuffer.sv
// Author : Santosh Bhosale
// Data   : 05/10/2026
//===================== Design Description ===========================|
// Removes the extra "0" that the transmitter inserts after six
// consecutive 1's, and flags a bit-stuffing error (stuff_err) when a
// seventh consecutive 1 is received.
//
// SYNC rule (USB 2.0 7.1.9.1): the final '1' of the SYNC pattern counts
// as the FIRST '1' of a run.  Therefore on 'sop' the run counter is
// loaded with 1 (not 0).  'sop' may arrive in an earlier clock than the
// first data bit, or in the same clock as it; both cases are handled.
//
// eop clears the run counter.
//====================================================================|
module usb2_bit_unstuffer #(parameter int UNSTUFF_POS=6)
(
    input  logic clk,
    input  logic rst_n,

    input  logic sop,
    input  logic eop,

    input  logic bit_in,
    input  logic bit_in_valid,

    output logic bit_out,
    output logic bit_out_valid,
    output logic stuff_err
);
    localparam int CNT_SIZE = $clog2(UNSTUFF_POS+1);
    logic [CNT_SIZE-1:0] one_count;
    logic [CNT_SIZE-1:0] cnt_eff;

    // run length seen so far, including the SYNC '1' when sop is present
    assign cnt_eff = sop ? CNT_SIZE'(1) : one_count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            one_count     <= '0;
            bit_out       <= 1'b0;
            bit_out_valid <= 1'b0;
            stuff_err     <= 1'b0;
        end
        else begin
            bit_out_valid <= 1'b0;
            stuff_err     <= 1'b0;

            if (sop)
                one_count <= CNT_SIZE'(1);

            if (bit_in_valid) begin
                if (cnt_eff == CNT_SIZE'(UNSTUFF_POS)) begin
                    if (bit_in == 1'b0) begin
                        // stuffed 0: discard
                        one_count <= '0;
                    end
                    else begin
                        // seventh consecutive 1: bit stuffing error, bit discarded,
                        // counter stays at UNSTUFF_POS (further 1s keep flagging)
                        stuff_err <= 1'b1;
                        one_count <= CNT_SIZE'(UNSTUFF_POS);
                    end
                end
                else begin
                    bit_out       <= bit_in;
                    bit_out_valid <= 1'b1;
                    one_count     <= bit_in ? cnt_eff + 1'b1 : '0;
                end
            end

            if (eop)
                one_count <= '0;
        end
    end
endmodule
 
