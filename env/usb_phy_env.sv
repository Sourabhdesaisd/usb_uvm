


class usb_phy_env extends uvm_env;

  `uvm_component_utils(usb_phy_env)


        
  // 1. ENVIRONMENT CONFIGURATION
        

  usb_phy_env_config cfg;


        
  // 2. AGENT CONFIGURATIONS
        

  phy_agent_config phy_cfg;
  usb_bfm_config   usb_cfg;


        
  // 3. AGENTS
        

  phy_agent     phy_ag;
  usb_bfm_agent usb_ag;


        
  // 4. SCOREBOARD
        

  usb_phy_scoreboard scoreboard;


        
  // 5. CONSTRUCTOR
        

  function new(string name = "usb_phy_env",
               uvm_component parent = null);

    super.new(name, parent);

  endfunction


        
  // 6. BUILD PHASE
        

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);


           
    // Get environment configuration
           

    if (!uvm_config_db#(usb_phy_env_config)::get(
          this, "", "cfg", cfg)) begin

      `uvm_fatal("ENV_CFG",
                 "USB PHY environment configuration not found")

    end

    if (cfg == null) begin

      `uvm_fatal("ENV_CFG_NULL",
                 "USB PHY environment configuration is NULL")

    end


           
    // Validate environment configuration
           

    cfg.validate_config();


           
    // Create PHY agent configuration
           

    phy_cfg = phy_agent_config::type_id::create(
                "phy_cfg");

    phy_cfg.vif       = cfg.phy_vif;
    phy_cfg.speed     = cfg.speed;
    phy_cfg.is_active = cfg.phy_is_active;

    phy_cfg.validate_config();


           
    // Pass PHY configuration to PHY agent
           

    uvm_config_db#(phy_agent_config)::set(
      this,
      "phy_ag",
      "cfg",
      phy_cfg
    );


           
    // Create USB BFM agent configuration
           

    usb_cfg = usb_bfm_config::type_id::create(
                "usb_cfg");

    usb_cfg.vif       = cfg.usb_vif;
    usb_cfg.speed     = cfg.speed;
    usb_cfg.is_active = cfg.usb_is_active;

    usb_cfg.validate_config();


           
    // Pass USB BFM configuration to USB agent
           

    uvm_config_db#(usb_bfm_config)::set(
      this,
      "usb_ag",
      "cfg",
      usb_cfg
    );


           
    // Create PHY agent
           

    phy_ag = phy_agent::type_id::create(
               "phy_ag",
               this);


           
    // Create USB BFM agent
           

    usb_ag = usb_bfm_agent::type_id::create(
               "usb_ag",
               this);


           
    // Create scoreboard
           

    scoreboard = usb_phy_scoreboard::type_id::create(
                   "scoreboard",
                   this);


           
    // Configuration information
           

    `uvm_info("USB_ENV",
              $sformatf(
                "Environment configured: SPEED=%0d PHY_ACTIVE=%0d USB_ACTIVE=%0d",
                cfg.speed,
                cfg.phy_is_active,
                cfg.usb_is_active),
              UVM_LOW)

  endfunction


        
  // 7. CONNECT PHASE
        

  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);


           
    // PHY Monitor -> Scoreboard PHY FIFO
           

    phy_ag.monitor.ap.connect(
      scoreboard.phy_fifo.analysis_export
    );


           
    // USB BFM Monitor -> Scoreboard Bus FIFO
           

    usb_ag.monitor.analysis_port.connect(
      scoreboard.bus_fifo.analysis_export
    );


    `uvm_info("USB_ENV",
              "PHY and USB BFM monitors connected to scoreboard",
              UVM_LOW)

  endfunction


        
  // 8. END OF ELABORATION PHASE
        

  function void end_of_elaboration_phase(uvm_phase phase);

    super.end_of_elaboration_phase(phase);

    `uvm_info("USB_ENV",
              "USB PHY environment elaboration completed",
              UVM_LOW)

    // Display complete UVM component hierarchy
    uvm_top.print_topology();

  endfunction


        
  // 9. REPORT PHASE
        

  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    `uvm_info("USB_ENV_REPORT",
              "USB PHY environment simulation completed",
              UVM_LOW)

  endfunction


endclass

