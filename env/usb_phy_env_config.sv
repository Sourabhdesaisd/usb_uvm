
class usb_phy_env_config extends uvm_object;

     
  // Virtual interfaces
     

  // Interface connected to the PHY SIE interface
  virtual usb_phy_if phy_vif;

  // Interface connected to the external USB bus/BFM
  virtual usb_bus_if usb_vif;


     
  // Common USB speed configuration
     

  usb_speed_e speed;


     
  // Agent activity configuration
     

  uvm_active_passive_enum phy_is_active;
  uvm_active_passive_enum usb_is_active;


     
  // UVM factory and field registration
     

  `uvm_object_utils_begin(usb_phy_env_config)

    `uvm_field_enum(usb_speed_e, speed, UVM_ALL_ON)

    `uvm_field_enum(uvm_active_passive_enum,
                    phy_is_active, UVM_ALL_ON)

    `uvm_field_enum(uvm_active_passive_enum,
                    usb_is_active, UVM_ALL_ON)

  `uvm_object_utils_end


     
  // Constructor
     

  function new(string name = "usb_phy_env_config");

    super.new(name);

    // Initialize virtual interfaces
    phy_vif = null;
    usb_vif = null;

    // Default USB speed
    speed = USB_SPEED_FS;

    // Both agents are active by default
    phy_is_active = UVM_ACTIVE;
    usb_is_active = UVM_ACTIVE;

  endfunction


     
  // Configuration validation
     

  function void validate_config();

    if (phy_vif == null) begin
      `uvm_fatal("ENV_CFG",
                 "PHY virtual interface is not configured")
    end

    if (usb_vif == null) begin
      `uvm_fatal("ENV_CFG",
                 "USB bus virtual interface is not configured")
    end

    if (speed == USB_SPEED_RESERVED) begin
      `uvm_fatal("ENV_CFG",
                 "Reserved USB speed is not supported")
    end

    if ((phy_is_active != UVM_ACTIVE) &&
        (phy_is_active != UVM_PASSIVE)) begin
      `uvm_fatal("ENV_CFG",
                 "Invalid PHY agent activity configuration")
    end

    if ((usb_is_active != UVM_ACTIVE) &&
        (usb_is_active != UVM_PASSIVE)) begin
      `uvm_fatal("ENV_CFG",
                 "Invalid USB BFM agent activity configuration")
    end

  endfunction

endclass

