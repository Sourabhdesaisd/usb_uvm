
class usb_phy_env_config extends uvm_object;

  `uvm_object_utils(usb_phy_env_config)

  // Agent configurations
  phy_agent_config phy_cfg;
  usb_bfm_agent_config usb_bfm_cfg;

  // Environment-level controls
  bit enable_phy_agent     = 1'b1;
  bit enable_usb_bfm_agent = 1'b1;
  bit enable_scoreboard    = 1'b1;

  // Default USB operating speed
  speed_t speed = FS;

  // Environment name
  string env_name = "USB_PHY_ENV";


  // Constructor
  function new(string name = "usb_phy_env_config");
    super.new(name);
  endfunction


  // Create and initialize agent configurations
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

    // Apply common speed
    phy_cfg.speed = speed;
    usb_bfm_cfg.set_speed(speed);

  endfunction


  // Set operating speed for both agents
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

    if (phy_cfg != null)
      phy_cfg.speed = new_speed;

    if (usb_bfm_cfg != null)
      usb_bfm_cfg.set_speed(new_speed);

    `uvm_info(
      "USB_PHY_ENV_CFG",
      $sformatf("USB speed updated to %0d", speed),
      UVM_LOW
    )

  endfunction


  // Validate environment configuration
  function void check_config();

    // Validate PHY agent configuration
    if (enable_phy_agent && phy_cfg == null) begin

      `uvm_fatal(
        "USB_PHY_ENV_CFG",
        "PHY agent is enabled but PHY configuration is NULL"
      )

    end

    // Validate USB BFM configuration
    if (enable_usb_bfm_agent && usb_bfm_cfg == null) begin

      `uvm_fatal(
        "USB_PHY_ENV_CFG",
        "USB BFM agent is enabled but its configuration is NULL"
      )

    end

    // Validate speed
    if (!(speed inside {LS, FS, HS})) begin

      `uvm_fatal(
        "USB_PHY_ENV_CFG",
        "Invalid environment USB speed"
      )

    end

    // Check PHY speed consistency
    if (enable_phy_agent && phy_cfg != null) begin

      if (phy_cfg.speed != speed) begin

        `uvm_fatal(
          "USB_PHY_ENV_CFG",
          "PHY agent speed does not match environment speed"
        )

      end

    end

  endfunction


  // Print environment configuration
  function void print_config();

    `uvm_info(
      "USB_PHY_ENV_CFG",
      $sformatf(
        "Environment       : %s\n\
         USB Speed         : %0d\n\
         PHY Agent Enabled : %0b\n\
         USB BFM Enabled   : %0b\n\
         Scoreboard Enabled: %0b",
        env_name,
        speed,
        enable_phy_agent,
        enable_usb_bfm_agent,
        enable_scoreboard
      ),
      UVM_LOW
    )

  endfunction

endclass

