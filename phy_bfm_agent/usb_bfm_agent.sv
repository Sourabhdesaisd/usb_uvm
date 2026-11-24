
class usb_bfm_agent extends uvm_agent;

  `uvm_component_utils(usb_bfm_agent)

  // --------------------------------------------------
  // Configuration
  // --------------------------------------------------

  usb_bfm_agent_config cfg;

  // --------------------------------------------------
  // Agent components
  // --------------------------------------------------

  usb_bfm_sequencer sequencer;
  usb_bfm_driver    driver;
  usb_bfm_monitor   monitor;


  // --------------------------------------------------
  // Constructor
  // --------------------------------------------------

  function new(
    string name = "usb_bfm_agent",
    uvm_component parent = null
  );

    super.new(name, parent);

  endfunction


  // --------------------------------------------------
  // Build phase
  // --------------------------------------------------

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    // Get agent configuration
    if (!uvm_config_db#(usb_bfm_agent_config)::get(
          this,
          "",
          "cfg",
          cfg
        )) begin

      `uvm_fatal(
        "USB_BFM_AGENT",
        "usb_bfm_agent_config not found in config_db"
      )

    end

    if (cfg == null) begin

      `uvm_fatal(
        "USB_BFM_AGENT",
        "USB BFM configuration is NULL"
      )

    end

    // Validate configuration
    cfg.check_config();


    // ------------------------------------------------
    // Create monitor
    // ------------------------------------------------

    if (cfg.enable_monitor) begin

      // Set configuration before component creation
      uvm_config_db#(usb_bfm_agent_config)::set(
        this,
        "monitor",
        "cfg",
        cfg
      );

      monitor = usb_bfm_monitor::type_id::create(
        "monitor",
        this
      );

    end


    // ------------------------------------------------
    // Create driver and sequencer
    // ------------------------------------------------

    if (cfg.is_active == UVM_ACTIVE) begin

      if (!cfg.enable_driver) begin

        `uvm_fatal(
          "USB_BFM_AGENT",
          "Active USB BFM agent requires an enabled driver"
        )

      end


      // Set driver configuration before creation
      uvm_config_db#(usb_bfm_agent_config)::set(
        this,
        "driver",
        "cfg",
        cfg
      );


      // Create sequencer
      sequencer = usb_bfm_sequencer::type_id::create(
        "sequencer",
        this
      );
      sequencer.bus_vif = cfg.bus_vif;


      // Create driver
      driver = usb_bfm_driver::type_id::create(
        "driver",
        this
      );

    end


    `uvm_info(
      "USB_BFM_AGENT",
      $sformatf(
        "Build completed: MODE=%s DRIVER=%0b SEQUENCER=%0b MONITOR=%0b SPEED=%0d",
        (cfg.is_active == UVM_ACTIVE) ? "ACTIVE" : "PASSIVE",
        (driver != null),
        (sequencer != null),
        (monitor != null),
        cfg.speed
      ),
      UVM_LOW
    )

  endfunction


  // --------------------------------------------------
  // Connect phase
  // --------------------------------------------------

  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);

    // Connect driver and sequencer
    if (driver != null && sequencer != null) begin

      driver.seq_item_port.connect(
        sequencer.seq_item_export
      );

      `uvm_info(
        "USB_BFM_AGENT",
        "USB BFM driver connected to sequencer",
        UVM_LOW
      )

    end


    // Validate active-mode connectivity
    if (cfg.is_active == UVM_ACTIVE) begin

      if (driver == null || sequencer == null) begin

        `uvm_fatal(
          "USB_BFM_AGENT",
          "Active agent is missing driver or sequencer"
        )

      end

    end


    // Validate monitor
    if (cfg.enable_monitor && monitor == null) begin

      `uvm_fatal(
        "USB_BFM_AGENT",
        "Monitor is enabled but was not created"
      )

    end


    `uvm_info(
      "USB_BFM_AGENT",
      "Connect phase completed",
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
      "USB_BFM_AGENT",
      "USB BFM agent hierarchy",
      UVM_LOW
    )

    this.print();

  endfunction


  // --------------------------------------------------
  // Report phase
  // --------------------------------------------------

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info(
      "USB_BFM_AGENT",
      "USB BFM agent report phase completed",
      UVM_LOW
    )

  endfunction

endclass

