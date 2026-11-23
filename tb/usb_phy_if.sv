
interface usb_phy_if #(
  parameter int WIDTH = 8
)(
  input logic clk
);

  import usb_phy_pkg::*;

  logic rst_n;
  speed_t usb_speed;

  // SIE to PHY TX
  logic             sof_packet;
  logic [WIDTH-1:0] sie_data;
  logic             sie_valid;
  logic             sie_sop;
  logic             sie_eop;
  logic             sie_ready;

  // PHY TX outputs
  logic dp;
  logic dm;
  logic tx_valid;

  // External USB partner to CDR
  logic analog_d_plus;
  logic analog_d_minus;
  logic analog_enable;
  logic analog_serial;

  // PHY RX outputs
  logic [WIDTH-1:0] DataOut;
  logic             RxValid;
  logic             RxActive;
  logic             RxError;
  logic [1:0]       LineState;

  logic rx_sop;
  logic rx_eop;

  // RX status outputs actually present in phy_top
  logic rx_stuff_err;
  logic rx_align_err;
  logic rx_line_err;
  logic rx_sync_err;
  logic rx_bus_reset;

  // PHY driver clocking block
  clocking cb_drv @(posedge clk);
    default input #1step output #0;

    input rst_n;
    input sie_ready;

    output usb_speed;
    output sof_packet;
    output sie_data;
    output sie_valid;
    output sie_sop;
    output sie_eop;
  endclocking

  // External partner CDR driver
  clocking cb_bfm_drv @(posedge clk);
    default input #1step output #0;

    input rst_n;

    output analog_enable;
    output analog_serial;
  endclocking

  // Monitor clocking block
  clocking cb_mon @(posedge clk);
    default input #1step;

    input rst_n;
    input usb_speed;

    input sof_packet;
    input sie_data;
    input sie_valid;
    input sie_sop;
    input sie_eop;
    input sie_ready;

    input dp;
    input dm;
    input tx_valid;

    input analog_d_plus;
    input analog_d_minus;
    input analog_enable;
    input analog_serial;

    input DataOut;
    input RxValid;
    input RxActive;
    input RxError;
    input LineState;

    input rx_sop;
    input rx_eop;

    input rx_stuff_err;
    input rx_align_err;
    input rx_line_err;
    input rx_sync_err;
    input rx_bus_reset;
  endclocking

endinterface

