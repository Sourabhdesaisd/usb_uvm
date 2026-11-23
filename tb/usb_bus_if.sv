
interface usb_bus_if
(
    input logic clk
);

    // Reset
    logic rst_n;

    // External USB BFM/device drive controls
    logic device_dp;
    logic device_dm;
    logic device_oe;

    // DUT PHY transmitter outputs
    logic phy_dp;
    logic phy_dm;
    logic phy_tx_valid;

    // Shared USB physical bus
    tri bus_dp;
    tri bus_dm;

    // External device drives the bus when enabled
    assign bus_dp = (device_oe === 1'b1) ? device_dp : 1'bz;
    assign bus_dm = (device_oe === 1'b1) ? device_dm : 1'bz;

    // DUT PHY drives the bus during transmission
    assign bus_dp = (phy_tx_valid === 1'b1) ? phy_dp : 1'bz;
    assign bus_dm = (phy_tx_valid === 1'b1) ? phy_dm : 1'bz;

    // Actual DUT TX bit-tick observation.
    // This signal must be connected in tb_top.sv to the DUT's
    // internal bit_tick signal. Do not leave it unconnected.
    logic bit_tick;

    // USB BFM driver clocking block
    clocking cb_drv @(posedge clk);
        default input #1step output #0;

        input rst_n;

        output device_dp;
        output device_dm;
        output device_oe;
    endclocking

    // USB bus monitor clocking block
    clocking cb_mon @(posedge clk);
        default input #1step;

        input rst_n;

        input device_dp;
        input device_dm;
        input device_oe;

        input phy_dp;
        input phy_dm;
        input phy_tx_valid;

        input bus_dp;
        input bus_dm;

        input bit_tick;
    endclocking

endinterface

