
//`timescale 1ns/1fs
module top_tb;

  import uvm_pkg::*;
  import usb_phy_pkg::*;
  import usb_phy_tb_pkg::*;

  localparam int WIDTH = 8;

  logic clk;

  // --------------------------------------------------
  // USB speed configuration
  // --------------------------------------------------

  speed_t selected_usb_speed;
  int unsigned usb_speed_arg;

  // --------------------------------------------------
  // UVM configuration objects
  // --------------------------------------------------

  usb_phy_env_config env_cfg;
  phy_agent_config phy_cfg;
  usb_bfm_agent_config usb_bfm_cfg;


  // --------------------------------------------------
  // PHY interface
  // --------------------------------------------------

  usb_phy_if #(
    .WIDTH(WIDTH)
  ) phy_if (
    .clk(clk)
  );


  // --------------------------------------------------
  // Shared USB bus interface
  // --------------------------------------------------

  usb_bus_if bus_if (
    .clk(clk)
  );


  // --------------------------------------------------
  // DUT: USB 2.0 PHY top
  // --------------------------------------------------

  phy_top #(
    .WIDTH(WIDTH)
  ) dut (

    // Clock and reset
    .clk              (clk),
    .rst_n            (phy_if.rst_n),
    .usb_speed        (phy_if.usb_speed),

    // Analog driver outputs
    .dp               (phy_if.dp),
    .dm               (phy_if.dm),
    .tx_valid         (phy_if.tx_valid),

    // Analog receiver inputs
    .analog_d_plus    (phy_if.analog_d_plus),
    .analog_d_minus   (phy_if.analog_d_minus),
    .analog_enable    (phy_if.analog_enable),
    .analog_phy_bfm    (phy_if.analog_phy_bfm),

    // SIE transmit interface
    .sof_packet       (phy_if.sof_packet),
    .sie_data         (phy_if.sie_data),
    .sie_valid        (phy_if.sie_valid),
    .sie_sop          (phy_if.sie_sop),
    .sie_eop           (phy_if.sie_eop),
    .sie_ready        (phy_if.sie_ready),

    // SIE receive interface
    .DataOut          (phy_if.DataOut),
    .RxValid          (phy_if.RxValid),
    .RxActive         (phy_if.RxActive),
    .RxError          (phy_if.RxError),
    .LineState        (phy_if.LineState),

    // RX packet markers
    .rx_sop           (phy_if.rx_sop),
    .rx_eop           (phy_if.rx_eop),

    // RX status
    .rx_stuff_err     (phy_if.rx_stuff_err),
    .rx_align_err     (phy_if.rx_align_err),
    .rx_line_err      (phy_if.rx_line_err),
    .rx_sync_err      (phy_if.rx_sync_err),
    .rx_bus_reset     (phy_if.rx_bus_reset)

  );


// DUT TX outputs
assign bus_if.phy_dp       = phy_if.dp;
assign bus_if.phy_dm       = phy_if.dm;
assign bus_if.phy_tx_valid = phy_if.tx_valid;


// Shared bus to DUT RX
assign phy_if.analog_d_plus  = bus_if.bus_dp;
assign phy_if.analog_d_minus = bus_if.bus_dm;
// Model the external analog receiver's local-TX squelch.
assign phy_if.analog_enable = phy_if.analog_enable_req ;// && !phy_if.tx_valid;


// Common reset
assign bus_if.rst_n = phy_if.rst_n;
assign bus_if.usb_speed = phy_if.usb_speed;


// DUT internal bit tick observation
assign bus_if.bit_tick = dut.dut_tx.bit_tick;

  // --------------------------------------------------
  // 480 MHz system clock
  // --------------------------------------------------

  initial begin : CLOCK_GENERATION

    clk = 1'b0;

    forever #1.041666667 clk = ~clk;

  end


  // --------------------------------------------------
  // Reset generation
  // --------------------------------------------------

  initial begin : RESET_GENERATION

    // Assert reset at simulation time zero.
    phy_if.rst_n = 1'b0;

    // Hold reset for 10 clock cycles.
    repeat (10) @(posedge clk);

    // Release reset on falling edge.
    @(negedge clk);

    phy_if.rst_n = 1'b1;

    $display(
      "[TB_TOP] Reset released at time %0t",
      $time
    );

  end


  // --------------------------------------------------
  // USB speed selection and UVM initialization
  // --------------------------------------------------

  initial begin : TB_INITIALIZATION

    // ----------------------------------------------
    // Default USB speed: Full Speed
    // ----------------------------------------------

    usb_speed_arg = 1;
    selected_usb_speed = FS;

    if ($value$plusargs("USB_SPEED=%d", usb_speed_arg)) begin

      case (usb_speed_arg)

        0: selected_usb_speed = LS;
        1: selected_usb_speed = FS;
        2: selected_usb_speed = HS;

        default: begin

          $fatal(
            1,
            "[TB_TOP] Invalid USB_SPEED=%0d. Use 0=LS, 1=FS, 2=HS",
            usb_speed_arg
          );

        end

      endcase

    end
    else begin

      $display(
        "[TB_TOP] USB_SPEED not supplied. Defaulting to FS"
      );

    end


    // ----------------------------------------------
    // Initialize DUT input signals
    // ----------------------------------------------

    phy_if.usb_speed     = selected_usb_speed;

    phy_if.sof_packet    = 1'b0;
    phy_if.sie_data      = '0;
    phy_if.sie_valid     = 1'b0;
    phy_if.sie_sop       = 1'b0;
    phy_if.sie_eop       = 1'b0;

    phy_if.analog_enable_req = 1'b0;
    phy_if.analog_phy_bfm = 1'b1;


    // ----------------------------------------------
    // Initialize external USB BFM driver
    // ----------------------------------------------

    bus_if.device_dp = 1'b1;
    bus_if.device_dm = 1'b0;
    bus_if.device_oe = 1'b0;


    // ----------------------------------------------
    // Create configuration objects
    // ----------------------------------------------

    env_cfg = usb_phy_env_config::type_id::create(
      "env_cfg"
    );

    phy_cfg = phy_agent_config::type_id::create(
      "phy_cfg"
    );

    usb_bfm_cfg = usb_bfm_agent_config::type_id::create(
      "usb_bfm_cfg"
    );


    // ----------------------------------------------
    // PHY agent configuration
    // ----------------------------------------------

    phy_cfg.vif = phy_if;

    phy_cfg.is_active      = UVM_ACTIVE;
    phy_cfg.enable_driver  = 1'b1;
    phy_cfg.enable_monitor = 1'b1;

    phy_cfg.set_speed(selected_usb_speed);


    // ----------------------------------------------
    // USB BFM agent configuration
    // ----------------------------------------------

    usb_bfm_cfg.bus_vif = bus_if;
    usb_bfm_cfg.phy_vif = phy_if;

    usb_bfm_cfg.is_active      = UVM_ACTIVE;
    usb_bfm_cfg.enable_driver  = 1'b1;
    usb_bfm_cfg.enable_monitor = 1'b1;

    usb_bfm_cfg.set_speed(selected_usb_speed);


    // ----------------------------------------------
    // Environment configuration
    // ----------------------------------------------

    env_cfg.phy_cfg     = phy_cfg;
    env_cfg.usb_bfm_cfg = usb_bfm_cfg;

    env_cfg.enable_phy_agent     = 1'b1;
    env_cfg.enable_usb_bfm_agent = 1'b1;
    env_cfg.enable_scoreboard    = 1'b1;

    env_cfg.set_speed(selected_usb_speed);


    // ----------------------------------------------
    // Configuration validation
    // ----------------------------------------------

    phy_cfg.check_config();
    usb_bfm_cfg.check_config();
    env_cfg.check_config();


    // ----------------------------------------------
    // Publish configuration objects
    // ----------------------------------------------

    uvm_config_db#(usb_phy_env_config)::set(
      null,
      "uvm_test_top",
      "env_cfg",
      env_cfg
    );


    // ----------------------------------------------
    // Print selected configuration
    // ----------------------------------------------

    $display("");
    $display("==============================================");
    $display("         USB PHY UVM CONFIGURATION");
    $display("==============================================");

    case (selected_usb_speed)

      LS: $display("[TB_TOP] USB SPEED : LOW SPEED");
      FS: $display("[TB_TOP] USB SPEED : FULL SPEED");
      HS: $display("[TB_TOP] USB SPEED : HIGH SPEED");

      default: $display("[TB_TOP] USB SPEED : INVALID");

    endcase

    $display(
      "[TB_TOP] USB_SPEED argument : %0d",
      usb_speed_arg
    );

    $display(
      "[TB_TOP] PHY agent enabled   : %0b",
      env_cfg.enable_phy_agent
    );

    $display(
      "[TB_TOP] USB BFM enabled     : %0b",
      env_cfg.enable_usb_bfm_agent
    );

    $display(
      "[TB_TOP] Scoreboard enabled  : %0b",
      env_cfg.enable_scoreboard
    );

    $display("==============================================");
    $display("");


    // ----------------------------------------------
    // Start UVM at simulation time zero
    // ----------------------------------------------

    $display(
      "[TB_TOP] Calling run_test at time %0t",
      $time
    );

    run_test();

  end


  // --------------------------------------------------
  // SimVision waveform dump
  // --------------------------------------------------

  initial begin : WAVEFORM_DUMP

    $shm_open("wave.shm");
    $shm_probe("ACTMF");

  end


endmodule

