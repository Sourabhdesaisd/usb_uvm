class usb_phy_env extends uvm_env;

  `uvm_component_utils(usb_phy_env)


  // ==================================================
  // CONFIGURATION
  // ==================================================

  usb_phy_env_config cfg;


  // ==================================================
  // AGENTS
  // ==================================================

  phy_agent     phy_ag;
  usb_bfm_agent usb_ag;


  // ==================================================
  // SCOREBOARD
  // ==================================================

  usb_phy_scb scoreboard;


  // ==================================================
  // CONSTRUCTOR
  // ==================================================

  function new(
    string name = "usb_phy_env",
    uvm_component parent = null
  );

    super.new(name, parent);

  endfunction


  // ==================================================
  // BUILD PHASE
  // ==================================================

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);


    // ----------------------------------------------
    // Get environment configuration
    // ----------------------------------------------

    if (!uvm_config_db#(usb_phy_env_config)::get(
          this,
          "",
          "cfg",
          cfg
        )) begin

      `uvm_fatal(
        "USB_PHY_ENV",
        "Environment configuration cfg was not found"
      )

    end


    if (cfg == null) begin

      `uvm_fatal(
        "USB_PHY_ENV",
        "Environment configuration is NULL"
      )

    end


    cfg.check_config();

    cfg.print_config();


    // ----------------------------------------------
    // Create PHY agent
    // ----------------------------------------------

    if (cfg.enable_phy_agent) begin

      uvm_config_db#(phy_agent_config)::set(
        this,
        "phy_ag",
        "cfg",
        cfg.phy_cfg
      );

      phy_ag = phy_agent::type_id::create(
        "phy_ag",
        this
      );

    end


    // ----------------------------------------------
    // Create USB BFM agent
    // ----------------------------------------------

    if (cfg.enable_usb_bfm_agent) begin

      uvm_config_db#(usb_bfm_agent_config)::set(
        this,
        "usb_ag",
        "cfg",
        cfg.usb_bfm_cfg
      );

      usb_ag = usb_bfm_agent::type_id::create(
        "usb_ag",
        this
      );

    end


    // ----------------------------------------------
    // Create scoreboard
    // ----------------------------------------------

    if (cfg.enable_scoreboard) begin

      scoreboard = usb_phy_scb::type_id::create(
        "scoreboard",
        this
      );

    end

  endfunction


  // ==================================================
  // CONNECT PHASE
  // ==================================================

  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);


    // ----------------------------------------------
    // Connect PHY monitor to scoreboard
    // ----------------------------------------------

    if ((scoreboard != null) && (phy_ag != null)) begin

      if (phy_ag.monitor != null) begin

        // TX accepted transactions
        phy_ag.monitor.analysis_port.connect(
          scoreboard.phy_fifo.analysis_export
        );


        // RX valid data bytes
        phy_ag.monitor.rx_analysis_port.connect(
          scoreboard.rx_fifo.analysis_export
        );


        // RX status events
        phy_ag.monitor.rx_status_analysis_port.connect(
          scoreboard.rx_status_fifo.analysis_export
        );


        `uvm_info(
          "USB_PHY_ENV",
          "PHY TX, RX and RX status connections completed",
          UVM_LOW
        )

      end

      else begin

        `uvm_warning(
          "USB_PHY_ENV",
          "PHY monitor is not created"
        )

      end

    end


    // ----------------------------------------------
    // Connect USB BFM monitor to scoreboard
    // ----------------------------------------------

    if ((scoreboard != null) && (usb_ag != null)) begin

      if (usb_ag.monitor != null) begin

        usb_ag.monitor.analysis_port.connect(
          scoreboard.bus_fifo.analysis_export
        );


        `uvm_info(
          "USB_PHY_ENV",
          "USB BFM bus monitor connection completed",
          UVM_LOW
        )

      end

      else begin

        `uvm_warning(
          "USB_PHY_ENV",
          "USB BFM monitor is not created"
        )

      end

    end


    `uvm_info(
      "USB_PHY_ENV",
      "Environment connect phase completed",
      UVM_LOW
    )

  endfunction


  // ==================================================
  // END OF ELABORATION
  // ==================================================

  function void end_of_elaboration_phase(
    uvm_phase phase
  );

    super.end_of_elaboration_phase(phase);

    `uvm_info(
      "USB_PHY_ENV",
      "USB PHY UVM environment hierarchy",
      UVM_LOW
    )

    uvm_top.print_topology();

  endfunction


  // ==================================================
  // REPORT PHASE
  // ==================================================

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info(
      "USB_PHY_ENV",
      "USB PHY environment report phase completed",
      UVM_LOW
    )

  endfunction

endclass
