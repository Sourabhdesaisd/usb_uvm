
class usb_phy_env extends uvm_env;

  `uvm_component_utils(usb_phy_env)

  // Environment configuration
  usb_phy_env_config cfg;

  // Agent instances
  phy_agent phy_ag;
  usb_bfm_agent usb_ag;

  // Scoreboard instance
  usb_phy_scb scoreboard;

  // Constructor
  function new(
    string name = "usb_phy_env",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    // Get environment configuration
    if (!uvm_config_db#(usb_phy_env_config)::get(
          this,
          "",
          "cfg",
          cfg
        )) begin

      `uvm_fatal(
        "USB_PHY_ENV",
        "Failed to get usb_phy_env_config from config_db"
      )

    end

    if (cfg == null) begin

      `uvm_fatal(
        "USB_PHY_ENV",
        "Environment configuration handle is NULL"
      )

    end

    if (cfg.phy_cfg == null) begin

      `uvm_fatal(
        "USB_PHY_ENV",
        "PHY agent configuration is NULL"
      )

    end

    if (cfg.usb_bfm_cfg == null) begin

      `uvm_fatal(
        "USB_PHY_ENV",
        "USB BFM agent configuration is NULL"
      )

    end

    // Pass PHY agent configuration
    uvm_config_db#(phy_agent_config)::set(
      this,
      "phy_ag",
      "cfg",
      cfg.phy_cfg
    );

    // Pass USB BFM agent configuration
    uvm_config_db#(usb_bfm_agent_config)::set(
      this,
      "usb_ag",
      "cfg",
      cfg.usb_bfm_cfg
    );

    // Create PHY agent
    phy_ag = phy_agent::type_id::create(
      "phy_ag",
      this
    );

    // Create USB BFM agent
    usb_ag = usb_bfm_agent::type_id::create(
      "usb_ag",
      this
    );

    // Create scoreboard
    scoreboard = usb_phy_scb::type_id::create(
      "scoreboard",
      this
    );

  endfunction

  // Connect phase
  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);

    // TX SIE monitor to scoreboard
    phy_ag.monitor.analysis_port.connect(
      scoreboard.phy_fifo.analysis_export
    );

    // RX monitor to scoreboard
    phy_ag.monitor.rx_analysis_port.connect(
      scoreboard.rx_fifo.analysis_export
    );

    // USB physical bus monitor to scoreboard
    usb_ag.monitor.analysis_port.connect(
      scoreboard.bus_fifo.analysis_export
    );

    `uvm_info(
      "USB_PHY_ENV",
      "TX, RX and USB bus analysis connections completed",
      UVM_LOW
    )

  endfunction

  // End of elaboration phase
  function void end_of_elaboration_phase(uvm_phase phase);

    super.end_of_elaboration_phase(phase);

    `uvm_info(
      "USB_PHY_ENV",
      "USB PHY environment hierarchy:",
      UVM_LOW
    )

    uvm_top.print_topology();

  endfunction

  // Report phase
  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info(
      "USB_PHY_ENV",
      "USB PHY environment completed",
      UVM_LOW
    )

  endfunction

endclass

