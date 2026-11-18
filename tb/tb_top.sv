
module tb_top;

              
  // 1. PACKAGE IMPORTS
              

  import uvm_pkg::*;
  import usb_phy_tb_pkg::*;


              
  // 2. CLOCK
              

  logic clk;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end


              
  // 3. INTERFACE INSTANCES
              

  usb_phy_if phy_if(clk);

  usb_bus_if usb_if(clk);


              
  // 4. RESET AND INITIAL CONFIGURATION
              

  initial begin

    // Assert reset
    phy_if.rst_n = 1'b0;

    // Initialize RTL speed to Low Speed
    phy_if.usb_speed = usb_phy_pkg::LS;

    // Initialize external USB partner drive
    usb_if.device_oe = 1'b0;
    usb_if.device_dp = 1'b0;
    usb_if.device_dm = 1'b0;

    // Wait for reset duration
    #100;

    // Release reset
    phy_if.rst_n = 1'b1;

  end


              
  // 5. COMMON RESET CONNECTION
              

  // Both interfaces use the same reset
  assign usb_if.rst_n = phy_if.rst_n;


              
  // 6. DUT TX -> USB BUS CONNECTION
              

  assign usb_if.phy_dp       = phy_if.dp;
  assign usb_if.phy_dm       = phy_if.dm;
  assign usb_if.phy_tx_valid = phy_if.tx_valid;


              
  // 7. USB BUS -> DUT CDR RX CONNECTION
              

  assign phy_if.analog_d_plus  = usb_if.bus_dp;
  assign phy_if.analog_d_minus = usb_if.bus_dm;


              


              
  //  PASS VIRTUAL INTERFACES TO UVM
              

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


              
  //  DUT INSTANTIATION
              

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



 initial begin
    $shm_open("wave.shm");
    $shm_probe("ACTMF");
  end

  
endmodule

