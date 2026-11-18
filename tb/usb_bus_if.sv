interface usb_bus_if(input logic clk);

  logic rst_n;

  logic device_dp;
  logic device_dm;
  logic device_oe;

  logic [1:0] phy_line_state;
  logic       phy_tx_valid;

  logic bit_tick;

  clocking cb_mon @(posedge clk);

    default input #1step;

    input rst_n;

    input device_dp;
    input device_dm;
    input device_oe;

    input phy_line_state;
    input phy_tx_valid;

    input bit_tick;

  endclocking

endinterface
