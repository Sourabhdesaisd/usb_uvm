
module tb_top;

  import uvm_pkg::*;
  import usb_phy_pkg::*;
  import usb_phy_tb_pkg::*;

  localparam int WIDTH = 8;

  logic clk;

  // Selected USB speed from command line
  speed_t selected_usb_speed;
  int unsigned usb_speed_arg;

  // PHY interface
  usb_phy_if #(
    .WIDTH(WIDTH)
  ) phy_if (
    .clk(clk)
  );

  // External USB bus interface
  usb_bus_if bus_if (
    .clk(clk)
  );

  // DUT
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

  // Connect PHY TX outputs to shared USB bus
  assign bus_if.phy_dp       = phy_if.dp;
  assign bus_if.phy_dm       = phy_if.dm;
  assign bus_if.phy_tx_valid = phy_if.tx_valid;

  // Connect shared USB bus to PHY RX/CDR inputs
  assign phy_if.analog_d_plus  = bus_if.bus_dp;
  assign phy_if.analog_d_minus = bus_if.bus_dm;

  // Shared reset
  assign bus_if.rst_n = phy_if.rst_n;

  // Observe internal TX bit tick
  assign bus_if.bit_tick = dut.dut_tx.bit_tick;


  // 480 MHz system clock
  // Period = 2.083333 ns
  initial begin
    clk = 1'b0;
    forever #1.041666 clk = ~clk;
  end


  // Initialize, configure speed, release reset and start UVM
  initial begin : TB_INITIALIZATION

    usb_phy_env_config env_cfg;
    phy_agent_config phy_cfg;
    usb_bfm_agent_config usb_bfm_cfg;

    // Default speed is Full Speed
    usb_speed_arg = 1;
    selected_usb_speed = FS;

    // Read speed from command line
    if ($value$plusargs("USB_SPEED=%d", usb_speed_arg)) begin

      case (usb_speed_arg)

        0: selected_usb_speed = LS;
        1: selected_usb_speed = FS;
        2: selected_usb_speed = HS;

        default: begin
          $fatal(
            1,
            "Invalid +USB_SPEED=%0d. Use 0=LS, 1=FS, 2=HS",
            usb_speed_arg
          );
        end

      endcase

    end
    else begin

      $display(
        "[TB_TOP] +USB_SPEED not supplied. Defaulting to FS"
      );

    end


    // Initialize reset and DUT input signals
    phy_if.rst_n         = 1'b0;
    phy_if.usb_speed     = selected_usb_speed;

    phy_if.sof_packet    = 1'b0;
    phy_if.sie_data      = '0;
    phy_if.sie_valid     = 1'b0;
    phy_if.sie_sop       = 1'b0;
    phy_if.sie_eop       = 1'b0;

    phy_if.analog_enable = 1'b0;
    phy_if.analog_serial = 1'b1;

    // Initialize external USB device driver
    bus_if.device_dp     = 1'b1;
    bus_if.device_dm     = 1'b0;
    bus_if.device_oe     = 1'b0;


    // Create configuration objects
    env_cfg     = usb_phy_env_config::type_id::create("env_cfg");
    phy_cfg     = phy_agent_config::type_id::create("phy_cfg");
    usb_bfm_cfg = usb_bfm_agent_config::type_id::create("usb_bfm_cfg");


    // Configure PHY agent
    phy_cfg.vif            = phy_if;
    phy_cfg.is_active      = UVM_ACTIVE;
    phy_cfg.enable_driver  = 1'b1;
    phy_cfg.enable_monitor = 1'b1;


    // Configure USB BFM agent
    usb_bfm_cfg.bus_vif     = bus_if;
    usb_bfm_cfg.phy_vif     = phy_if;
    usb_bfm_cfg.is_active   = UVM_ACTIVE;
    usb_bfm_cfg.enable_driver  = 1'b1;
    usb_bfm_cfg.enable_monitor = 1'b1;


    // Attach agent configurations to environment
    env_cfg.phy_cfg     = phy_cfg;
    env_cfg.usb_bfm_cfg = usb_bfm_cfg;

    env_cfg.enable_phy_agent     = 1'b1;
    env_cfg.enable_usb_bfm_agent = 1'b1;
    env_cfg.enable_scoreboard    = 1'b1;

    // Apply the selected speed to both agents
    env_cfg.set_speed(selected_usb_speed);


    // Validate individual configurations
    phy_cfg.check_config();
    usb_bfm_cfg.check_config();
    env_cfg.check_config();


    // Set virtual interfaces
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


    // Set PHY agent configuration
    uvm_config_db#(phy_agent_config)::set(
      null,
      "uvm_test_top.env.phy_ag",
      "cfg",
      phy_cfg
    );

    // Set USB BFM agent configuration
    uvm_config_db#(usb_bfm_agent_config)::set(
      null,
      "uvm_test_top.env.usb_ag",
      "cfg",
      usb_bfm_cfg
    );

    // Set environment configuration for the test
    uvm_config_db#(usb_phy_env_config)::set(
      null,
      "*",
      "env_cfg",
      env_cfg
    );


    $display("==============================================");
    $display("[TB_TOP] USB PHY UVM CONFIGURATION");
    $display("[TB_TOP] USB_SPEED argument = %0d", usb_speed_arg);
    $display("[TB_TOP] Selected speed     = %s",
             selected_usb_speed.name());
    $display("==============================================");


    // Keep reset asserted for 10 clock cycles
    repeat (10) @(posedge clk);

    // Release reset on falling edge
    @(negedge clk);
    phy_if.rst_n = 1'b1;

    $display("[TB_TOP] Reset released");
    $display("[TB_TOP] Starting UVM test");

    run_test();

  end


  // SimVision waveform dumping
  initial begin
    $shm_open("wave.shm");
    $shm_probe("ACTMF");
  end

endmodule

