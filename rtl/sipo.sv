//======================== SIPO ===================================|
// File   : sipo.sv
// Author : Santosh Bhosale
// Data   : 14/09/2026
//==================== Design Description =========================|
// Serial-In Parallel-Out.  Collects phy_bfm_valid bits (LSB first) and
// gives a WIDTH-bit word with a 1-clock parallel_valid.
//
// Added for the RX path (existing ports are unchanged):
//   clear         : resets the bit counter at the start of every packet,
//                   so leftover bits of the previous packet (for example
//                   the 7 HS-EOP bits) can never misalign the next one
//   bit_count_out : number of bits already shifted into the word being
//                   assembled; the RX controller uses it for the
//                   byte-alignment (dribble) check at EOP
//=================================================================|
module usb_sipo #(
    parameter WIDTH = 8
)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 phy_bfm_in,
    input  logic                 phy_bfm_valid,
    output logic [WIDTH-1:0]     parallel_out,
    output logic                 parallel_valid,
    output logic                 busy,
    // new ports
    input  logic                 clear,
    output logic [$clog2(WIDTH)-1:0] bit_count_out
);

    logic [WIDTH-1:0]            shift_reg;
    logic [$clog2(WIDTH)-1:0]    bit_count;

    assign bit_count_out = bit_count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg      <= '0;
            parallel_out   <= '0;
            parallel_valid <= 1'b0;
            bit_count      <= '0;
            busy           <= 1'b0;
        end
        else begin
            parallel_valid <= 1'b0;

            if (clear) begin
                bit_count <= '0;
                busy      <= 1'b0;
            end
            else if (phy_bfm_valid) begin
                busy      <= 1'b1;
                shift_reg <= {phy_bfm_in, shift_reg[WIDTH-1:1]};

                if (bit_count == WIDTH-1) begin
                    parallel_out   <= {phy_bfm_in, shift_reg[WIDTH-1:1]};
                    parallel_valid <= 1'b1;
                    bit_count      <= '0;
                end
                else begin
                    bit_count      <= bit_count + 1'b1;
                end
            end
            else begin
                busy <= 1'b0;
            end
        end
    end

endmodule
 
