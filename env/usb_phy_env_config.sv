
class usb_phy_env_config extends uvm_object;

  `uvm_object_utils(usb_phy_env_config)

  // --------------------------------------------------
  // Agent configurations
  // --------------------------------------------------

  phy_agent_config     phy_cfg;
  usb_bfm_agent_config usb_bfm_cfg;


  // --------------------------------------------------
  // Environment-level controls
  // --------------------------------------------------

  bit enable_phy_agent     = 1'b1;
  bit enable_usb_bfm_agent = 1'b1;
  bit enable_scoreboard    = 1'b1;


  // --------------------------------------------------
  // Common USB operating speed
  // --------------------------------------------------

  speed_t speed = FS;


  // --------------------------------------------------
  // Environment identification
  // --------------------------------------------------

  string env_name = "USB_PHY_ENV";


  // --------------------------------------------------
  // Constructor
  // --------------------------------------------------

  function new(string name = "usb_phy_env_config");

    super.new(name);

  endfunction


  // --------------------------------------------------
  // Create agent configurations
  // --------------------------------------------------

  function void create_agent_configs();


    // ----------------------------------------------
    // PHY agent configuration
    // ----------------------------------------------

    if (enable_phy_agent) begin

      if (phy_cfg == null) begin

        phy_cfg = phy_agent_config::type_id::create(
          "phy_cfg"
        );

      end

      phy_cfg.set_speed(speed);

    end


    // ----------------------------------------------
    // USB BFM agent configuration
    // ----------------------------------------------

    if (enable_usb_bfm_agent) begin

      if (usb_bfm_cfg == null) begin

        usb_bfm_cfg =
          usb_bfm_agent_config::type_id::create(
            "usb_bfm_cfg"
          );

      end

      usb_bfm_cfg.set_speed(speed);

    end


    `uvm_info(
      "USB_PHY_ENV_CFG",
      "Agent configurations created",
      UVM_LOW
    )

  endfunction


  // --------------------------------------------------
  // Configure common USB speed
  // --------------------------------------------------

  function void set_speed(speed_t new_speed);

    if (!(new_speed inside {LS, FS, HS})) begin

      `uvm_fatal(
        "USB_PHY_ENV_CFG",
        $sformatf(
          "Invalid USB speed: %0d",
          new_speed
        )
      )

    end


    // Update environment speed
    speed = new_speed;


    // Update PHY agent speed
    if (phy_cfg != null) begin

      phy_cfg.set_speed(new_speed);

    end


    // Update USB BFM speed
    if (usb_bfm_cfg != null) begin

      usb_bfm_cfg.set_speed(new_speed);

    end


    `uvm_info(
      "USB_PHY_ENV_CFG",
      $sformatf(
        "Common USB speed updated to %0d",
        speed
      ),
      UVM_LOW
    )

  endfunction


  // --------------------------------------------------
  // Validate environment configuration
  // --------------------------------------------------

  function void check_config();


    // ----------------------------------------------
    // Validate operating speed
    // ----------------------------------------------

    if (!(speed inside {LS, FS, HS})) begin

      `uvm_fatal(
        "USB_PHY_ENV_CFG",
        "Invalid environment USB speed"
      )

    end


    // ----------------------------------------------
    // Validate PHY agent
    // ----------------------------------------------

    if (enable_phy_agent) begin

      if (phy_cfg == null) begin

        `uvm_fatal(
          "USB_PHY_ENV_CFG",
          "PHY agent is enabled but PHY configuration is NULL"
        )

      end


      if (phy_cfg.speed != speed) begin

        `uvm_fatal(
          "USB_PHY_ENV_CFG",
          "PHY agent speed does not match environment speed"
        )

      end

    end


    // ----------------------------------------------
    // Validate USB BFM agent
    // ----------------------------------------------

    if (enable_usb_bfm_agent) begin

      if (usb_bfm_cfg == null) begin

        `uvm_fatal(
          "USB_PHY_ENV_CFG",
          "USB BFM is enabled but its configuration is NULL"
        )

      end


      if (usb_bfm_cfg.speed != speed) begin

        `uvm_fatal(
          "USB_PHY_ENV_CFG",
          "USB BFM speed does not match environment speed"
        )

      end

    end


    // ----------------------------------------------
    // Check that at least one agent is enabled
    // ----------------------------------------------

    if (!enable_phy_agent && !enable_usb_bfm_agent) begin

      `uvm_warning(
        "USB_PHY_ENV_CFG",
        "Both PHY and USB BFM agents are disabled"
      )

    end


    `uvm_info(
      "USB_PHY_ENV_CFG",
      "Environment configuration validation completed",
      UVM_LOW
    )

  endfunction


  // --------------------------------------------------
  // Print environment configuration
  // --------------------------------------------------

  function void print_config();

    `uvm_info(
      "USB_PHY_ENV_CFG",
      "----------------------------------------",
      UVM_LOW
    )

    `uvm_info(
      "USB_PHY_ENV_CFG",
      $sformatf(
        "Environment          : %s",
        env_name
      ),
      UVM_LOW
    )

    `uvm_info(
      "USB_PHY_ENV_CFG",
      $sformatf(
        "USB Speed            : %0d",
        speed
      ),
      UVM_LOW
    )

    `uvm_info(
      "USB_PHY_ENV_CFG",
      $sformatf(
        "PHY Agent Enabled    : %0b",
        enable_phy_agent
      ),
      UVM_LOW
    )

    `uvm_info(
      "USB_PHY_ENV_CFG",
      $sformatf(
        "USB BFM Enabled      : %0b",
        enable_usb_bfm_agent
      ),
      UVM_LOW
    )

    `uvm_info(
      "USB_PHY_ENV_CFG",
      $sformatf(
        "Scoreboard Enabled   : %0b",
        enable_scoreboard
      ),
      UVM_LOW
    )

    `uvm_info(
      "USB_PHY_ENV_CFG",
      "----------------------------------------",
      UVM_LOW
    )

  endfunction

endclass

