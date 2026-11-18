module tb_top;

  import uvm_pkg::*;
  import usb_phy_pkg::*;

  logic clk;

  // ------------------------------------------------------------
  // Clock generation
  // ------------------------------------------------------------
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

 // Interface instances
  usb_phy_if phy_if(clk);
  usb_bus_if usb_if(clk);
  // ------------------------------------------------------------
  // Reset and initial speed
  // ------------------------------------------------------------
  initial begin
    phy_if.rst_n       = 1'b0;
    phy_if.usb_speed   = usb_phy_if::USB_SPEED_RESERVED;

    #100;
    phy_if.rst_n       = 1'b1;
  end

  // ------------------------------------------------------------
  // Pass virtual interface to UVM
  // ------------------------------------------------------------
  initial begin

       // Set virtual interfaces for the UVM test
    uvm_config_db#(virtual usb_phy_if)::set(
      null,
      "uvm_test_top",
      "phy_vif",
      phy_if
    );

    uvm_config_db#(virtual usb_bus_if)::set(
      null,
      "uvm_test_top",
      "usb_vif",
      usb_if
    );
    run_test();

  end

  // ------------------------------------------------------------
  // DUT instance
  // Replace module and port names with actual RTL names.
  // ------------------------------------------------------------
  usb2_phy_top dut (
    .clk            (clk),
    .rst_n          (phy_if.rst_n),
    .usb_speed      (phy_if.usb_speed),

    .sof_packet     (phy_if.sof_packet),
    .sie_valid      (phy_if.sie_valid),
    .sie_data       (phy_if.sie_data),
    .sop            (phy_if.sop),
    .eop            (phy_if.eop),
    .sie_ready      (phy_if.sie_ready),

    .tx_line_state  (phy_if.tx_line_state),
    .tx_valid       (phy_if.tx_valid),

    .rx_dp          (phy_if.rx_dp),
    .rx_dm          (phy_if.rx_dm),

    .Rx_data        (phy_if.Rx_data),
    .Rx_valid       (phy_if.Rx_valid),
    .line_state     (phy_if.line_state)
  );

endmodule
