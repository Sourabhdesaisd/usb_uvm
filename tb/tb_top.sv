
module tb_top;

  import uvm_pkg::*;
  import usb_phy_tb_pkg::*;

  logic clk;

  // 480 MHz clock: period approximately 2.083334 ns
  initial begin
    clk = 1'b0;
    forever #1.041667 clk = ~clk;
  end

  // Interfaces
  usb_phy_if phy_if(clk);
  usb_bus_if usb_if(clk);

  // Reset and initial configuration
  initial begin

    phy_if.rst_n = 1'b0;
    phy_if.usb_speed = usb_phy_pkg::LS;

    phy_if.sof_packet = 1'b0;
    phy_if.sie_data   = '0;
    phy_if.sie_valid  = 1'b0;
    phy_if.sie_sop    = 1'b0;
    phy_if.sie_eop    = 1'b0;

    phy_if.analog_enable = 1'b0;
    phy_if.analog_serial = 1'b0;

    usb_if.device_oe = 1'b0;
    usb_if.device_dp = 1'b0;
    usb_if.device_dm = 1'b0;

    #100;

    phy_if.rst_n = 1'b1;

  end

  // Common reset
  assign usb_if.rst_n = phy_if.rst_n;

  // DUT TX to USB bus
  assign usb_if.phy_dp       = phy_if.dp;
  assign usb_if.phy_dm       = phy_if.dm;
  assign usb_if.phy_tx_valid = phy_if.tx_valid;

  // USB bus to DUT CDR
  assign phy_if.analog_d_plus  = usb_if.bus_dp;
  assign phy_if.analog_d_minus = usb_if.bus_dm;

  // DUT TX bit-tick connection for verification
  //
  // IMPORTANT:
  // Confirm that phy_tx_top declares a signal named bit_tick.
  // If its actual name is different, replace this reference.
  assign usb_if.bit_tick = dut.dut_tx.bit_tick;

  // Virtual interface configuration
  initial begin

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

  // DUT
  phy_top dut (

    .clk             (clk),
    .rst_n           (phy_if.rst_n),
    .usb_speed       (phy_if.usb_speed),

    .dp              (phy_if.dp),
    .dm              (phy_if.dm),
    .tx_valid        (phy_if.tx_valid),

    .analog_d_plus   (phy_if.analog_d_plus),
    .analog_d_minus  (phy_if.analog_d_minus),
    .analog_enable   (phy_if.analog_enable),
    .analog_serial   (phy_if.analog_serial),

    .sof_packet      (phy_if.sof_packet),
    .sie_data        (phy_if.sie_data),
    .sie_valid       (phy_if.sie_valid),
    .sie_sop         (phy_if.sie_sop),
    .sie_eop         (phy_if.sie_eop),
    .sie_ready       (phy_if.sie_ready),

    .DataOut         (phy_if.DataOut),
    .RxValid         (phy_if.RxValid),
    .RxActive        (phy_if.RxActive),
    .RxError         (phy_if.RxError),
    .LineState       (phy_if.LineState),

    .rx_sop          (phy_if.rx_sop),
    .rx_eop          (phy_if.rx_eop),

    .rx_stuff_err    (phy_if.rx_stuff_err),
    .rx_align_err    (phy_if.rx_align_err),
    .rx_line_err     (phy_if.rx_line_err),
    .rx_sync_err     (phy_if.rx_sync_err),
    .rx_bus_reset    (phy_if.rx_bus_reset)

  );

  initial begin
    $shm_open("wave.shm");
    $shm_probe("AS");
  end

endmodule

