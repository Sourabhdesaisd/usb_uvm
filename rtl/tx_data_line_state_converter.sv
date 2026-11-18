// file: tx_line_state_converter.sv
// NRZI symbol (1 = J, 0 = K) -> {DP,DM}
//   FS / HS : J = DP1 DM0 (2'b10)   K = DP0 DM1 (2'b01)
//   LS      : J = DP0 DM1 (2'b01)   K = DP1 DM0 (2'b10)   (inverted)
module tx_line_state_converter
(
    input  logic       nrzi_bit,
    input  logic       nrzi_valid,
    input  speed_t     usb_speed,

    output logic [1:0] line_state,   // {DP, DM}
    output logic       line_valid
);
    logic [1:0] j_state;
    assign j_state    = (usb_speed == LS) ? 2'b01 : 2'b10;
    assign line_state = nrzi_bit ? j_state : ~j_state;
    assign line_valid = nrzi_valid;
endmodule

