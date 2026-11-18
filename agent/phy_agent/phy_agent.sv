
class phy_agent extends uvm_agent;

  `uvm_component_utils(phy_agent)

  phy_agent_config cfg;

phy_sequencer sequencer;
  phy_driver    driver;
  phy_monitor   monitor;

function new(string name = "phy_agent",
               uvm_component parent = null);

    super.new(name, parent);

  endfunction

// ------------------------------------------------
  // Build phase
  // ------------------------------------------------
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

if (!uvm_config_db#(phy_agent_config)::get(
          this, "", "cfg", cfg)) begin

`uvm_fatal("PHY_AGENT_CFG",
                 "PHY agent configuration not found")

    end

    if (cfg.vif == null) begin

`uvm_fatal("PHY_AGENT_VIF",
                 "PHY virtual interface is NULL")

    end

    is_active = cfg.is_active;

// Pass interface and configuration to monitor
    uvm_config_db#(virtual usb_phy_if)::set(
      this, "monitor", "vif", cfg.vif);

uvm_config_db#(phy_agent_config)::set(
      this, "monitor", "cfg", cfg);

monitor = phy_monitor::type_id::create(
      "monitor", this);

// Create driver and sequencer only in active mode
    if (is_active == UVM_ACTIVE) begin

uvm_config_db#(virtual usb_phy_if)::set(
        this, "driver", "vif", cfg.vif);

uvm_config_db#(phy_agent_config)::set(
        this, "driver", "cfg", cfg);

sequencer = phy_sequencer::type_id::create(
        "sequencer", this);

driver = phy_driver::type_id::create(
        "driver", this);

    end

`uvm_info("PHY_AGENT",
              "PHY agent build completed",
              UVM_LOW)

  endfunction

// ------------------------------------------------
  // Connect phase
  // ------------------------------------------------
  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);

    if (is_active == UVM_ACTIVE) begin

driver.seq_item_port.connect(
        sequencer.seq_item_export);

`uvm_info("PHY_AGENT",
                "PHY driver connected to sequencer",
                UVM_LOW)

    end

  endfunction

endclass
