
interface usb_bus_if (
  input logic clk
);

  // --------------------------------------------------
  // Reset
  // --------------------------------------------------

  logic rst_n;


  // --------------------------------------------------
  // External USB BFM / device driver
  // --------------------------------------------------

  logic device_dp;
  logic device_dm;
  logic device_oe;


  // --------------------------------------------------
  // DUT PHY transmitter outputs
  // --------------------------------------------------

  logic phy_dp;
  logic phy_dm;
  logic phy_tx_valid;


  // --------------------------------------------------
  // Shared USB physical bus
  // --------------------------------------------------

  tri bus_dp;
  tri bus_dm;


  // --------------------------------------------------
  // External USB BFM drives the bus
  // --------------------------------------------------

  assign bus_dp =
    (device_oe === 1'b1) ? device_dp : 1'bz;

  assign bus_dm =
    (device_oe === 1'b1) ? device_dm : 1'bz;


  // --------------------------------------------------
  // DUT PHY drives the bus
  // --------------------------------------------------

  assign bus_dp =
    (phy_tx_valid === 1'b1) ? phy_dp : 1'bz;

  assign bus_dm =
    (phy_tx_valid === 1'b1) ? phy_dm : 1'bz;


  // --------------------------------------------------
  // Contention detection
  // --------------------------------------------------

  logic bus_contention;

  always_comb begin

    bus_contention = 1'b0;

    if ((device_oe === 1'b1) &&
        (phy_tx_valid === 1'b1)) begin

      bus_contention = 1'b1;

    end

  end


  // --------------------------------------------------
  // TX bit tick observation
  // --------------------------------------------------

  // Connect this signal in tb_top to the DUT internal
  // bit_tick signal if the RTL hierarchy exposes it.
  //
  // This is an observation signal only.
  logic bit_tick;


  // --------------------------------------------------
  // USB BFM driver clocking block
  // --------------------------------------------------

  clocking cb_drv @(posedge clk);

    default input #1step output #0;

    // Reset observation
    input rst_n;

    // External device controls
    output device_dp;
    output device_dm;
    output device_oe;

  endclocking


  // --------------------------------------------------
  // USB bus monitor clocking block
  // --------------------------------------------------

  clocking cb_mon @(posedge clk);

    default input #1step;

    // Reset
    input rst_n;

    // External device driver
    input device_dp;
    input device_dm;
    input device_oe;

    // DUT PHY transmitter
    input phy_dp;
    input phy_dm;
    input phy_tx_valid;

    // Resolved USB bus
    input bus_dp;
    input bus_dm;

    // Contention status
    input bus_contention;

    // TX timing observation
    input bit_tick;

  endclocking


  // --------------------------------------------------
  // Modports
  // --------------------------------------------------

  modport USB_BFM_DRIVER (
    clocking cb_drv,
    input clk
  );

  modport USB_BFM_MONITOR (
    clocking cb_mon,
    input clk
  );


endinterface

