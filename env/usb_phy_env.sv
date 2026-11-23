
class usb_phy_env extends uvm_env;

    `uvm_component_utils(usb_phy_env)

    // Environment configuration
    usb_phy_env_config env_cfg;

    // UVM agents
    phy_agent     phy_ag;
    usb_bfm_agent usb_ag;

    // Scoreboard
    usb_phy_scb scoreboard;


    function new(
        string name = "usb_phy_env",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get environment configuration.
        if (!uvm_config_db#(usb_phy_env_config)::get(
                this, "", "env_cfg", env_cfg
            )) begin

            `uvm_fatal(
                "USB_PHY_ENV",
                "usb_phy_env_config not found in config_db"
            )

        end

        env_cfg.check_config();

        // Create PHY agent.
        if (env_cfg.enable_phy_agent) begin

            uvm_config_db#(phy_agent_config)::set(
                this,
                "phy_ag",
                "cfg",
                env_cfg.phy_cfg
            );

            phy_ag = phy_agent::type_id::create(
                "phy_ag",
                this
            );

        end

        // Create USB BFM agent.
        if (env_cfg.enable_usb_bfm_agent) begin

            uvm_config_db#(usb_bfm_agent_config)::set(
                this,
                "usb_ag",
                "cfg",
                env_cfg.usb_bfm_cfg
            );

            usb_ag = usb_bfm_agent::type_id::create(
                "usb_ag",
                this
            );

        end

        // Create scoreboard.
        scoreboard = usb_phy_scb::type_id::create(
            "scoreboard",
            this
        );

    endfunction


    function void connect_phase(uvm_phase phase);
    
      super.connect_phase(phase);
    
      // PHY monitor -> scoreboard
      phy_ag.monitor.analysis_port.connect(
        scoreboard.phy_fifo.analysis_export
      );
    
      // USB bus monitor -> scoreboard
      usb_ag.monitor.analysis_port.connect(
        scoreboard.bus_fifo.analysis_export
      );
    
    endfunction


    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);

        `uvm_info(
            "USB_PHY_ENV",
            "USB PHY UVM environment elaboration completed",
            UVM_LOW
        )

        uvm_top.print_topology();

    endfunction

endclass 

