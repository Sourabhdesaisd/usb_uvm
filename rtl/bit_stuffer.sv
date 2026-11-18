// file: bit_stuffer.sv   (module usb2_bit_stuffer)
//
// Inserts a '0' after six consecutive '1's (USB 2.0 7.1.9.1).
//  * SYNC goes through the stuffer, so the final '1' of SYNC counts as the
//    first '1' of a run, exactly as the spec requires.
//  * A stuffed '0' is inserted even if it is the very last bit before EOP.
//    The 'last' tag then moves onto the stuffed bit (last_held), so the EOP
//    generator always starts after the stuffed bit.
//  * bit_in_ready = 0 while a stuffed bit is being sent: the PISO simply
//    holds its current bit (nothing is lost, no bubble).
//  * Purely combinational path + one counter; advances only on bit_tick.
module usb2_bit_stuffer (
    input  logic clk,
    input  logic rst_n,
    input  logic bit_tick,

    input  logic bit_in,
    input  logic bit_in_valid,
    input  logic bit_in_sop,
    input  logic bit_in_last,
    output logic bit_in_ready,

    output logic bit_out,
    output logic bit_out_valid,
    output logic bit_out_sop,
    output logic bit_out_last
);
    logic [2:0] ones_count;
    logic       last_held;       // the 6th '1' was the last bit of the packet
    logic       stuff_now;
    logic       will_stuff;      // this bit is the 6th '1' -> a stuffed 0 must follow

    assign stuff_now    = (ones_count == 3'd6);
    assign will_stuff   = bit_in && (ones_count == 3'd5);
    assign bit_in_ready = !stuff_now;

    assign bit_out       = stuff_now ? 1'b0      : bit_in;
    assign bit_out_valid = stuff_now ? 1'b1      : bit_in_valid;
    assign bit_out_sop   = !stuff_now && bit_in_sop;
    // if a stuffed 0 must follow, the tag is NOT given to this bit but to the stuffed one
    assign bit_out_last  = stuff_now ? last_held
                                     : (bit_in_valid && bit_in_last && !will_stuff);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ones_count <= '0;
            last_held  <= 1'b0;
        end else if (bit_tick) begin
            if (stuff_now) begin
                ones_count <= '0;
                last_held  <= 1'b0;
            end else if (bit_in_valid) begin
                ones_count <= bit_in ? ones_count + 1'b1 : 3'd0;
                last_held  <= bit_in_last;
            end
        end
    end
endmodule
 
