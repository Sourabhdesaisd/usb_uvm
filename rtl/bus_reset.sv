// file: rx_reset_detect.sv   (module usb2_rx_reset_detect)  
//
// Bus-reset (long SE0) detector for LS / FS operation.
//
// USB 2.0 7.1.7.5: a device operating in low-/full-speed mode that sees an SE0 on its
// upstream port for more than 2.5 us (TDETRST) may treat it as a reset (the host drives
// the reset SE0 for >= 10 ms; a normal EOP has only ~2 bit times of SE0).
//
//   bus_reset = 1 while the line has been SE0 CONTINUOUSLY for RESET_SE0_NS (default 2500 ns).
//   It falls as soon as the line leaves SE0.
//
// It runs on the raw (continuous) d_plus / d_minus levels, not on the bit samples,
// and it runs also while no packet is active (reset normally happens on an idle bus).
//
// HS operation: the HS idle state is SE0, so a long SE0 is NOT a reset indication there.
// bus_reset stays 0 in HS.  A HS device detects reset by reverting to FS termination after
// 3.0 - 3.125 ms of idle and then looking for SE0 (7.1.7.5); that sequence belongs to the
// PHY / SIE control, and once XcvrSelect = FS this block works.
module usb2_rx_reset_detect
    import usb_phy_pkg::*;
#(
    parameter int CLK_HZ       = 480_000_000,
    parameter int RESET_SE0_NS = 2500
)(
    input  logic   clk,
    input  logic   rst_n,
    input  speed_t speed,
    input  logic   d_plus,
    input  logic   d_minus,
    output logic   bus_reset
);
    localparam int RESET_CLKS = ((CLK_HZ / 1_000_000) * RESET_SE0_NS) / 1000;   // 1200 at 480 MHz
    localparam int CNT_W      = $clog2(RESET_CLKS + 1);

    logic             se0;
    logic [CNT_W-1:0] cnt;

    assign se0 = ~d_plus & ~d_minus;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt       <= '0;
            bus_reset <= 1'b0;
        end else if ((speed == HS) || !se0) begin
            cnt       <= '0;
            bus_reset <= 1'b0;
        end else begin
            if (cnt != CNT_W'(RESET_CLKS))
                cnt <= cnt + 1'b1;
            if (cnt == CNT_W'(RESET_CLKS - 1))
                bus_reset <= 1'b1;
        end
    end
endmodule

