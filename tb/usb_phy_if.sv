
interface usb_phy_if(input logic clk);

  // Reset
  logic rst_n;

  // USB speed configuration
  logic [1:0] usb_speed;

  // SIE inputs
  logic       sie_valid;
  logic [7:0] sie_data;
  logic       sop;
  logic       eop;
  logic       sof_packet;

  // SIE output
  logic sie_ready;

  // TX outputs
  logic [1:0] tx_line_state;
  logic       tx_valid;

  // RX inputs
  logic rx_dp;
  logic rx_dm;

  // RX outputs
  logic [7:0] Rx_data;
  logic       Rx_valid;
  logic [1:0] line_state;


  // Driver clocking block
  clocking cb_drv @(posedge clk);

    default input #1step output #0;

    input rst_n;
    input sie_ready;

    output usb_speed;

    output sie_valid;
    output sie_data;
    output sop;
    output eop;
    output sof_packet;

  endclocking


  // Monitor clocking block
  clocking cb_mon @(posedge clk);

    default input #1step;

    input rst_n;
    input usb_speed;

    input sie_valid;
    input sie_data;
    input sie_ready;
    input sop;
    input eop;
    input sof_packet;

    input tx_line_state;
    input tx_valid;

    input rx_dp;
    input rx_dm;

    input Rx_data;
    input Rx_valid;
    input line_state;

  endclocking

endinterface
