
class phy_agent extends uvm_agent;

    `uvm_component_utils(phy_agent)

    // Agent configuration
    phy_agent_config cfg;

    // Agent components
    phy_sequencer sequencer;
    phy_driver    driver;
    phy_monitor   monitor;

    function new(
        string name = "phy_agent",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction


              
    // BUILD PHASE
              

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Retrieve PHY agent configuration
        if (!uvm_config_db#(phy_agent_config)::get(
            this,
            "",
            "cfg",
            cfg
        )) begin
            `uvm_fatal(
                "PHY_AGENT",
                "Failed to retrieve phy_agent_config"
            )
        end

        if (cfg == null) begin
            `uvm_fatal(
                "PHY_AGENT",
                "PHY agent configuration is NULL"
            )
        end

        cfg.check_config();

        // Create monitor when enabled
        if (cfg.enable_monitor) begin

            monitor = phy_monitor::type_id::create(
                "monitor",
                this
            );

            uvm_config_db#(phy_agent_config)::set(
                this,
                "monitor",
                "cfg",
                cfg
            );

        end

        // Create driver and sequencer in active mode
        if (cfg.is_active == UVM_ACTIVE) begin

            if (!cfg.enable_driver) begin
                `uvm_fatal(
                    "PHY_AGENT",
                    "Active PHY agent requires enable_driver=1"
                )
            end

            sequencer = phy_sequencer::type_id::create(
                "sequencer",
                this
            );

            driver = phy_driver::type_id::create(
                "driver",
                this
            );

            uvm_config_db#(phy_agent_config)::set(
                this,
                "driver",
                "cfg",
                cfg
            );

        end

    endfunction


              
    // CONNECT PHASE
              

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (cfg.is_active == UVM_ACTIVE) begin

            if (sequencer == null || driver == null) begin
                `uvm_fatal(
                    "PHY_AGENT",
                    "Sequencer or driver was not created"
                )
            end

            driver.seq_item_port.connect(
                sequencer.seq_item_export
            );

        end

    endfunction


              
    // END OF ELABORATION
              

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);

        `uvm_info(
            "PHY_AGENT",
            $sformatf(
                "PHY agent created. Mode=%s Monitor=%0b Driver=%0b",
                (cfg.is_active == UVM_ACTIVE) ? "ACTIVE" : "PASSIVE",
                cfg.enable_monitor,
                cfg.enable_driver
            ),
            UVM_LOW
        )

    endfunction

endclass 

