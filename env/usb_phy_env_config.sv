
class usb_phy_env_config extends uvm_object;

    `uvm_object_utils(usb_phy_env_config)

    // PHY agent configuration
    phy_agent_config phy_cfg;

    // USB BFM agent configuration
    usb_bfm_agent_config usb_bfm_cfg;

    // Environment-level controls
    bit enable_phy_agent     = 1'b1;
    bit enable_usb_bfm_agent = 1'b1;

    // Default USB operating speed
    speed_t speed = FS;

    // Environment name
    string env_name = "USB_PHY_ENV";


    function new(string name = "usb_phy_env_config");
        super.new(name);
    endfunction


    // Create and initialize the agent configurations.
    function void create_agent_configs();

        if (phy_cfg == null) begin

            phy_cfg = phy_agent_config::type_id::create(
                "phy_cfg"
            );

        end

        if (usb_bfm_cfg == null) begin

            usb_bfm_cfg = usb_bfm_agent_config::type_id::create(
                "usb_bfm_cfg"
            );

        end

        phy_cfg.speed = speed;
        usb_bfm_cfg.set_speed(speed);

    endfunction


    // Set the operating speed for both agents.
    function void set_speed(speed_t new_speed);

        if (!(new_speed inside {LS, FS, HS})) begin

            `uvm_error(
                "USB_PHY_ENV_CFG",
                $sformatf(
                    "Invalid USB speed: %0d",
                    new_speed
                )
            )

            return;

        end

        speed = new_speed;

        if (phy_cfg != null) begin
            phy_cfg.speed = new_speed;
        end

        if (usb_bfm_cfg != null) begin
            usb_bfm_cfg.set_speed(new_speed);
        end

    endfunction


    // Validate environment configuration.
    function void check_config();

        if (enable_phy_agent && phy_cfg == null) begin

            `uvm_fatal(
                "USB_PHY_ENV_CFG",
                "PHY agent configuration is NULL"
            )

        end

        if (enable_usb_bfm_agent && usb_bfm_cfg == null) begin

            `uvm_fatal(
                "USB_PHY_ENV_CFG",
                "USB BFM agent configuration is NULL"
            )

        end

        if (!(speed inside {LS, FS, HS})) begin

            `uvm_fatal(
                "USB_PHY_ENV_CFG",
                "Invalid environment USB speed"
            )

        end

    endfunction


    // Print the environment configuration.
    function void print_config();

        `uvm_info(
            "USB_PHY_ENV_CFG",
            $sformatf(
                "Environment=%s Speed=%0d PHY Agent=%0b USB BFM Agent=%0b",
                env_name,
                speed,
                enable_phy_agent,
                enable_usb_bfm_agent
            ),
            UVM_LOW
        )

    endfunction

endclass 
