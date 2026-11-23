
class usb_bfm_agent_config extends uvm_object;

  `uvm_object_utils_begin(usb_bfm_agent_config)

    `uvm_field_enum(
      uvm_active_passive_enum,
      is_active,
      UVM_ALL_ON
    )

    `uvm_field_int(enable_driver, UVM_ALL_ON)
    `uvm_field_int(enable_monitor, UVM_ALL_ON)

    `uvm_field_enum(speed_t, speed, UVM_ALL_ON)

    `uvm_field_int(default_bit_time_cycles, UVM_ALL_ON)
    `uvm_field_int(default_idle_cycles, UVM_ALL_ON)

    `uvm_field_string(agent_name, UVM_ALL_ON)

  `uvm_object_utils_end


  // --------------------------------------------------
  // Virtual interfaces
  // --------------------------------------------------

  // Shared USB DP/DM bus interface
  virtual usb_bus_if bus_vif;

  // PHY interface for analog/CDR stimulus
  virtual usb_phy_if #(8) phy_vif;


  // --------------------------------------------------
  // Agent configuration
  // --------------------------------------------------

  uvm_active_passive_enum is_active = UVM_ACTIVE;

  bit enable_driver  = 1'b1;
  bit enable_monitor = 1'b1;

  // USB operating speed
  speed_t speed = FS;


  // --------------------------------------------------
  // Timing configuration
  // --------------------------------------------------

  // Number of system-clock cycles per USB bit
  int unsigned default_bit_time_cycles = 40;

  // Idle duration before starting a new bus transaction
  int unsigned default_idle_cycles = 0;


  // Agent identification
  string agent_name = "USB_BFM_AGENT";


  // --------------------------------------------------
  // Constructor
  // --------------------------------------------------

  function new(string name = "usb_bfm_agent_config");

    super.new(name);

  endfunction


  // --------------------------------------------------
  // Set USB operating speed
  // --------------------------------------------------

  function void set_speed(speed_t new_speed);

    if (!(new_speed inside {LS, FS, HS})) begin

      `uvm_fatal(
        "USB_BFM_CFG",
        $sformatf(
          "Invalid USB speed: %0d",
          new_speed
        )
      )

    end

    speed = new_speed;

    // These values follow the current RTL's
    // 480 MHz system-clock timing convention.
    case (new_speed)

      LS: begin
        default_bit_time_cycles = 320;
      end

      FS: begin
        default_bit_time_cycles = 40;
      end

      HS: begin
        default_bit_time_cycles = 1;
      end

      default: begin
        `uvm_fatal(
          "USB_BFM_CFG",
          "Unsupported USB speed"
        )
      end

    endcase

    `uvm_info(
      "USB_BFM_CFG",
      $sformatf(
        "USB speed configured: speed=%0d bit_time_cycles=%0d",
        speed,
        default_bit_time_cycles
      ),
      UVM_LOW
    )

  endfunction


  // --------------------------------------------------
  // Configuration validation
  // --------------------------------------------------

  function void check_config();

    // Check shared USB bus interface
    if (bus_vif == null) begin

      `uvm_fatal(
        "USB_BFM_CFG",
        "USB bus virtual interface is NULL"
      )

    end


    // Check PHY interface
    if (phy_vif == null) begin

      `uvm_fatal(
        "USB_BFM_CFG",
        "PHY virtual interface is NULL"
      )

    end


    // Check operating speed
    if (!(speed inside {LS, FS, HS})) begin

      `uvm_fatal(
        "USB_BFM_CFG",
        "Invalid USB speed configuration"
      )

    end


    // Check bit period
    if (default_bit_time_cycles == 0) begin

      `uvm_fatal(
        "USB_BFM_CFG",
        "USB bit time cannot be zero"
      )

    end


    // Check bit period against selected speed
    case (speed)

      LS: begin

        if (default_bit_time_cycles != 320) begin

          `uvm_fatal(
            "USB_BFM_CFG",
            "LS bit period must be 320 system-clock cycles"
          )

        end

      end

      FS: begin

        if (default_bit_time_cycles != 40) begin

          `uvm_fatal(
            "USB_BFM_CFG",
            "FS bit period must be 40 system-clock cycles"
          )

        end

      end

      HS: begin

        if (default_bit_time_cycles != 1) begin

          `uvm_fatal(
            "USB_BFM_CFG",
            "HS bit period must be 1 system-clock cycle"
          )

        end

      end

      default: begin

        `uvm_fatal(
          "USB_BFM_CFG",
          "Unsupported USB speed"
        )

      end

    endcase


    // Active agent requires a driver
    if ((is_active == UVM_ACTIVE) && !enable_driver) begin

      `uvm_fatal(
        "USB_BFM_CFG",
        "Active USB BFM agent requires its driver"
      )

    end


    // Validate agent mode
    if (!(is_active inside {UVM_ACTIVE, UVM_PASSIVE})) begin

      `uvm_fatal(
        "USB_BFM_CFG",
        "Invalid USB BFM agent mode"
      )

    end


    // At least one component should be enabled
    if (!enable_driver && !enable_monitor) begin

      `uvm_warning(
        "USB_BFM_CFG",
        "Both USB BFM driver and monitor are disabled"
      )

    end

  endfunction


  // --------------------------------------------------
  // Print configuration
  // --------------------------------------------------

  function void print_config();

    `uvm_info(
      "USB_BFM_CFG",
      "----------------------------------------",
      UVM_LOW
    )

    `uvm_info(
      "USB_BFM_CFG",
      $sformatf("Agent name          : %s", agent_name),
      UVM_LOW
    )

    `uvm_info(
      "USB_BFM_CFG",
      $sformatf(
        "Agent mode          : %s",
        (is_active == UVM_ACTIVE) ? "ACTIVE" : "PASSIVE"
      ),
      UVM_LOW
    )

    `uvm_info(
      "USB_BFM_CFG",
      $sformatf("Driver enabled      : %0b", enable_driver),
      UVM_LOW
    )

    `uvm_info(
      "USB_BFM_CFG",
      $sformatf("Monitor enabled     : %0b", enable_monitor),
      UVM_LOW
    )

    `uvm_info(
      "USB_BFM_CFG",
      $sformatf("USB speed           : %0d", speed),
      UVM_LOW
    )

    `uvm_info(
      "USB_BFM_CFG",
      $sformatf(
        "Bit time (sys cycles): %0d",
        default_bit_time_cycles
      ),
      UVM_LOW
    )

    `uvm_info(
      "USB_BFM_CFG",
      $sformatf(
        "Idle cycles         : %0d",
        default_idle_cycles
      ),
      UVM_LOW
    )

    `uvm_info(
      "USB_BFM_CFG",
      "----------------------------------------",
      UVM_LOW
    )

  endfunction

endclass

