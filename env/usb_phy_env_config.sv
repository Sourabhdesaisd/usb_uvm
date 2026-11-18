class usb_phy_env_config extends uvm_object;

// PHY virtual interface
  virtual usb_phy_if phy_vif;

// USB bus virtual interface
  virtual usb_bus_if usb_vif;

// Common USB speed
  usb_speed_e speed;

// Agent activity configuration
  uvm_active_passive_enum phy_is_active;
  uvm_active_passive_enum usb_is_active;

  `uvm_object_utils_begin(usb_phy_env_config)

`uvm_field_enum(usb_speed_e,
                    speed, UVM_ALL_ON)

`uvm_field_enum(uvm_active_passive_enum,
                    phy_is_active, UVM_ALL_ON)

`uvm_field_enum(uvm_active_passive_enum,
                    usb_is_active, UVM_ALL_ON)

  `uvm_object_utils_end

  function new(string name = "usb_phy_env_config");

    super.new(name);

phy_vif = null;
    usb_vif = null;

// Default speed
    speed = USB_SPEED_FS;

// Default agent modes
    phy_is_active = UVM_ACTIVE;
    usb_is_active = UVM_ACTIVE;

  endfunction

endclass

