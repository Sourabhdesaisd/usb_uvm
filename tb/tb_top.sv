
module tb_top;

         
  // PACKAGE IMPORTS
         

  import uvm_pkg::*;
  import usb_phy_tb_pkg::*;


         
  // CLOCK
         

  logic clk;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end


         
  // INTERFACE INSTANCES
         

  usb_phy_if phy_if(clk);

  usb_bus_if usb_if(clk);


         
  // RESET AND INITIAL CONFIGURATION
         

  initial begin

    // Initial reset
    phy_if.rst_n = 1'b0;

    // Initialize USB speed to reserved (2'b11)
    // The PHY driver will configure the selected speed.
    phy_if.usb_speed = '1;

    // Initialize USB BFM interface reset
    usb_if.rst_n = 1'b0;

    // Wait for reset duration
    #100;

    // Release reset
    phy_if.rst_n = 1'b1;
    usb_if.rst_n = 1'b1;

  end


         
  // PASS VIRTUAL INTERFACES TO UVM
         

  initial begin

    // PHY virtual interface
    uvm_config_db#(virtual usb_phy_if)::set(
      null,
      "uvm_test_top",
      "phy_vif",
      phy_if
    );

    // USB bus virtual interface
    uvm_config_db#(virtual usb_bus_if)::set(
      null,
      "uvm_test_top",
      "usb_vif",
      usb_if
    );

    // Start UVM
    run_test();

  end


         
  // DUT INSTANTIATION
         

  phy_top dut (

    // Clock and reset
    .clk             (clk),
    .rst_n           (phy_if.rst_n),
    .usb_speed       (phy_if.usb_speed),

    // Physical TX outputs
    .dp              (phy_if.dp),
    .dm              (phy_if.dm),
    .tx_valid        (phy_if.tx_valid),

    // CDR / analog-front-end inputs
    .analog_d_plus   (phy_if.analog_d_plus),
    .analog_d_minus  (phy_if.analog_d_minus),
    .analog_enable   (phy_if.analog_enable),
    .analog_serial   (phy_if.analog_serial),

    // SIE TX inputs
    .sof_packet      (phy_if.sof_packet),
    .sie_data        (phy_if.sie_data),
    .sie_valid       (phy_if.sie_valid),
    .sie_sop         (phy_if.sie_sop),
    .sie_eop         (phy_if.sie_eop),
    .sie_ready       (phy_if.sie_ready),

    // SIE RX outputs
    .DataOut         (phy_if.DataOut),
    .RxValid         (phy_if.RxValid),
    .RxActive        (phy_if.RxActive),
    .RxError         (phy_if.RxError),
    .LineState       (phy_if.LineState),

    // RX packet markers
    .rx_sop          (phy_if.rx_sop),
    .rx_eop          (phy_if.rx_eop),

    // RX status
    .rx_stuff_err    (phy_if.rx_stuff_err),
    .rx_align_err    (phy_if.rx_align_err),
    .rx_line_err     (phy_if.rx_line_err),
    .rx_babble_err   (phy_if.rx_babble_err),
    .rx_sync_err     (phy_if.rx_sync_err),
    .rx_bus_reset    (phy_if.rx_bus_reset)

  );

endmodule

