

module tb_top;

  import uvm_pkg::*;
  import usb_phy_pkg::*;
  import usb_phy_tb_pkg::*;

  localparam int WIDTH = 8;

  logic clk;

  // --------------------------------------------------
  // Interface instances
  // --------------------------------------------------

  usb_phy_if #(
    .WIDTH(WIDTH)
  ) phy_if (
    .clk(clk)
  );

  usb_bus_if bus_if (
    .clk(clk)
  );

  // --------------------------------------------------
  // DUT instantiation
  // --------------------------------------------------

  phy_top #(
    .WIDTH(WIDTH)
  ) dut (
    .clk              (clk),
    .rst_n            (phy_if.rst_n),
    .usb_speed        (phy_if.usb_speed),

    // TX interface
    .dp               (phy_if.dp),
    .dm               (phy_if.dm),
    .tx_valid         (phy_if.tx_valid),

    .sof_packet       (phy_if.sof_packet),
    .sie_data         (phy_if.sie_data),
    .sie_valid        (phy_if.sie_valid),
    .sie_sop          (phy_if.sie_sop),
    .sie_eop          (phy_if.sie_eop),
    .sie_ready        (phy_if.sie_ready),

    // External USB bus / CDR inputs
    .analog_d_plus    (phy_if.analog_d_plus),
    .analog_d_minus   (phy_if.analog_d_minus),
    .analog_enable    (phy_if.analog_enable),
    .analog_serial    (phy_if.analog_serial),

    // RX interface
    .DataOut          (phy_if.DataOut),
    .RxValid          (phy_if.RxValid),
    .RxActive         (phy_if.RxActive),
    .RxError          (phy_if.RxError),
    .LineState        (phy_if.LineState),

    .rx_sop           (phy_if.rx_sop),
    .rx_eop           (phy_if.rx_eop),

    .rx_stuff_err     (phy_if.rx_stuff_err),
    .rx_align_err     (phy_if.rx_align_err),
    .rx_line_err      (phy_if.rx_line_err),
    .rx_sync_err      (phy_if.rx_sync_err),
    .rx_bus_reset     (phy_if.rx_bus_reset)
  );

  // --------------------------------------------------
  // DUT TX to shared USB bus
  // --------------------------------------------------

  assign bus_if.phy_dp       = phy_if.dp;
  assign bus_if.phy_dm       = phy_if.dm;
  assign bus_if.phy_tx_valid = phy_if.tx_valid;

  // Shared USB bus to DUT RX/CDR
  assign phy_if.analog_d_plus  = bus_if.bus_dp;
  assign phy_if.analog_d_minus = bus_if.bus_dm;

  // Shared reset
  assign bus_if.rst_n = phy_if.rst_n;

  // Internal TX bit tick observation
  // Confirm dut_tx and bit_tick hierarchy in your RTL.
  assign bus_if.bit_tick = dut.dut_tx.bit_tick;

  // --------------------------------------------------
  // Clock generation: 480 MHz
  // Period = 2.083333 ns
  // --------------------------------------------------

  initial begin
    clk = 1'b0;
    forever #1.041666 clk = ~clk;
  end

  // --------------------------------------------------
  // Reset and initial values
  // --------------------------------------------------

  initial begin

    phy_if.rst_n         = 1'b0;

    phy_if.usb_speed     = LS;

    phy_if.sof_packet    = 1'b0;
    phy_if.sie_data      = '0;
    phy_if.sie_valid     = 1'b0;
    phy_if.sie_sop       = 1'b0;
    phy_if.sie_eop       = 1'b0;

    phy_if.analog_enable = 1'b0;
    phy_if.analog_serial = 1'b1;

    bus_if.device_dp     = 1'b1;
    bus_if.device_dm     = 1'b0;
    bus_if.device_oe     = 1'b0;

    repeat (10) @(posedge clk);

    @(negedge clk);
    phy_if.rst_n = 1'b1;

  end

  // --------------------------------------------------
  // UVM configuration and startup
  // --------------------------------------------------

  initial begin

    usb_phy_env_config env_cfg;
    phy_agent_config phy_cfg;
    usb_bfm_agent_config usb_bfm_cfg;

    // Create configuration objects
    env_cfg    = usb_phy_env_config::type_id::create("env_cfg");
    phy_cfg    = phy_agent_config::type_id::create("phy_cfg");
    usb_bfm_cfg = usb_bfm_agent_config::type_id::create("usb_bfm_cfg");

    // PHY agent configuration
    phy_cfg.vif            = phy_if;
    phy_cfg.is_active      = UVM_ACTIVE;
    phy_cfg.enable_driver  = 1'b1;
    phy_cfg.enable_monitor = 1'b1;
    phy_cfg.speed          = LS;

    // USB BFM agent configuration
    usb_bfm_cfg.bus_vif = bus_if;
    usb_bfm_cfg.phy_vif = phy_if;

    // Environment configuration
    env_cfg.phy_cfg     = phy_cfg;
    env_cfg.usb_bfm_cfg = usb_bfm_cfg;

    // Pass virtual interfaces through config_db
    uvm_config_db#(virtual usb_phy_if #(WIDTH))::set(
      null,
      "*",
      "vif",
      phy_if
    );

    uvm_config_db#(virtual usb_bus_if)::set(
      null,
      "*",
      "bus_vif",
      bus_if
    );

    // Pass environment configuration to base test
    uvm_config_db#(usb_phy_env_config)::set(
      null,
      "*",
      "env_cfg",
      env_cfg
    );

    `uvm_info(
      "TB_TOP",
      "UVM configuration objects created and configured",
      UVM_LOW
    )

    // Start UVM only after reset is released
    wait (phy_if.rst_n === 1'b1);

    run_test();

  end

 initial begin
    $shm_open("wave.shm");
    $shm_probe("ACTMF");
  end



endmodule

