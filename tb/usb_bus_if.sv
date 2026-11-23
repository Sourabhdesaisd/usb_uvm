
interface usb_bus_if(input logic clk);

  logic rst_n;

  // External USB partner
  logic device_dp;
  logic device_dm;
  logic device_oe;

  // DUT PHY TX outputs
  logic phy_dp;
  logic phy_dm;
  logic phy_tx_valid;

  // Resolved USB bus
  tri bus_dp;
  tri bus_dm;

  // External partner drives the bus
  assign bus_dp = (device_oe === 1'b1) ? device_dp : 1'bz;
  assign bus_dm = (device_oe === 1'b1) ? device_dm : 1'bz;

  // DUT drives the bus during TX
  assign bus_dp = (phy_tx_valid === 1'b1) ? phy_dp : 1'bz;
  assign bus_dm = (phy_tx_valid === 1'b1) ? phy_dm : 1'bz;

  // Connected to the actual DUT TX bit tick in tb_top
  logic bit_tick;

  clocking cb_drv @(posedge clk);
    default input #1step output #0;

    input rst_n;
    input bit_tick;

    output device_dp;
    output device_dm;
    output device_oe;
  endclocking

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

