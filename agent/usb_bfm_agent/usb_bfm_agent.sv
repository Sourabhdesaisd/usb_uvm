
class usb_bfm_agent extends uvm_agent;

  `uvm_component_utils(usb_bfm_agent)


            
  // 1. CONFIGURATION
            

  usb_bfm_config cfg;


            
  // 2. UVM COMPONENTS
            

  usb_bfm_sequencer sequencer;
  usb_bfm_driver    driver;
  usb_bfm_monitor   monitor;


            
  // 3. CONSTRUCTOR
            

  function new(string name = "usb_bfm_agent",
               uvm_component parent = null);

    super.new(name, parent);

  endfunction


            
  // 4. BUILD PHASE
            

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);


              
    // Get USB BFM configuration
              

    if (!uvm_config_db#(usb_bfm_config)::get(
          this, "", "cfg", cfg)) begin

      `uvm_fatal("USB_AGENT_CFG",
                 "USB BFM configuration not found")

    end

    if (cfg == null) begin

      `uvm_fatal("USB_AGENT_CFG_NULL",
                 "USB BFM configuration handle is NULL")

    end


              
    // Validate configuration
              

    cfg.validate_config();


              
    // Configure active/passive mode
              

    is_active = cfg.is_active;


              
    // Create USB BFM monitor
    // Monitor is created in both active and passive
    // modes.
              

    // Pass virtual interface to monitor
    uvm_config_db#(virtual usb_bus_if)::set(
      this,
      "monitor",
      "vif",
      cfg.vif
    );


    // Pass configuration to monitor
    uvm_config_db#(usb_bfm_config)::set(
      this,
      "monitor",
      "cfg",
      cfg
    );


    monitor = usb_bfm_monitor::type_id::create(
      "monitor",
      this
    );


              
    // Create driver and sequencer in active mode
              

    if (is_active == UVM_ACTIVE) begin


      // Pass virtual interface to driver
      uvm_config_db#(virtual usb_bus_if)::set(
        this,
        "driver",
        "vif",
        cfg.vif
      );


      // Pass configuration to driver
      uvm_config_db#(usb_bfm_config)::set(
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


      // Create driver
      driver = usb_bfm_driver::type_id::create(
        "driver",
        this
      );

    end


    `uvm_info("USB_AGENT",
              $sformatf(
                "USB BFM agent build completed. Mode=%s Speed=%0d",
                is_active.name(),
                cfg.speed
              ),
              UVM_LOW)

  endfunction


            
  // 5. CONNECT PHASE
            

  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);


              
    // Connect driver and sequencer in active mode
              

    if (is_active == UVM_ACTIVE) begin

      if ((driver == null) || (sequencer == null)) begin

        `uvm_fatal("USB_AGENT_CONNECT",
                   "USB driver or sequencer handle is NULL")

      end

      driver.seq_item_port.connect(
        sequencer.seq_item_export
      );


      `uvm_info("USB_AGENT",
                "USB driver connected to sequencer",
                UVM_LOW)

    end


    `uvm_info("USB_AGENT",
              "USB BFM agent connect phase completed",
              UVM_LOW)

  endfunction

endclass

