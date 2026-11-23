
class usb_phy_base_test extends uvm_test;

    `uvm_component_utils(usb_phy_base_test)

    // Main environment
    usb_phy_env env;

    // Environment configuration
    usb_phy_env_config env_cfg;

    // Virtual interfaces
    virtual usb_phy_if #(8) phy_vif;
    virtual usb_bus_if bus_vif;


    function new(
        string name = "usb_phy_base_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Retrieve PHY interface from testbench top.
        if (!uvm_config_db#(virtual usb_phy_if #(8))::get(
                this,
                "",
                "vif",
                phy_vif
            )) begin

            `uvm_fatal(
                "USB_PHY_BASE_TEST",
                "PHY virtual interface not found"
            )

        end

        // Retrieve USB bus interface from testbench top.
        if (!uvm_config_db#(virtual usb_bus_if)::get(
                this,
                "",
                "bus_vif",
                bus_vif
            )) begin

            `uvm_fatal(
                "USB_PHY_BASE_TEST",
                "USB bus virtual interface not found"
            )

        end


        // Create environment configuration.
        env_cfg = usb_phy_env_config::type_id::create(
            "env_cfg"
        );

        // Create both agent configurations.
        env_cfg.create_agent_configs();


        // Configure PHY agent.
        env_cfg.phy_cfg.vif = phy_vif;
        env_cfg.phy_cfg.is_active = UVM_ACTIVE;
        env_cfg.phy_cfg.enable_driver = 1'b1;
        env_cfg.phy_cfg.enable_monitor = 1'b1;


        // Configure USB BFM agent.
        env_cfg.usb_bfm_cfg.bus_vif = bus_vif;
        env_cfg.usb_bfm_cfg.phy_vif = phy_vif;
        env_cfg.usb_bfm_cfg.is_active = UVM_ACTIVE;
        env_cfg.usb_bfm_cfg.enable_driver = 1'b1;
        env_cfg.usb_bfm_cfg.enable_monitor = 1'b1;


        // Default test speed.
        env_cfg.set_speed(FS);

        // Validate all configurations.
        env_cfg.check_config();


        // Pass configuration to environment.
        uvm_config_db#(usb_phy_env_config)::set(
            this,
            "env",
            "env_cfg",
            env_cfg
        );


        // Create environment.
        env = usb_phy_env::type_id::create(
            "env",
            this
        );


        `uvm_info(
            "USB_PHY_BASE_TEST",
            "USB PHY base test build completed",
            UVM_LOW
        )

    endfunction


    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);

        `uvm_info(
            "USB_PHY_BASE_TEST",
            "USB PHY UVM testbench topology",
            UVM_LOW
        )

        uvm_top.print_topology();

    endfunction


    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info(
            "USB_PHY_BASE_TEST",
            "USB PHY base test completed",
            UVM_LOW
        )

    endfunction

endclass : usb_phy_base_test

