interface usb_bus_if (
  input logic clk
);

  // ==================================================
  // RESET
  // ==================================================

  logic rst_n;


  // ==================================================
  // EXTERNAL USB BFM DRIVER
  // ==================================================

  logic device_dp;
  logic device_dm;
  logic device_oe;


  // ==================================================
  // DUT PHY TRANSMITTER
  // ==================================================

  logic phy_dp;
  logic phy_dm;
  logic phy_tx_valid;


  // ==================================================
  // SHARED USB BUS
  // ==================================================

  tri bus_dp;
  tri bus_dm;


  // ==================================================
  // EXTERNAL BFM BUS DRIVER
  // ==================================================

  assign bus_dp =
    (device_oe === 1'b1) ? device_dp : 1'bz;

  assign bus_dm =
    (device_oe === 1'b1) ? device_dm : 1'bz;


  // ==================================================
  // DUT PHY BUS DRIVER
  // ==================================================

  assign bus_dp =
    (phy_tx_valid === 1'b1) ? phy_dp : 1'bz;

  assign bus_dm =
    (phy_tx_valid === 1'b1) ? phy_dm : 1'bz;


  // ==================================================
  // BUS OWNERSHIP AND CONTENTION
  // ==================================================

  logic bus_contention;

  always_comb begin

    bus_contention = 1'b0;

    if ((device_oe === 1'b1) &&
        (phy_tx_valid === 1'b1)) begin

      bus_contention = 1'b1;

    end

  end


  // ==================================================
  // TX BIT TICK OBSERVATION
  // ==================================================

  logic bit_tick;


  // ==================================================
  // USB BFM DRIVER CLOCKING BLOCK
  // ==================================================

  clocking cb_drv @(posedge clk);

    default input #1step output #0;

    input rst_n;

    output device_dp;
    output device_dm;
    output device_oe;

  endclocking


  // ==================================================
  // USB BUS MONITOR CLOCKING BLOCK
  // ==================================================

  clocking cb_mon @(posedge clk);

    default input #1step;

    input rst_n;

    // External BFM driver
    input device_dp;
    input device_dm;
    input device_oe;

    // DUT driver
    input phy_dp;
    input phy_dm;
    input phy_tx_valid;

    // Resolved USB bus
    input bus_dp;
    input bus_dm;

    // Bus status
    input bus_contention;

    // TX timing
    input bit_tick;

  endclocking


  // ==================================================
  // MODPORTS
  // ==================================================

  modport USB_BFM_DRIVER (
    clocking cb_drv,
    input clk
  );

  modport USB_BFM_MONITOR (
    clocking cb_mon,
    input clk
  );

endinterface
