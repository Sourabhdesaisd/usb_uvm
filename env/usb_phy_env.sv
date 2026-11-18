
class usb_phy_env extends uvm_env;

  `uvm_component_utils(usb_phy_env)


  // ------------------------------------------------
  // Environment configuration
  // ------------------------------------------------
  usb_phy_env_config cfg;


  // ------------------------------------------------
  // Agent configurations
  // ------------------------------------------------
  phy_agent_config phy_cfg;
  usb_bfm_config   usb_cfg;


  // ------------------------------------------------
  // Agents
  // ------------------------------------------------
  phy_agent     phy_ag;
  usb_bfm_agent usb_ag;


  // ------------------------------------------------
  // Analysis FIFOs
  // ------------------------------------------------
  uvm_tlm_analysis_fifo #(phy_transaction)
      phy_analysis_fifo;

  uvm_tlm_analysis_fifo #(usb_bfm_transaction)
      usb_analysis_fifo;


  // ------------------------------------------------
  // Constructor
  // ------------------------------------------------
  function new(string name = "usb_phy_env",
               uvm_component parent = null);

    super.new(name, parent);

  endfunction


  // ------------------------------------------------
  // Build phase
  // ------------------------------------------------
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);


    // ----------------------------------------------
    // Get environment configuration
    // ----------------------------------------------
    if (!uvm_config_db#(usb_phy_env_config)::get(
          this, "", "cfg", cfg)) begin

      `uvm_fatal("ENV_CFG",
                 "USB PHY environment configuration not found")

    end


    // ----------------------------------------------
    // Validate USB speed
    // ----------------------------------------------
    if (cfg.speed == USB_SPEED_RESERVED) begin

      `uvm_fatal("ENV_SPEED",
                 "Reserved USB speed selected")

    end


    // ----------------------------------------------
    // Validate virtual interfaces
    // ----------------------------------------------
    if (cfg.phy_vif == null) begin

      `uvm_fatal("ENV_PHY_VIF",
                 "PHY virtual interface is NULL")

    end

    if (cfg.usb_vif == null) begin

      `uvm_fatal("ENV_USB_VIF",
                 "USB bus virtual interface is NULL")

    end


    // ----------------------------------------------
    // Create PHY Agent configuration
    // ----------------------------------------------
    phy_cfg = phy_agent_config::type_id::create(
      "phy_cfg"
    );

    phy_cfg.vif       = cfg.phy_vif;
    phy_cfg.speed     = cfg.speed;
    phy_cfg.is_active = cfg.phy_is_active;


    // ----------------------------------------------
    // Pass PHY configuration to PHY Agent
    // ----------------------------------------------
    uvm_config_db#(phy_agent_config)::set(
      this,
      "phy_ag",
      "cfg",
      phy_cfg
    );


    // ----------------------------------------------
    // Create USB Device Agent configuration
    // ----------------------------------------------
    usb_cfg = usb_bfm_config::type_id::create(
      "usb_cfg"
    );

    usb_cfg.vif       = cfg.usb_vif;
    usb_cfg.speed     = cfg.speed;
    usb_cfg.is_active = cfg.usb_is_active;


    // ----------------------------------------------
    // Pass USB configuration to USB Device Agent
    // ----------------------------------------------
    uvm_config_db#(usb_bfm_config)::set(
      this,
      "usb_ag",
      "cfg",
      usb_cfg
    );


    // ----------------------------------------------
    // Create PHY Agent
    // ----------------------------------------------
    phy_ag = phy_agent::type_id::create(
      "phy_ag",
      this
    );


    // ----------------------------------------------
    // Create USB Device Agent
    // ----------------------------------------------
    usb_ag = usb_bfm_agent::type_id::create(
      "usb_ag",
      this
    );


    // ----------------------------------------------
    // Create PHY Analysis FIFO
    // ----------------------------------------------
    phy_analysis_fifo =
      new("phy_analysis_fifo", this);


    // ----------------------------------------------
    // Create USB Analysis FIFO
    // ----------------------------------------------
    usb_analysis_fifo =
      new("usb_analysis_fifo", this);


    `uvm_info("USB_ENV",
              $sformatf(
                "Environment configured: USB speed=%0d PHY active=%0b USB active=%0b",
                cfg.speed,
                cfg.phy_is_active,
                cfg.usb_is_active),
              UVM_LOW)

  endfunction


  // ------------------------------------------------
  // Connect phase
  // ------------------------------------------------
  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);


    // ----------------------------------------------
    // PHY Monitor -> PHY Analysis FIFO
    // ----------------------------------------------
    phy_ag.monitor.analysis_port.connect(
      phy_analysis_fifo.analysis_export
    );


    // ----------------------------------------------
    // USB Monitor -> USB Analysis FIFO
    // ----------------------------------------------
    usb_ag.monitor.analysis_port.connect(
      usb_analysis_fifo.analysis_export
    );


    `uvm_info("USB_ENV",
              "PHY and USB monitor analysis connections completed",
              UVM_LOW)

  endfunction


  // ------------------------------------------------
  // End of elaboration phase
  // ------------------------------------------------
  function void end_of_elaboration_phase(uvm_phase phase);

    super.end_of_elaboration_phase(phase);

    `uvm_info("USB_ENV",
              "USB PHY environment elaboration completed",
              UVM_LOW)

    // Print complete UVM component hierarchy
    uvm_top.print_topology();

  endfunction


  // ------------------------------------------------
  // Report phase
  // ------------------------------------------------
  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info("USB_ENV_REPORT",
              "USB PHY environment simulation completed",
              UVM_LOW)

  endfunction


endclass

