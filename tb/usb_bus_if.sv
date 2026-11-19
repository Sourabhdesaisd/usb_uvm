

interface usb_bus_if(input logic clk);

          
  // 1. RESET
          

  logic rst_n;


          
  // 2. EXTERNAL USB PARTNER DRIVE
          

  logic device_dp;
  logic device_dm;
  logic device_oe;


          
  // 3. DUT PHYSICAL TX OBSERVATIONS
          

  logic phy_dp;
  logic phy_dm;
  logic phy_tx_valid;


          
  // 4. RESOLVED USB BUS
          

  tri bus_dp;
  tri bus_dm;

  // External USB partner drives the bus
  assign bus_dp = (device_oe === 1'b1) ?
                  device_dp : 1'bz;

  assign bus_dm = (device_oe === 1'b1) ?
                  device_dm : 1'bz;

  // DUT PHY drives the bus during valid TX
  assign bus_dp = (phy_tx_valid === 1'b1) ?
                  phy_dp : 1'bz;

  assign bus_dm = (phy_tx_valid === 1'b1) ?
                  phy_dm : 1'bz;


          
  // 5. USB BIT TIMING
          

 logic bit_tick = 1'b0;

          
  // 6. EXTERNAL USB PARTNER DRIVER CLOCKING BLOCK
          

  clocking cb_drv @(posedge clk);

    default input #1step output #0;

    input rst_n;
    input bit_tick;

    output device_dp;
    output device_dm;
    output device_oe;

  endclocking


          
  // 7. USB BUS MONITOR CLOCKING BLOCK
          

  clocking cb_mon @(posedge clk);

    default input #1step;

    input rst_n;

    // External partner
    input device_dp;
    input device_dm;
    input device_oe;

    // DUT TX
    input phy_dp;
    input phy_dm;
    input phy_tx_valid;

    // Resolved bus
    input bus_dp;
    input bus_dm;

    // Timing
    input bit_tick;

  endclocking

endinterface

