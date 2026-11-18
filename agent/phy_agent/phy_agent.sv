

class phy_agent extends uvm_agent;

    `uvm_component_utils(phy_agent)

       
    // Configuration
       

    phy_agent_config cfg;

       
    // UVM Components
       

    phy_sequencer sequencer;
    phy_driver    driver;
    phy_monitor   monitor;


       
    // Constructor
       

    function new(string name = "phy_agent",
                 uvm_component parent = null);

        super.new(name, parent);

    endfunction


       
    // Build Phase
       

    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        // Get PHY agent configuration
        if (!uvm_config_db#(phy_agent_config)::get(
                this, "", "cfg", cfg)) begin

            `uvm_fatal("PHY_AGENT_CFG",
                       "PHY agent configuration not found")

        end

        // Check configuration handle
        if (cfg == null) begin

            `uvm_fatal("PHY_AGENT_CFG",
                       "PHY agent configuration handle is NULL")

        end

        // Check virtual interface
        if (cfg.vif == null) begin

            `uvm_fatal("PHY_AGENT_VIF",
                       "PHY virtual interface is NULL")

        end

        // Configure active/passive mode
        is_active = cfg.is_active;


         
        // Create Monitor in both active and passive modes
         

        uvm_config_db#(virtual usb_phy_if)::set(
            this, "monitor", "vif", cfg.vif);

        uvm_config_db#(phy_agent_config)::set(
            this, "monitor", "cfg", cfg);

        monitor = phy_monitor::type_id::create(
            "monitor", this);


         
        // Active Agent: Create Driver and Sequencer
         

        if (is_active == UVM_ACTIVE) begin

            // Pass interface to driver
            uvm_config_db#(virtual usb_phy_if)::set(
                this, "driver", "vif", cfg.vif);

            // Pass configuration to driver
            uvm_config_db#(phy_agent_config)::set(
                this, "driver", "cfg", cfg);

            // Create sequencer
            sequencer = phy_sequencer::type_id::create(
                "sequencer", this);

            // Create driver
            driver = phy_driver::type_id::create(
                "driver", this);

        end


        `uvm_info("PHY_AGENT",
                  $sformatf(
                      "PHY agent build completed. Mode = %s",
                      is_active.name()),
                  UVM_LOW)

    endfunction


       
    // Connect Phase
       

    function void connect_phase(uvm_phase phase);

        super.connect_phase(phase);

        // Connect driver and sequencer in active mode
        if (is_active == UVM_ACTIVE) begin

            if (driver == null || sequencer == null) begin

                `uvm_fatal("PHY_AGENT_CONNECT",
                           "Driver or Sequencer handle is NULL")

            end

            driver.seq_item_port.connect(
                sequencer.seq_item_export);

            `uvm_info("PHY_AGENT",
                      "PHY driver connected to sequencer",
                      UVM_LOW)

        end

    endfunction

endclass : phy_agent

