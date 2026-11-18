// file: usb_tx_line_mux.sv
// EOP has priority over data.  When neither is valid the driver is
// released (tx_valid = 0) and the idle level is the speed-correct one.
module usb_tx_line_mux
(
    input  speed_t     usb_speed,

    input  logic [1:0] data_line_state,
    input  logic       data_valid,

    input  logic [1:0] eop_line_state,
    input  logic       eop_valid,

    output logic [1:0] tx_line_state,
    output logic       tx_valid
);
    always_comb begin
        if (eop_valid) begin
            tx_line_state = eop_line_state;
            tx_valid      = 1'b1;
        end else if (data_valid) begin
            tx_line_state = data_line_state;
            tx_valid      = 1'b1;
        end else begin
            tx_valid = 1'b0;
            unique case (usb_speed)
                LS:      tx_line_state = 2'b01;   // idle J (LS)
                FS:      tx_line_state = 2'b10;   // idle J (FS)
                default: tx_line_state = 2'b00;   // HS idle = SE0
            endcase
        end
    end
endmodule

