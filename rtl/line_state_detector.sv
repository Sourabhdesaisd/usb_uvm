module usb2_rx_line_state_detector
    import usb_phy_pkg::*;
(
    input  logic d_plus,
    input  logic d_minus,
    input  speed_t speed,

    output logic line_j,
    output logic line_k,
    output logic line_se0,
    output logic line_se1
);

    always_comb begin
        line_j   = 1'b0;
        line_k   = 1'b0;
        line_se0 = 1'b0;
        line_se1 = 1'b0;

        if (d_plus == 1'b0 && d_minus == 1'b0) begin
            line_se0 = 1'b1;
        end
        else if (d_plus == 1'b1 && d_minus == 1'b1) begin
            line_se1 = 1'b1;
        end
        else begin
            // J/K polarity:
            // Full-Speed and High-Speed: J=10, K=01
            // Low-Speed:                  J=01, K=10
            if (speed==LS) begin
                line_j = !d_plus && d_minus;
                line_k = d_plus && !d_minus;
            end
            else begin
                line_j = d_plus && !d_minus;
                line_k = !d_plus && d_minus;
            end
        end
    end

endmodule
 
 
