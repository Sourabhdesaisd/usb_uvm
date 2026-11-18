class usb_bfm_agent extends uvm_agent;

  `uvm_component_utils(usb_bfm_agent)

  usb_bfm_config cfg;

  usb_bfm_sequencer sequencer;
  usb_bfm_driver    driver;
  usb_bfm_monitor   monitor;

  function new(string name = "usb_bfm_agent",
               uvm_component parent = null);

    super.new(name, parent);

  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db#(usb_bfm_config)::get(
          this, "", "cfg", cfg)) begin

      `uvm_fatal("USB_AGENT_CFG",
                 "USB BFM configuration not found")

    end

    is_active = cfg.is_active;

    if (cfg.vif == null) begin

      `uvm_fatal("USB_AGENT_VIF",
                 "USB BFM virtual interface is NULL")

    end

    // Pass configuration and interface to monitor
    uvm_config_db#(virtual usb_bus_if)::set(
      this, "monitor", "vif", cfg.vif);

    monitor = usb_bfm_monitor::type_id::create(
      "monitor", this);

    if (is_active == UVM_ACTIVE) begin

      uvm_config_db#(virtual usb_bus_if)::set(
        this, "driver", "vif", cfg.vif);

      uvm_config_db#(usb_bfm_config)::set(
        this, "driver", "cfg", cfg);

      sequencer = usb_bfm_sequencer::type_id::create(
        "sequencer", this);

      driver = usb_bfm_driver::type_id::create(
        "driver", this);

    end

    `uvm_info("USB_AGENT",
              "USB BFM agent build completed",
              UVM_LOW)

  endfunction


  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);

    if (is_active == UVM_ACTIVE) begin

      driver.seq_item_port.connect(
        sequencer.seq_item_export);

      `uvm_info("USB_AGENT",
                "USB driver connected to sequencer",
                UVM_LOW)

    end

  endfunction

endclass
