
class usb_phy_env extends uvm_env;

  `uvm_component_utils(usb_phy_env)

  // --------------------------------------------------
  // Environment configuration
  // --------------------------------------------------

  usb_phy_env_config cfg;


  // --------------------------------------------------
  // Agent handles
  // --------------------------------------------------

  phy_agent     phy_ag;
  usb_bfm_agent usb_ag;


  // --------------------------------------------------
  // Scoreboard
  // --------------------------------------------------

  usb_phy_scb scoreboard;


  // --------------------------------------------------
  // Constructor
  // --------------------------------------------------

  function new(
    string name = "usb_phy_env",
    uvm_component parent = null
  );

    super.new(name, parent);

  endfunction


  // --------------------------------------------------
  // Build phase
  // --------------------------------------------------

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


    // ----------------------------------------------
    // Validate configuration
    // ----------------------------------------------

    cfg.check_config();

    cfg.print_config();


    // ----------------------------------------------
    // Create PHY agent
    // ----------------------------------------------

    if (cfg.enable_phy_agent) begin

      if (cfg.phy_cfg == null) begin

        `uvm_fatal(
          "USB_PHY_ENV",
          "PHY agent configuration is NULL"
        )

      end


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


      `uvm_info(
        "USB_PHY_ENV",
        "PHY agent created",
        UVM_LOW
      )

    end


    // ----------------------------------------------
    // Create USB BFM agent
    // ----------------------------------------------

    if (cfg.enable_usb_bfm_agent) begin

      if (cfg.usb_bfm_cfg == null) begin

        `uvm_fatal(
          "USB_PHY_ENV",
          "USB BFM agent configuration is NULL"
        )

      end


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


      `uvm_info(
        "USB_PHY_ENV",
        "USB BFM agent created",
        UVM_LOW
      )

    end


    // ----------------------------------------------
    // Create scoreboard
    // ----------------------------------------------

    if (cfg.enable_scoreboard) begin

      scoreboard = usb_phy_scb::type_id::create(
        "scoreboard",
        this
      );


      `uvm_info(
        "USB_PHY_ENV",
        "Scoreboard created",
        UVM_LOW
      )

    end


    `uvm_info(
      "USB_PHY_ENV",
      "Environment build phase completed",
      UVM_LOW
    )

  endfunction


  // --------------------------------------------------
  // Connect phase
  // --------------------------------------------------

  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);


    // ----------------------------------------------
    // Connect PHY monitor to scoreboard
    // ----------------------------------------------

    if (scoreboard != null && phy_ag != null) begin

      if (phy_ag.monitor != null) begin

        // TX accepted-byte transactions
        phy_ag.monitor.analysis_port.connect(
          scoreboard.phy_fifo.analysis_export
        );


        // RX received-byte transactions
        phy_ag.monitor.rx_analysis_port.connect(
          scoreboard.rx_fifo.analysis_export
        );


        `uvm_info(
          "USB_PHY_ENV",
          "PHY TX and RX monitor connections completed",
          UVM_LOW
        )

      end
      else begin

        `uvm_warning(
          "USB_PHY_ENV",
          "PHY monitor is not created. PHY scoreboard connections skipped"
        )

      end

    end


    // ----------------------------------------------
    // Connect USB BFM monitor to scoreboard
    // ----------------------------------------------

    if (scoreboard != null && usb_ag != null) begin

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
          "USB BFM monitor is not created. Bus scoreboard connection skipped"
        )

      end

    end


    // ----------------------------------------------
    // Validate scoreboard connections
    // ----------------------------------------------

    if (cfg.enable_scoreboard) begin

      if (scoreboard == null) begin

        `uvm_fatal(
          "USB_PHY_ENV",
          "Scoreboard is enabled but was not created"
        )

      end


      if (phy_ag != null && phy_ag.monitor == null) begin

        `uvm_error(
          "USB_PHY_ENV",
          "PHY monitor is missing"
        )

      end


      if (usb_ag != null && usb_ag.monitor == null) begin

        `uvm_error(
          "USB_PHY_ENV",
          "USB BFM monitor is missing"
        )

      end

    end


    `uvm_info(
      "USB_PHY_ENV",
      "Environment connect phase completed",
      UVM_LOW
    )

  endfunction


  // --------------------------------------------------
  // End of elaboration phase
  // --------------------------------------------------

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


  // --------------------------------------------------
  // Report phase
  // --------------------------------------------------

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);


    `uvm_info(
      "USB_PHY_ENV",
      "USB PHY environment report phase completed",
      UVM_LOW
    )

  endfunction

endclass

