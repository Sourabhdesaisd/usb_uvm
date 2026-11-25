
interface usb_phy_if #(
  parameter int WIDTH = 8
)(
  input logic clk
);

  import usb_phy_pkg::*;

  // --------------------------------------------------
  // Reset and USB speed
  // --------------------------------------------------

  logic rst_n;
  speed_t usb_speed;


  // --------------------------------------------------
  // SIE TX interface
  // PHY driver -> DUT
  // --------------------------------------------------

  logic             sof_packet;
  logic [WIDTH-1:0] sie_data;
  logic             sie_valid;
  logic             sie_sop;
  logic             sie_eop;
  logic             sie_ready;


  // --------------------------------------------------
  // PHY TX physical outputs
  // DUT -> USB bus
  // --------------------------------------------------

  logic dp;
  logic dm;
  logic tx_valid;


  // --------------------------------------------------
  // Analog receiver / CDR inputs
  // USB BFM -> DUT
  // --------------------------------------------------

  logic analog_d_plus;
  logic analog_d_minus;
  logic analog_enable;
  logic analog_enable_req; // Testbench request, suppressed during local TX.
  logic analog_serial;


  // --------------------------------------------------
  // SIE RX interface
  // DUT -> monitor / scoreboard
  // --------------------------------------------------

  logic [WIDTH-1:0] DataOut;

  logic RxValid;
  logic RxActive;
  logic RxError;

  logic [1:0] LineState;

  logic rx_sop;
  logic rx_eop;


  // --------------------------------------------------
  // Optional RX status outputs
  // --------------------------------------------------

  logic rx_stuff_err;
  logic rx_align_err;
  logic rx_line_err;
  logic rx_sync_err;
  logic rx_bus_reset;


  // --------------------------------------------------
  // PHY TX driver clocking block
  // --------------------------------------------------

  clocking cb_drv @(posedge clk);

    default input #1step output #0;

    // Driver observes
    input rst_n;
    input sie_ready;

    // Driver controls
    output usb_speed;

    output sof_packet;
    output sie_data;
    output sie_valid;
    output sie_sop;
    output sie_eop;

  endclocking


  // --------------------------------------------------
  // USB BFM analog driver clocking block
  // --------------------------------------------------

  clocking cb_bfm_drv @(posedge clk);

    default input #1step output #0;

    // Observe reset
    input rst_n;

    // Control analog receiver
    output analog_enable_req;

  endclocking


  // --------------------------------------------------
  // PHY monitor clocking block
  // --------------------------------------------------

  clocking cb_mon @(posedge clk);

    default input #1step;

    // Reset and speed
    input rst_n;
    input usb_speed;

    // SIE TX handshake
    input sof_packet;
    input sie_data;
    input sie_valid;
    input sie_sop;
    input sie_eop;
    input sie_ready;

    // PHY TX outputs
    input dp;
    input dm;
    input tx_valid;

    // Analog receiver inputs
    input analog_d_plus;
    input analog_d_minus;
    input analog_enable;
    input analog_serial;

    // SIE RX outputs
    input DataOut;
    input RxValid;
    input RxActive;
    input RxError;
    input LineState;

    // RX packet markers
    input rx_sop;
    input rx_eop;

    // RX status
    input rx_stuff_err;
    input rx_align_err;
    input rx_line_err;
    input rx_sync_err;
    input rx_bus_reset;

  endclocking


  // --------------------------------------------------
  // Modports
  // --------------------------------------------------

  modport PHY_DRIVER (
    clocking cb_drv,
    input clk
  );

  modport USB_BFM_DRIVER (
    clocking cb_bfm_drv,
    input clk
  );

  modport PHY_MONITOR (
    clocking cb_mon,
    input clk
  );


endinterface


